import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import '../models/graph_node.dart';
import '../models/contact.dart';

class GraphPainter extends CustomPainter {
  final List<GraphNode> nodes;
  final List<GraphLink> links;
  final PivotType pivot;
  final double minTime;
  final double maxTime;

  GraphPainter({
    required this.nodes,
    required this.links,
    required this.pivot,
    required this.minTime,
    required this.maxTime,
  });

  @override
  void paint(Canvas canvas, Size size) {
    _drawLinks(canvas);
    _drawNodes(canvas);
  }

  void _drawLinks(Canvas canvas) {
    for (final link in links) {
      final source = nodes.firstWhere(
        (n) => n.id == link.sourceId,
        orElse: () => nodes.first,
      );
      final target = nodes.firstWhere(
        (n) => n.id == link.targetId,
        orElse: () => nodes.first,
      );

      final paint = Paint()
        ..color = const Color(0xFF444444).withValues(alpha: 0.4)
        ..strokeWidth = 1
        ..style = PaintingStyle.stroke;

      if (link.type == 'time') {
        _drawDashedLine(canvas, Offset(source.x, source.y),
            Offset(target.x, target.y), paint, 4, 4);
      } else {
        canvas.drawLine(
          Offset(source.x, source.y),
          Offset(target.x, target.y),
          paint,
        );
      }
    }
  }

  void _drawDashedLine(Canvas canvas, Offset start, Offset end, Paint paint,
      double dashWidth, double dashSpace) {
    final dx = end.dx - start.dx;
    final dy = end.dy - start.dy;
    final distance = math.sqrt(dx * dx + dy * dy);
    if (distance == 0) return;

    final unitX = dx / distance;
    final unitY = dy / distance;

    double drawn = 0.0;
    bool drawing = true;
    while (drawn < distance) {
      final segLen = drawing ? dashWidth : dashSpace;
      final nextDrawn = math.min(drawn + segLen, distance);
      if (drawing) {
        canvas.drawLine(
          Offset(start.dx + unitX * drawn, start.dy + unitY * drawn),
          Offset(start.dx + unitX * nextDrawn, start.dy + unitY * nextDrawn),
          paint,
        );
      }
      drawn = nextDrawn;
      drawing = !drawing;
    }
  }

  void _drawNodes(Canvas canvas) {
    for (final node in nodes) {
      final center = Offset(node.x, node.y);

      // Glow effect
      final glowPaint = Paint()
        ..color = _getNodeColor(node).withValues(alpha: 0.3)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8);
      canvas.drawCircle(center, 18, glowPaint);

      // Node circle
      final fillPaint = Paint()
        ..color = _getNodeColor(node)
        ..style = PaintingStyle.fill;
      canvas.drawCircle(center, 14, fillPaint);

      // Stroke
      final strokePaint = Paint()
        ..color = Colors.white
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2;
      canvas.drawCircle(center, 14, strokePaint);

      // Label
      final textPainter = TextPainter(
        text: TextSpan(
          text: node.name,
          style: const TextStyle(
            color: Color(0xFFe2e8f0),
            fontSize: 12,
            fontFamily: 'Inter',
          ),
        ),
        textDirection: TextDirection.ltr,
      );
      textPainter.layout();
      textPainter.paint(canvas, Offset(center.dx + 18, center.dy - 6));
    }
  }

  Color _getNodeColor(GraphNode node) {
    if (pivot == PivotType.time) {
      return _magmaColor(node.data.dateMet.millisecondsSinceEpoch.toDouble());
    }
    return const Color(0xFF6366f1); // indigo-500
  }

  // Simplified Magma colorscale interpolation
  Color _magmaColor(double value) {
    if (maxTime == minTime) return const Color(0xFF6366f1);
    final t = ((value - minTime) / (maxTime - minTime)).clamp(0.0, 1.0);
    // Magma-inspired: dark purple -> magenta -> yellow
    if (t < 0.25) {
      return Color.lerp(
          const Color(0xFF000004), const Color(0xFF51127C), t / 0.25)!;
    } else if (t < 0.5) {
      return Color.lerp(const Color(0xFF51127C), const Color(0xFFB63679),
          (t - 0.25) / 0.25)!;
    } else if (t < 0.75) {
      return Color.lerp(const Color(0xFFB63679), const Color(0xFFFB8761),
          (t - 0.5) / 0.25)!;
    } else {
      return Color.lerp(const Color(0xFFFB8761), const Color(0xFFFCFDBF),
          (t - 0.75) / 0.25)!;
    }
  }

  @override
  bool shouldRepaint(covariant GraphPainter oldDelegate) => true;
}
