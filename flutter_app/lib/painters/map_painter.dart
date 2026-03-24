import 'dart:math';
import 'package:flutter/material.dart';
import '../models/contact.dart';

class MapPainter extends CustomPainter {
  final List<Contact> contacts;
  final List<List<List<List<double>>>>? geoData; // country polygons

  MapPainter({required this.contacts, this.geoData});

  @override
  void paint(Canvas canvas, Size size) {
    _drawBackground(canvas, size);
    if (geoData != null) {
      _drawCountries(canvas, size);
    }
    _drawContactPins(canvas, size);
  }

  void _drawBackground(Canvas canvas, Size size) {
    final paint = Paint()..color = const Color(0xFF020617);
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), paint);
  }

  Offset _mercatorProject(double lng, double lat, Size size) {
    final x = (lng + 180) / 360 * size.width;
    final latRad = lat * pi / 180;
    final mercN = log(tan(pi / 4 + latRad / 2));
    final y = size.height / 2 - (mercN * size.width / (2 * pi));
    return Offset(x, y);
  }

  void _drawCountries(Canvas canvas, Size size) {
    final fillPaint = Paint()
      ..color = const Color(0xFF1a1a1a)
      ..style = PaintingStyle.fill;

    final strokePaint = Paint()
      ..color = const Color(0xFF333333)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.5;

    for (final country in geoData!) {
      for (final ring in country) {
        if (ring.length < 2) continue;
        final path = Path();
        final first = _mercatorProject(ring[0][0], ring[0][1], size);
        path.moveTo(first.dx, first.dy);
        for (int i = 1; i < ring.length; i++) {
          final pt = _mercatorProject(ring[i][0], ring[i][1], size);
          path.lineTo(pt.dx, pt.dy);
        }
        path.close();
        canvas.drawPath(path, fillPaint);
        canvas.drawPath(path, strokePaint);
      }
    }
  }

  void _drawContactPins(Canvas canvas, Size size) {
    for (final contact in contacts) {
      if (contact.lat == null || contact.lng == null) continue;

      final pos = _mercatorProject(contact.lng!, contact.lat!, size);

      // Glow
      final glowPaint = Paint()
        ..color = const Color(0xFF6366f1).withValues(alpha: 0.4)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6);
      canvas.drawCircle(pos, 8, glowPaint);

      // Pin circle
      final fillPaint = Paint()..color = const Color(0xFF6366f1);
      canvas.drawCircle(pos, 6, fillPaint);

      final strokePaint = Paint()
        ..color = Colors.white
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1;
      canvas.drawCircle(pos, 6, strokePaint);

      // Label
      final textPainter = TextPainter(
        text: TextSpan(
          text: contact.name,
          style: const TextStyle(
            color: Color(0xFF94a3b8),
            fontSize: 10,
            fontFamily: 'Inter',
          ),
        ),
        textDirection: TextDirection.ltr,
      );
      textPainter.layout();
      textPainter.paint(canvas, Offset(pos.dx + 10, pos.dy - 5));
    }
  }

  @override
  bool shouldRepaint(covariant MapPainter oldDelegate) =>
      contacts != oldDelegate.contacts || geoData != oldDelegate.geoData;
}
