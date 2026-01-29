import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

class MapPreview extends StatelessWidget {
  final double lat;
  final double lng;
  final double zoom;

  const MapPreview({
    super.key,
    required this.lat,
    required this.lng,
    this.zoom = 14,
  });

  @override
  Widget build(BuildContext context) {
    double safeLat = lat;
    double safeLng = lng;

    // guard กันข้อมูลสลับ
    if (safeLat.abs() > 90 && safeLng.abs() <= 90) {
      debugPrint('⚠️ SWAP lat/lng detected: lat=$lat lng=$lng');
      final tmp = safeLat;
      safeLat = safeLng;
      safeLng = tmp;
    }

    final point = LatLng(safeLat, safeLng);

    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: SizedBox(
        height: 140,
        child: FlutterMap(
          options: MapOptions(
            initialCenter: point,
            initialZoom: zoom,
            interactionOptions: const InteractionOptions(
              flags: InteractiveFlag.none,
            ),
          ),
          children: [
            TileLayer(
              urlTemplate: 'https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png',
              subdomains: const ['a', 'b', 'c'],
              userAgentPackageName: 'ai_task_project_manager',
            ),
            MarkerLayer(
              markers: [
                Marker(
                  point: point,
                  width: 48,
                  height: 48,
                  alignment: Alignment.bottomCenter,
                  child: const Icon(
                    Icons.location_pin,
                    color: Colors.red,
                    size: 40,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
