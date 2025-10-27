import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

class AiMapPage extends StatelessWidget {
  /// ต้องมีคีย์ 'lat','lng' (num/double) และ 'title' (String)
  final List<Map<String, dynamic>> points;

  const AiMapPage({super.key, required this.points});

  @override
  Widget build(BuildContext context) {
    // center จากจุดแรกที่มีพิกัด
    final first = points.firstWhere(
      (e) => e['lat'] is num && e['lng'] is num,
      orElse: () => const {'lat': 13.7563, 'lng': 100.5018, 'title': 'Bangkok'},
    );
    final center = LatLng(
      (first['lat'] as num).toDouble(),
      (first['lng'] as num).toDouble(),
    );

    final markers = points.where((p) => p['lat'] is num && p['lng'] is num).map(
      (p) {
        final lat = (p['lat'] as num).toDouble();
        final lng = (p['lng'] as num).toDouble();
        final title = (p['title'] ?? '').toString();
        final type = (p['type'] ?? '').toString();

        IconData icon = Icons.location_pin;
        // (ออปชัน) เลือก icon ตามประเภท
        if (type == 'hotel') icon = Icons.hotel;
        if (type == 'restaurant') icon = Icons.restaurant;
        if (type == 'attraction') icon = Icons.place;

        return Marker(
          point: LatLng(lat, lng),
          width: 44,
          height: 44,
          child: Tooltip(
            message: title.isNotEmpty ? title : 'Point',
            child: Icon(icon, size: 36, color: Colors.red),
          ),
        );
      },
    ).toList();

    return Scaffold(
      appBar: AppBar(title: const Text('Trip Map')),
      body: FlutterMap(
        options: MapOptions(initialCenter: center, initialZoom: 12),
        children: [
          TileLayer(
            urlTemplate: 'https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png',
            subdomains: const ['a', 'b', 'c'],
            userAgentPackageName: 'ai_task_project_manager',
          ),
          MarkerLayer(markers: markers),
        ],
      ),
    );
  }
}
