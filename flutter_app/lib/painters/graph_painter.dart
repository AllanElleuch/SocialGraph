import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import '../models/graph_node.dart';
import '../models/contact.dart';
import '../services/relationship_strength.dart';

/// Base node radius (px) used when strength weighting is disabled or a contact
/// has zero strength. Setting [kStrengthRadiusFactor] to 0 reproduces the
/// original fixed-radius rendering exactly (every node drawn at this radius).
const double kNodeBaseRadius = 14.0;

/// How much a node's drawn radius can grow at full strength (RFC-006, U6.3).
///
/// `radius = kNodeBaseRadius + kStrengthRadiusFactor * (strength / 100)`.
/// At the default value of 6 a full-strength (100) node is drawn at
/// `14 + 6 = 20` px (~1.4x the base), while a 0-strength node stays at 14.
/// Set to `0.0` to restore the prior constant-radius behaviour.
const double kStrengthRadiusFactor = 6.0;

/// Pure, canvas-free mapping from a 0..100 relationship [strength] to a drawn
/// node radius. Used by the painter and exercised directly in tests.
///
/// Guarantees:
///   * always finite and `>= kNodeBaseRadius`,
///   * monotonic non-decreasing in [strength],
///   * equals [kNodeBaseRadius] exactly when [kStrengthRadiusFactor] is 0 or
///     when [strength] is 0.
///
/// Non-finite or out-of-range strengths are defensively clamped to 0..100 so
/// the result can never be NaN/infinite and can never feed a runaway value
/// into rendering.
double nodeRadiusForStrength(double strength) {
  final s = strength.isFinite ? strength.clamp(0.0, 100.0) : 0.0;
  final radius = kNodeBaseRadius + kStrengthRadiusFactor * (s / 100.0);
  // Defensive: never below base, never non-finite.
  if (!radius.isFinite || radius < kNodeBaseRadius) return kNodeBaseRadius;
  return radius;
}

class GraphPainter extends CustomPainter {
  final List<GraphNode> nodes;
  final List<GraphLink> links;
  final PivotType pivot;
  final double minTime;
  final double maxTime;

  /// Decoded contact thumbnails keyed by contact id. A node whose id has an
  /// entry is drawn with the photo clipped to its circle; others fall back to a
  /// solid colored circle. Defaults to empty (no photos).
  final Map<String, ui.Image> photos;

  /// Reference time used to compute relationship strength at paint time.
  /// Injectable for deterministic testing; defaults to the wall clock.
  final DateTime now;

  GraphPainter({
    required this.nodes,
    required this.links,
    required this.pivot,
    required this.minTime,
    required this.maxTime,
    this.photos = const {},
    DateTime? now,
  }) : now = now ?? DateTime.now();

  /// Strength (0..100) for [node]'s contact as of [now].
  double _strengthOf(GraphNode node) => strengthScore(node.data, now: now);

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

      // Optional, cheap edge emphasis: edges between two strong contacts are
      // drawn slightly brighter/thicker. Stays within safe, bounded ranges so
      // it can never produce invalid paint values. Disabled implicitly when
      // strength weighting is off (factor 0) by treating it as a no-op blend.
      final edgeStrength = kStrengthRadiusFactor == 0
          ? 0.0
          : ((_strengthOf(source) + _strengthOf(target)) / 200.0)
              .clamp(0.0, 1.0);
      final alpha = (0.4 + 0.3 * edgeStrength).clamp(0.0, 1.0);
      final width = 1.0 + 0.5 * edgeStrength;

      final paint = Paint()
        ..color = const Color(0xFF444444).withValues(alpha: alpha)
        ..strokeWidth = width
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

      // Radius scaled by relationship strength (RFC-006, U6.3). Guaranteed
      // finite and >= kNodeBaseRadius; equals the original 14 when
      // kStrengthRadiusFactor == 0, preserving prior rendering exactly.
      final radius = nodeRadiusForStrength(_strengthOf(node));
      // Glow tracks the node radius with a fixed offset (matches the original
      // 18 vs 14 = +4 relationship at base).
      final glowRadius = radius + 4;

      // Glow effect
      final glowPaint = Paint()
        ..color = _getNodeColor(node).withValues(alpha: 0.3)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8);
      canvas.drawCircle(center, glowRadius, glowPaint);

      // Node body: the contact's photo (clipped to the circle) when decoded,
      // otherwise a solid colored circle.
      final image = photos[node.id];
      if (image != null) {
        final rect = Rect.fromCircle(center: center, radius: radius);
        canvas.save();
        canvas.clipPath(Path()..addOval(rect));
        paintImage(
          canvas: canvas,
          rect: rect,
          image: image,
          fit: BoxFit.cover,
          filterQuality: FilterQuality.low,
        );
        canvas.restore();
      } else {
        final fillPaint = Paint()
          ..color = _getNodeColor(node)
          ..style = PaintingStyle.fill;
        canvas.drawCircle(center, radius, fillPaint);
      }

      // Stroke — tinted with the node color for photo nodes so each node keeps
      // its identity ring; plain white otherwise (preserves prior look).
      final strokePaint = Paint()
        ..color = image != null ? _getNodeColor(node) : Colors.white
        ..style = PaintingStyle.stroke
        ..strokeWidth = image != null ? 2.5 : 2;
      canvas.drawCircle(center, radius, strokePaint);

      // Label — positioned just outside the (possibly larger) node circle so
      // it never overlaps. Offset preserves the original +18/-6 at base radius.
      final labelDx = center.dx + radius + 4;
      final labelDy = center.dy - 6;

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
      textPainter.paint(canvas, Offset(labelDx, labelDy));
    }
  }

  Color _getNodeColor(GraphNode node) {
    if (pivot == PivotType.time) {
      // Undated contacts fall back to the oldest end of the colour scale.
      final ms =
          node.data.dateMet?.millisecondsSinceEpoch.toDouble() ?? minTime;
      return _magmaColor(ms);
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
