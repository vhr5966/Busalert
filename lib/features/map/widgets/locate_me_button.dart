/// Locate Me button and user location marker for FlutterMap screens.
///
/// Handles GPS permissions, location service checks, fetching current position,
/// animating map camera, and rendering a blue user position marker.
library;

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';

import '../../../core/theme.dart';

/// Renders a distinctive user location marker on the map.
Marker buildUserLocationMarker(LatLng position) {
  return Marker(
    point: position,
    width: 28,
    height: 28,
    child: Stack(
      alignment: Alignment.center,
      children: [
        // Outer translucent pulse ring
        Container(
          width: 28,
          height: 28,
          decoration: BoxDecoration(
            color: kCardiffBlue.withAlpha(60),
            shape: BoxShape.circle,
          ),
        ),
        // Inner solid location dot
        Container(
          width: 16,
          height: 16,
          decoration: BoxDecoration(
            color: kCardiffBlue,
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white, width: 2.5),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withAlpha(60),
                blurRadius: 4,
                offset: const Offset(0, 1),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}

/// A floating action button with [Icons.my_location] that centers the map
/// on the user's current GPS location.
class LocateMeButton extends StatefulWidget {
  final MapController mapController;
  final ValueChanged<LatLng>? onLocated;
  final double zoom;
  final String heroTag;

  const LocateMeButton({
    super.key,
    required this.mapController,
    this.onLocated,
    this.zoom = 15.0,
    this.heroTag = 'locate_me_fab',
  });

  @override
  State<LocateMeButton> createState() => _LocateMeButtonState();
}

class _LocateMeButtonState extends State<LocateMeButton> {
  bool _isLocating = false;

  Future<void> _handleLocate() async {
    if (_isLocating) return;

    setState(() => _isLocating = true);

    try {
      // 1. Check location services
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'Location services are disabled. Please turn on GPS in settings.',
              ),
            ),
          );
        }
        return;
      }

      // 2. Check & request location permission
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text(
                  'Location permission is required to center on your location.',
                ),
              ),
            );
          }
          return;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'Location permission is permanently denied. Please enable it in Settings.',
              ),
            ),
          );
        }
        return;
      }

      // 3. Get current location
      final pos = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 10),
        ),
      );

      final userPos = LatLng(pos.latitude, pos.longitude);

      // 4. Move map camera
      widget.mapController.move(userPos, widget.zoom);

      // 5. Notify parent callback
      widget.onLocated?.call(userPos);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Could not obtain location: ${e.toString()}'),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLocating = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return FloatingActionButton.small(
      heroTag: widget.heroTag,
      backgroundColor: Colors.white,
      foregroundColor: kCardiffBlue,
      tooltip: 'Locate me',
      onPressed: _isLocating ? null : _handleLocate,
      child: _isLocating
          ? const SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: kCardiffBlue,
              ),
            )
          : const Icon(Icons.my_location, size: 20),
    );
  }
}
