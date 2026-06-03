import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../models/graph_node.dart';
import '../models/contact.dart';
import '../services/relationship_strength.dart';
import 'star_style.dart';

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

/// Renders the mutuals graph as a constellation: contacts are stars (sized by
/// relationship strength, colored by [starColorMode]) with a soft glow and
/// gentle twinkle, connected by faint glowing constellation lines. Selecting a
/// contact illuminates its constellation (connected component) and dims the
/// rest; labels and photo-orbs fade in as you zoom.
class GraphPainter extends CustomPainter {
  final List<GraphNode> nodes;
  final List<GraphLink> links;
  final PivotType pivot;
  final double minTime;
  final double maxTime;

  /// Decoded contact thumbnails keyed by contact id. When a node's photo is
  /// available and the view is zoomed in enough, it blooms into a photo-orb;
  /// otherwise the node is a pure star. Defaults to empty (no photos).
  final Map<String, ui.Image> photos;

  /// Constellation (connected-component) index per contact id, for cluster
  /// coloring and selection illumination. Empty disables both.
  final Map<String, int> clusters;

  /// Whether stars are colored by relationship temperature or by constellation.
  final StarColorMode starColorMode;

  /// The currently-selected contact id. When set (and present in [clusters]),
  /// its constellation stays bright while the rest of the sky dims.
  final String? selectedId;

  /// The live view transform (from the InteractiveViewer's controller), used to
  /// derive zoom scale for level-of-detail, label/photo gating, and viewport
  /// culling. Null in tests → treated as identity (scale 1, no culling).
  final ValueListenable<Matrix4>? viewTransform;

