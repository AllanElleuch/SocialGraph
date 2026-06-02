import 'package:apple_maps_flutter/apple_maps_flutter.dart';
import 'package:flutter/material.dart';
import '../models/contact.dart';
import '../services/location_service.dart';

/// Native Apple Maps (MapKit) view showing contacts as annotations, the
/// device's location as the system blue dot, and a button to recenter on it.
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
  // World-ish starting view until we have a reason to move the camera.
  static const CameraPosition _initialCamera = CameraPosition(
    target: LatLng(20, 0),
    zoom: 1,
  );

  // Zoom level used when recentering on the device location (street level).
  static const double _focusZoom = 14;

  final LocationService _locationService = LocationService();
  AppleMapController? _controller;
  bool _locating = false;

  Set<Annotation> _buildAnnotations() {
    final annotations = <Annotation>{};
    for (final contact in widget.contacts) {
      final lat = contact.lat;
      final lng = contact.lng;
      if (lat == null || lng == null) continue;
      final name = contact.displayName.isEmpty ? 'Contact' : contact.displayName;
      annotations.add(
        Annotation(
          annotationId: AnnotationId(contact.id),
          position: LatLng(lat, lng),
          infoWindow: InfoWindow(title: name),
          onTap: () => widget.onSelectContact(contact),
        ),
      );
    }
    return annotations;
  }

  /// Requests location permission (if needed), resolves the device position,
  /// and recenters the map on it. The blue "you are here" dot is rendered
  /// natively by MapKit via [AppleMap.myLocationEnabled].
  Future<void> _goToMyLocation() async {
    if (_locating) return;
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _locating = true);
    try {
      final pos = await _locationService.getCurrentPosition();
      await _controller?.moveCamera(
        CameraUpdate.newLatLngZoom(LatLng(pos.lat, pos.lng), _focusZoom),
      );
    } catch (e) {
      if (!mounted) return;
      messenger.showSnackBar(
        SnackBar(content: Text(e.toString().replaceFirst('Exception: ', ''))),
      );
    } finally {
      if (mounted) setState(() => _locating = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        AppleMap(
          initialCameraPosition: _initialCamera,
          annotations: _buildAnnotations(),
          myLocationEnabled: true,
          onMapCreated: (controller) => _controller = controller,
        ),
        // Raised clear of the floating bottom navigation / active-view card.
        Positioned(
          right: 20,
          bottom: 120 + MediaQuery.of(context).padding.bottom,
          child: _LocateMeButton(
            loading: _locating,
            onPressed: _goToMyLocation,
          ),
        ),
      ],
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
