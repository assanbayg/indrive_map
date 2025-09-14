import 'dart:async';
import 'dart:ui' as ui;

import 'package:csv/csv.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

void main() {
  runApp(const HeatmapApp());
}

class HeatmapApp extends StatelessWidget {
  const HeatmapApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        body: FutureBuilder<List<LatLng>>(
          future: _loadPointsFromCsv(),
          builder: (context, snapshot) {
            if (!snapshot.hasData) {
              return const Center(child: CircularProgressIndicator());
            }
            final points = snapshot.data!;
            return FlutterMap(
              options: MapOptions(
                initialCenter: LatLng(51.095460, 71.427530),
                initialZoom: 13,
              ),
              children: [
                TileLayer(
                  urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                  subdomains: const ['a', 'b', 'c'],
                  userAgentPackageName: 'com.example.indrive_map',
                ),
                HeatmapOverlay(points: points),
              ],
            );
          },
        ),
      ),
    );
  }
}

/// Load pickup & drop points from CSV
Future<List<LatLng>> _loadPointsFromCsv() async {
  final raw = await rootBundle.loadString('assets/trips.csv');
  final rows = const CsvToListConverter().convert(raw, eol: '\n');
  final points = <LatLng>[];
  for (var i = 1; i < rows.length; i++) {
    final row = rows[i];
    if (row.length >= 5) {
      points.add(LatLng(row[1], row[2])); // pickup
      points.add(LatLng(row[3], row[4])); // drop
    }
  }
  return points;
}

/// Heatmap overlay
class HeatmapOverlay extends StatelessWidget {
  final List<LatLng> points;
  const HeatmapOverlay({super.key, required this.points});

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<ImageProvider>(
      future: HeatmapPainter.generate(points),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const SizedBox();
        return OverlayImageLayer(
          overlayImages: [
            OverlayImage(
              bounds: LatLngBounds(
                const LatLng(51.05, 71.35), // SW
                const LatLng(51.12, 71.45), // NE
              ),
              opacity: 0.6,
              imageProvider: snapshot.data!,
            ),
          ],
        );
      },
    );
  }
}

/// Heatmap generator
class HeatmapPainter {
  static Future<ImageProvider> generate(List<LatLng> points) async {
    const size = 1024.0;
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder, const Rect.fromLTWH(0, 0, size, size));
    final paint = Paint()..style = PaintingStyle.fill;

    // Transparent background
    canvas.drawRect(
      const Rect.fromLTWH(0, 0, size, size),
      Paint()..color = Colors.transparent,
    );

    for (final p in points) {
      final x = ((p.longitude - 71.35) / 0.10) * size;
      final y = ((51.12 - p.latitude) / 0.07) * size;

      paint.shader = ui.Gradient.radial(Offset(x, y), 40, [
        Colors.red.withValues(alpha: 0.5),
        Colors.transparent,
      ]);
      canvas.drawCircle(Offset(x, y), 5, paint);
    }

    final picture = recorder.endRecording();
    final image = await picture.toImage(size.toInt(), size.toInt());
    final byteData = await image.toByteData(format: ui.ImageByteFormat.png);

    return MemoryImage(byteData!.buffer.asUint8List());
  }
}
