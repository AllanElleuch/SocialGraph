import 'dart:convert';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../models/contact.dart';
import '../painters/map_painter.dart';

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

class _MapViewState extends State<MapView> {
  List<List<List<List<double>>>>? _geoData;
  bool _loading = true;
  final TransformationController _transformController =
      TransformationController();

  @override
  void initState() {
    super.initState();
    _loadGeoData();
  }

  Future<void> _loadGeoData() async {
    try {
      final response = await http.get(Uri.parse(
          'https://cdn.jsdelivr.net/npm/world-atlas@2/countries-110m.json'));
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final countries = _extractCountries(data);
        setState(() {
          _geoData = countries;
          _loading = false;
        });
      }
    } catch (e) {
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

  Contact? _hitTest(Offset localPosition, Size size) {
    final matrix = _transformController.value;
    final inverted = Matrix4.tryInvert(matrix);
    if (inverted == null) return null;
    final transformed = MatrixUtils.transformPoint(inverted, localPosition);

    for (final contact in widget.contacts) {
      if (contact.lat == null || contact.lng == null) continue;
      final x = (contact.lng! + 180) / 360 * size.width;
      final latRad = contact.lat! * math.pi / 180;
      final mercN = math.log(math.tan(math.pi / 4 + latRad / 2));
      final y = size.height / 2 - (mercN * size.width / (2 * math.pi));

      final dx = transformed.dx - x;
      final dy = transformed.dy - y;
      if (dx * dx + dy * dy <= 12 * 12) {
        return contact;
      }
    }
    return null;
  }

  @override
  void dispose() {
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

    return GestureDetector(
      onTapUp: (details) {
        final size = MediaQuery.of(context).size;
        final contact = _hitTest(details.localPosition, size);
        if (contact != null) {
          widget.onSelectContact(contact);
        }
      },
      child: InteractiveViewer(
        transformationController: _transformController,
        boundaryMargin: const EdgeInsets.all(double.infinity),
        minScale: 0.1,
        maxScale: 8.0,
        child: CustomPaint(
          size: Size.infinite,
          painter: MapPainter(
            contacts: widget.contacts,
            geoData: _geoData,
          ),
        ),
      ),
    );
  }
}
