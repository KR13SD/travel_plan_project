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
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: SizedBox(
        height: 140,
        child: FlutterMap(
          options: MapOptions(
            initialCenter: LatLng(lat, lng),
            initialZoom: zoom,
            interactionOptions: const InteractionOptions(
              // ปิด gesture ใน preview กันชนกับ scroll หลัก
              flags: InteractiveFlag.none,
            ),
          ),
          children: [
            TileLayer(
              urlTemplate: 'https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png',
              subdomains: const ['a','b','c'],
              userAgentPackageName: 'ai_task_project_manager',
            ),
            MarkerLayer(markers: [
              Marker(
                point: LatLng(lat, lng),
                width: 40,
                height: 40,
                child: const Icon(Icons.location_pin, color: Colors.red, size: 36),
              ),
            ]),
          ],
        ),
      ),
    );
  }
}
