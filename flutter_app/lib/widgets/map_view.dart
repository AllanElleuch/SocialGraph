import 'dart:convert';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../models/contact.dart';
import '../painters/map_painter.dart';
import '../services/location_service.dart';

class MapView extends StatefulWidget {
  final List<Contact> contacts;
  final ValueChanged<Contact> onSelectContact;

  const MapView({
    super.key,
    required this.contacts,
    required this.onSelectContact,
  });

  @override
  State<MapView> createState() => _MapViewState();
}

class _MapViewState extends State<MapView>
    with SingleTickerProviderStateMixin {
  List<List<List<List<double>>>>? _geoData;
  bool _loading = true;

  // Minimum/maximum zoom levels for the map. Shared with [InteractiveViewer].
  static const double _minScale = 0.1;
  static const double _maxScale = 8.0;

  // Zoom level applied when centering on the device location.
  static const double _focusScale = 3.5;

  final TransformationController _transformController =
      TransformationController();

  final LocationService _locationService = LocationService();

  // Device GPS position, once resolved. Drawn as the "you are here" dot.
  ({double lat, double lng})? _userLocation;
  bool _locating = false;

  late final AnimationController _animController = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 600),
  );
  Animation<Matrix4>? _focusAnimation;

  @override
  void initState() {
    super.initState();
    _loadGeoData();
  }

  /// Projects a lng/lat pair to map (scene) coordinates. Must match the
  /// Mercator projection used by [MapPainter].
  Offset _project(double lng, double lat, Size size) {
    final x = (lng + 180) / 360 * size.width;
    final latRad = lat * math.pi / 180;
    final mercN = math.log(math.tan(math.pi / 4 + latRad / 2));
    final y = size.height / 2 - (mercN * size.width / (2 * math.pi));
    return Offset(x, y);
  }

  void _onFocusTick() {
    final anim = _focusAnimation;
    if (anim != null) _transformController.value = anim.value;
  }

  /// Smoothly animates the viewport so [target] (scene coords) sits centered
  /// at [_focusScale] zoom.
  ///
  /// The matrix is built with explicit entries (scale on the diagonal,
  /// translation in the last column) so the result is unambiguous: a scene
  /// point P maps to screen at `s * P + t`. We want the user's point centered,
  /// so `t = center - s * P`.
  void _animateToScenePoint(Offset target, Size size) {
    final s = _focusScale;
    final center = Offset(size.width / 2, size.height / 2);
    final end = Matrix4.identity()
      ..setEntry(0, 0, s)
      ..setEntry(1, 1, s)
      ..setEntry(0, 3, center.dx - s * target.dx)
      ..setEntry(1, 3, center.dy - s * target.dy);

    _focusAnimation?.removeListener(_onFocusTick);
    _focusAnimation = Matrix4Tween(
      begin: _transformController.value,
      end: end,
    ).animate(
      CurvedAnimation(parent: _animController, curve: Curves.easeInOut),
    )..addListener(_onFocusTick);
    _animController.forward(from: 0);
  }

  /// Requests location permission (if needed), resolves the device position,
  /// shows it on the map, and zooms to it.
  Future<void> _goToMyLocation(Size size) async {
    if (_locating) return;
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _locating = true);
    try {
      final pos = await _locationService.getCurrentPosition();
      if (!mounted) return;
      setState(() => _userLocation = pos);
      _animateToScenePoint(_project(pos.lng, pos.lat, size), size);
    } catch (e) {
      if (!mounted) return;
      messenger.showSnackBar(
        SnackBar(content: Text(e.toString().replaceFirst('Exception: ', ''))),
      );
    } finally {
      if (mounted) setState(() => _locating = false);
    }
  }

  Future<void> _loadGeoData() async {
    try {
      final response = await http.get(Uri.parse(
          'https://cdn.jsdelivr.net/npm/world-atlas@2/countries-110m.json'));
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final countries = _extractCountries(data);
        if (!mounted) return;
        setState(() {
          _geoData = countries;
          _loading = false;
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
    }
  }

  // Extract polygon coordinates from TopoJSON
  List<List<List<List<double>>>> _extractCountries(Map<String, dynamic> topo) {
    final result = <List<List<List<double>>>>[];

    final objects = topo['objects'] as Map<String, dynamic>;
    final countriesObj = objects['countries'] as Map<String, dynamic>;
    final geometries = countriesObj['geometries'] as List<dynamic>;
    final arcsData = topo['arcs'] as List<dynamic>;
    final transform = topo['transform'] as Map<String, dynamic>?;

    // Decode arcs
    final decodedArcs = <List<List<double>>>[];
    for (final arc in arcsData) {
      final points = <List<double>>[];
      double x = 0, y = 0;
      for (final coord in arc as List<dynamic>) {
        final c = coord as List<dynamic>;
        x += (c[0] as num).toDouble();
        y += (c[1] as num).toDouble();
        double lng = x;
        double lat = y;
        if (transform != null) {
          final scale = transform['scale'] as List<dynamic>;
          final translate = transform['translate'] as List<dynamic>;
          lng = x * (scale[0] as num).toDouble() +
              (translate[0] as num).toDouble();
          lat = y * (scale[1] as num).toDouble() +
              (translate[1] as num).toDouble();
        }
        points.add([lng, lat]);
      }
      decodedArcs.add(points);
    }

    for (final geom in geometries) {
      final type = geom['type'] as String;
      if (type == 'Polygon') {
        final arcs = geom['arcs'] as List<dynamic>;
        final polygon = <List<List<double>>>[];
        for (final ring in arcs) {
          final coords = _decodeRing(ring as List<dynamic>, decodedArcs);
          polygon.add(coords);
        }
        result.add(polygon);
      } else if (type == 'MultiPolygon') {
        final arcs = geom['arcs'] as List<dynamic>;
        for (final poly in arcs) {
          final polygon = <List<List<double>>>[];
          for (final ring in poly as List<dynamic>) {
            final coords = _decodeRing(ring as List<dynamic>, decodedArcs);
            polygon.add(coords);
          }
          result.add(polygon);
        }
      }
    }

    return result;
  }

  List<List<double>> _decodeRing(
      List<dynamic> arcIndices, List<List<List<double>>> decodedArcs) {
    final coords = <List<double>>[];
    for (final idx in arcIndices) {
      final arcIndex = idx as int;
      final reversed = arcIndex < 0;
      final actualIndex = reversed ? ~arcIndex : arcIndex;
      if (actualIndex >= decodedArcs.length) continue;
      var arc = decodedArcs[actualIndex];
      if (reversed) {
        arc = arc.reversed.toList();
      }
      // Skip first point if not the first arc to avoid duplicates
      final start = coords.isEmpty ? 0 : 1;
      for (int i = start; i < arc.length; i++) {
        coords.add(arc[i]);
      }
    }
    return coords;
  }

  // [localPosition] is already in the map's (scene) coordinate space because
  // the tap target lives inside the [InteractiveViewer]'s transformed child,
  // so no inverse-matrix step is needed here.
  Contact? _hitTest(Offset localPosition, Size size) {
    for (final contact in widget.contacts) {
      if (contact.lat == null || contact.lng == null) continue;
      final x = (contact.lng! + 180) / 360 * size.width;
      final latRad = contact.lat! * math.pi / 180;
      final mercN = math.log(math.tan(math.pi / 4 + latRad / 2));
      final y = size.height / 2 - (mercN * size.width / (2 * math.pi));

      final dx = localPosition.dx - x;
      final dy = localPosition.dy - y;
      if (dx * dx + dy * dy <= 12 * 12) {
        return contact;
      }
    }
    return null;
  }

  @override
  void dispose() {
    _focusAnimation?.removeListener(_onFocusTick);
    _animController.dispose();
    _transformController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(
        child: CircularProgressIndicator(color: Color(0xFF6366f1)),
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final size = Size(constraints.maxWidth, constraints.maxHeight);
        return Stack(
          children: [
            InteractiveViewer(
              transformationController: _transformController,
              minScale: _minScale,
              maxScale: _maxScale,
              // Allow panning the map freely beyond its edges while zoomed.
              boundaryMargin: const EdgeInsets.all(double.infinity),
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTapUp: (details) {
                  final contact = _hitTest(details.localPosition, size);
                  if (contact != null) {
                    widget.onSelectContact(contact);
                  }
                },
                child: CustomPaint(
                  size: Size.infinite,
                  painter: MapPainter(
                    contacts: widget.contacts,
                    geoData: _geoData,
                    userLocation: _userLocation,
                  ),
                ),
              ),
            ),
            // Raised clear of the floating bottom navigation / active-view card.
            Positioned(
              right: 20,
              bottom: 120 + MediaQuery.of(context).padding.bottom,
              child: _LocateMeButton(
                loading: _locating,
                onPressed: () => _goToMyLocation(size),
              ),
            ),
          ],
        );
      },
    );
  }
}

/// Circular "center on my location" button shown over the map.
class _LocateMeButton extends StatelessWidget {
  final bool loading;
  final VoidCallback onPressed;

  const _LocateMeButton({required this.loading, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: const Color(0xFF1e293b),
      shape: const CircleBorder(),
      elevation: 4,
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: loading ? null : onPressed,
        child: SizedBox(
          width: 48,
          height: 48,
          child: loading
              ? const Padding(
                  padding: EdgeInsets.all(14),
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Color(0xFF6366f1),
                  ),
                )
              : const Icon(
                  Icons.my_location,
                  color: Color(0xFF6366f1),
                  size: 22,
                ),
        ),
      ),
    );
  }
}