  /// Drives the twinkle animation; its 0..1 value maps to a seamless phase.
  /// Null in tests → static (no twinkle motion).
  final Animation<double>? twinkle;

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
    this.clusters = const {},
    this.starColorMode = StarColorMode.temperature,
    this.selectedId,
    this.viewTransform,
    this.twinkle,
    DateTime? now,
  })  : now = now ?? DateTime.now(),
        super(repaint: Listenable.merge([viewTransform, twinkle]));

  /// One reusable white radial-gradient (bright center → transparent edge),
  /// drawn at unit radius and tinted per star via a color filter. Avoids
  /// per-star shader/blur allocation — key to staying smooth at ~1500 nodes.
  static final ui.Gradient _glowGradient = ui.Gradient.radial(
    Offset.zero,
    1.0,
    const [Color(0xFFFFFFFF), Color(0x00FFFFFF)],
    const [0.0, 1.0],
  );

  /// Show labels only past this on-screen zoom scale (keeps the far view clean).
  static const double _labelScale = 1.6;

  /// Below this on-screen radius a star collapses to a cheap point of light
  /// (a photo would be sub-pixel and meaningless there).
  static const double _pointPx = 2.5;

  double _strengthOf(GraphNode node) => strengthScore(node.data, now: now);

  Color _starColor(GraphNode node, double strength) {
    if (pivot == PivotType.time) {
      final ms = node.data.dateMet?.millisecondsSinceEpoch.toDouble() ?? minTime;
      return _magmaColor(ms);
    }
    if (starColorMode == StarColorMode.cluster && clusters.isNotEmpty) {
      return clusterColor(clusters[node.id] ?? 0);
    }
    return starTemperatureColor(strength);
  }

  @override
  void paint(Canvas canvas, Size size) {
    final matrix = viewTransform?.value;
    final scale = (matrix?.getMaxScaleOnAxis() ?? 1.0).clamp(0.05, 64.0);
    final visible = _visibleRect(matrix, size);
    // value 0..1 → 0..2π so sin() is seamless across animation loops.
    final time = (twinkle?.value ?? 0.0) * 2 * math.pi;
    final selectedCluster =
        (selectedId != null && clusters.isNotEmpty) ? clusters[selectedId] : null;

    final byId = {for (final n in nodes) n.id: n};

    _drawLinks(canvas, byId, scale, selectedCluster);
    _drawStars(canvas, scale, visible, time, selectedCluster);
  }

  Rect? _visibleRect(Matrix4? matrix, Size size) {
    if (matrix == null) return null;
    final inv = Matrix4.tryInvert(matrix);
    if (inv == null) return null;
    return MatrixUtils.transformRect(inv, Offset.zero & size);
  }

  // ── Constellation lines ────────────────────────────────────────────────

  void _drawLinks(
    Canvas canvas,
    Map<String, GraphNode> byId,
    double scale,
    int? selectedCluster,
  ) {
    for (final link in links) {
      final source = byId[link.sourceId];
      final target = byId[link.targetId];
      if (source == null || target == null) continue;

      final edgeStrength = kStrengthRadiusFactor == 0
          ? 0.0
          : ((_strengthOf(source) + _strengthOf(target)) / 200.0)
              .clamp(0.0, 1.0);

      // Selection: a line in the chosen constellation glows; others fade back.
      double dim = 1.0;
      if (selectedCluster != null) {
        final inSel = clusters[source.id] == selectedCluster &&
            clusters[target.id] == selectedCluster;
        dim = inSel ? 1.0 : 0.12;
      }

      final alpha = ((0.18 + 0.22 * edgeStrength) * dim).clamp(0.0, 1.0);
      final width = (0.6 + 0.8 * edgeStrength) / scale;
      final a = Offset(source.x, source.y);
      final b = Offset(target.x, target.y);

      if (link.type == 'time') {
        final paint = Paint()
          ..color = const Color(0xFFB0C4FF).withValues(alpha: alpha)
          ..strokeWidth = width
          ..style = PaintingStyle.stroke;
        _drawDashedLine(canvas, a, b, paint, 4, 4);
        continue;
      }

      // Soft glow underlay for in-focus lines, then a crisp core line.
      if (dim > 0.5) {
        canvas.drawLine(
          a,
          b,
          Paint()
            ..color = const Color(0xFF93C5FD)
                .withValues(alpha: (alpha * 0.6).clamp(0.0, 1.0))
            ..strokeWidth = width * 3
            ..style = PaintingStyle.stroke
            ..strokeCap = StrokeCap.round,
        );
      }
      canvas.drawLine(
        a,
        b,
        Paint()
          ..color = const Color(0xFFDCE8FF).withValues(alpha: alpha)
          ..strokeWidth = width
          ..style = PaintingStyle.stroke,
      );
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

  // ── Stars ──────────────────────────────────────────────────────────────

  void _drawStars(
    Canvas canvas,
    double scale,
    Rect? visible,
    double time,
    int? selectedCluster,
  ) {
    final cull = visible?.inflate(120);
    for (final node in nodes) {
      final center = Offset(node.x, node.y);
      if (cull != null && !cull.contains(center)) continue;

      final strength = _strengthOf(node);
      final radius = nodeRadiusForStrength(strength);
      final color = _starColor(node, strength);

      final dim = selectedCluster == null
          ? 1.0
          : (clusters[node.id] == selectedCluster ? 1.0 : 0.16);
      final tw = twinkleBrightness(time, twinklePhaseFor(node.id));
      final screenRadius = radius * scale;

      // Far away: a cheap point of light, no glow/photo.
      if (screenRadius < _pointPx) {
        final r = math.max(0.8, 1.4 / scale);
        canvas.drawCircle(
          center,
          r,
          Paint()
            ..color = Color.lerp(color, Colors.white, 0.5)!
                .withValues(alpha: (0.85 * dim * tw).clamp(0.0, 1.0)),
        );
        continue;
      }

      // Soft corona.
      _drawGlow(canvas, center, radius * 3.4,
          color, (0.5 * dim * tw).clamp(0.0, 1.0));

      // Photos always show on full stars (any zoom past the point threshold),
      // not just when zoomed in close.
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
        // Colored corona ring keeps the star identity around the photo.
        canvas.drawCircle(
          center,
          radius,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 2.0 / scale
            ..color = color.withValues(alpha: (0.9 * dim).clamp(0.0, 1.0)),
        );
      } else {
        // Star body: colored disc with a hot, near-white core.
        canvas.drawCircle(
          center,
          radius * 0.95,
          Paint()..color = color.withValues(alpha: (0.95 * dim).clamp(0.0, 1.0)),
        );
        canvas.drawCircle(
          center,
          radius * 0.45,
          Paint()
            ..color = Color.lerp(color, Colors.white, 0.75)!
                .withValues(alpha: (dim * tw).clamp(0.0, 1.0)),
        );
        // Crisp rim.
        canvas.drawCircle(
          center,
          radius,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.2 / scale
            ..color = Colors.white.withValues(alpha: (0.5 * dim).clamp(0.0, 1.0)),
        );
      }

      // Labels fade in when zoomed in; hidden for dimmed (off-constellation)
      // stars so the focused constellation reads clearly.
      if (scale >= _labelScale && dim > 0.5) {
        _drawLabel(canvas, node.name, center, radius, scale, dim);
      }
    }
  }

  void _drawGlow(
      Canvas canvas, Offset center, double radius, Color color, double alpha) {
    if (alpha <= 0) return;
    final paint = Paint()
      ..shader = _glowGradient
      ..colorFilter = ColorFilter.mode(
        color.withValues(alpha: alpha),
        BlendMode.srcIn,
      );
    canvas.save();
    canvas.translate(center.dx, center.dy);
    canvas.scale(radius);
    canvas.drawCircle(Offset.zero, 1.0, paint);
    canvas.restore();
  }

  void _drawLabel(Canvas canvas, String name, Offset center, double radius,
      double scale, double dim) {
    final tp = TextPainter(
      text: TextSpan(
        text: name,
        style: TextStyle(
          color: const Color(0xFFE2E8F0)
              .withValues(alpha: (0.9 * dim).clamp(0.0, 1.0)),
          // Compensate for the view transform so labels stay a constant size.
          fontSize: 12 / scale,
          fontFamily: 'Inter',
          letterSpacing: 0.5 / scale,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas, Offset(center.dx + radius + 4 / scale, center.dy - 6 / scale));
  }

  // Simplified Magma colorscale interpolation (time pivot only).
  Color _magmaColor(double value) {
    if (maxTime == minTime) return const Color(0xFF6366f1);
    final t = ((value - minTime) / (maxTime - minTime)).clamp(0.0, 1.0);
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
