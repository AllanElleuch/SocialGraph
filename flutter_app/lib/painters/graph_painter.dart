import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../models/graph_node.dart';
import '../models/contact.dart';
import '../services/relationship_strength.dart';
import 'star_style.dart';
import 'constellation_layout.dart';

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

  /// Placed tag-groups whose names are drawn faintly near their centers (mutual
  /// constellation view). Empty disables labels.
  final List<ConstellationGroup> constellationLabels;

  /// Relationship label per link, aligned with [links]: the tags the two
  /// endpoints share (e.g. "Work · Gym"). Drawn on the line when zoomed in.
  /// Empty list (or a per-link empty string) draws no label.
  final List<String> edgeLabels;

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
    this.constellationLabels = const [],
    this.edgeLabels = const [],
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

  /// Level-of-detail thresholds (on-screen node radius, logical px):
  ///  - below [_pointPx]: a cheap point of light (no glow/disc/photo);
  ///  - below [_glowPx]: a flat colored disc + core (no soft glow, no rim);
  ///  - below [_photoPx]: a glowing star, but no photo;
  ///  - at/above [_photoPx]: the full star with its photo.
  /// This keeps frames cheap at overview, where ~1500 nodes are all tiny.
  static const double _pointPx = 3.5;
  static const double _glowPx = 7.0;
  static const double _photoPx = 12.0;

  /// Relationship strength (0..100) per node id, computed once for this painter
  /// rather than per frame — recomputing it for ~1500 nodes on every twinkle
  /// frame was a major cost. `late final` so it's built on first paint.
  late final Map<String, double> _strengthById = {
    for (final n in nodes) n.id: strengthScore(n.data, now: now),
  };

  /// Node lookup by id, built once (used by links, stars and edge labels).
  late final Map<String, GraphNode> _byId = {for (final n in nodes) n.id: n};

  double _strengthOf(GraphNode node) =>
      _strengthById[node.id] ?? strengthScore(node.data, now: now);

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

    _drawLinks(canvas, _byId, scale, selectedCluster);
    _drawStars(canvas, scale, visible, time, selectedCluster);
    _drawEdgeLabels(canvas, _byId, scale, visible, selectedCluster);
    _drawConstellationNames(canvas, scale, selectedCluster);
  }

  /// Minimum on-screen zoom before relationship labels appear on lines (kept
  /// hidden at overview so the sky stays clean).
  static const double _edgeLabelScale = 1.25;

  /// Draws the shared-tag relationship label at the midpoint of each line, for
  /// links currently on screen, once zoomed in past [_edgeLabelScale].
  void _drawEdgeLabels(
    Canvas canvas,
    Map<String, GraphNode> byId,
    double scale,
    Rect? visible,
    int? selectedCluster,
  ) {
    if (pivot != PivotType.mutual ||
        edgeLabels.length != links.length ||
        scale < _edgeLabelScale) {
      return;
    }
    final cull = visible?.inflate(80);
    for (var i = 0; i < links.length; i++) {
      final label = edgeLabels[i];
      if (label.isEmpty) continue;
      final s = byId[links[i].sourceId];
      final t = byId[links[i].targetId];
      if (s == null || t == null) continue;
      final mid = Offset((s.x + t.x) / 2, (s.y + t.y) / 2);
      if (cull != null && !cull.contains(mid)) continue;

      var dim = 1.0;
      if (selectedCluster != null) {
        final inSel = clusters[s.id] == selectedCluster &&
            clusters[t.id] == selectedCluster;
        if (!inSel) continue; // hide off-focus labels during selection
        dim = 1.0;
      }
      _drawEdgeLabel(canvas, label, mid, scale, dim);
    }
  }

  void _drawEdgeLabel(
      Canvas canvas, String label, Offset mid, double scale, double dim) {
    // The label keeps growing as the user zooms in (with a high ceiling so it
    // can get large), staying readable. `fc` is the content-space font size
    // that renders to `onScreen` logical px after the view transform.
    final onScreen = (scale * 18.0).clamp(24.0, 160.0);
    final fc = onScreen / scale;
    final tp = TextPainter(
      text: TextSpan(
        text: label,
        style: TextStyle(
          color: const Color(0xFFEEF3FF)
              .withValues(alpha: dim.clamp(0.0, 1.0)),
          fontSize: fc,
          fontWeight: FontWeight.w600,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();

    final padH = fc * 0.5, padV = fc * 0.3;
    final rect = Rect.fromCenter(
      center: mid,
      width: tp.width + padH * 2,
      height: tp.height + padV * 2,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(rect, Radius.circular(fc * 0.5)),
      Paint()
        ..color = const Color(0xFF0A0E1A)
            .withValues(alpha: (0.82 * dim).clamp(0.0, 1.0)),
    );
    tp.paint(canvas, Offset(mid.dx - tp.width / 2, mid.dy - tp.height / 2));
  }

  /// Faint, letter-spaced constellation (tag) names near each group, shown only
  /// at overview-ish zooms so they never clutter a close-up. Off-focus groups
  /// fade when a constellation is selected.
  void _drawConstellationNames(Canvas canvas, double scale, int? selectedCluster) {
    if (constellationLabels.isEmpty || scale > 2.4) return;
    for (final g in constellationLabels) {
      final dim = selectedCluster == null
          ? 1.0
          : (g.index == selectedCluster ? 1.0 : 0.18);
      final tp = TextPainter(
        text: TextSpan(
          text: g.tag.toUpperCase(),
          style: TextStyle(
            color: const Color(0xFFB8C2E0)
                .withValues(alpha: (0.55 * dim).clamp(0.0, 1.0)),
            fontSize: 64 / scale,
            letterSpacing: 10 / scale,
            fontWeight: FontWeight.w600,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      // Centered horizontally, sitting just below the figure's center band.
      tp.paint(
        canvas,
        Offset(g.center.dx - tp.width / 2, g.center.dy + 150 / scale),
      );
    }
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
    // Reused across all nodes to avoid ~thousands of Paint allocations/frame.
    final fill = Paint()..style = PaintingStyle.fill;
    final stroke = Paint()..style = PaintingStyle.stroke;

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

      // Tier 0 — a cheap point of light (overview / very large sets).
      if (screenRadius < _pointPx) {
        fill.color = Color.lerp(color, Colors.white, 0.5)!
            .withValues(alpha: (0.85 * dim * tw).clamp(0.0, 1.0));
        canvas.drawCircle(center, math.max(0.8, 1.4 / scale), fill);
        continue;
      }

      final showGlow = screenRadius >= _glowPx;
      // Soft corona (only once the node is big enough to warrant it).
      if (showGlow) {
        _drawGlow(canvas, center, radius * 3.4, color,
            (0.5 * dim * tw).clamp(0.0, 1.0));
      }

      final image = photos[node.id];
      if (image != null && screenRadius >= _photoPx) {
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
        stroke
          ..strokeWidth = 2.0 / scale
          ..color = color.withValues(alpha: (0.9 * dim).clamp(0.0, 1.0));
        canvas.drawCircle(center, radius, stroke);
      } else {
        // Star body: colored disc with a hot, near-white core.
        fill.color = color.withValues(alpha: (0.95 * dim).clamp(0.0, 1.0));
        canvas.drawCircle(center, radius * 0.95, fill);
        fill.color = Color.lerp(color, Colors.white, 0.75)!
            .withValues(alpha: (dim * tw).clamp(0.0, 1.0));
        canvas.drawCircle(center, radius * 0.45, fill);
        if (showGlow) {
          stroke
            ..strokeWidth = 1.2 / scale
            ..color = Colors.white.withValues(alpha: (0.5 * dim).clamp(0.0, 1.0));
          canvas.drawCircle(center, radius, stroke);
        }
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
    // The name grows as you zoom into a node (capped), and carries a soft
    // shadow so it stays legible over the node's bright glow.
    final onScreen = (scale * 10.0).clamp(15.0, 48.0);
    final fc = onScreen / scale;
    final tp = TextPainter(
      text: TextSpan(
        text: name,
        style: TextStyle(
          color: const Color(0xFFF1F5FF)
              .withValues(alpha: dim.clamp(0.0, 1.0)),
          fontSize: fc,
          fontFamily: 'Inter',
          fontWeight: FontWeight.w600,
          letterSpacing: fc * 0.02,
          shadows: [
            Shadow(
              color: const Color(0xFF000000)
                  .withValues(alpha: (0.85 * dim).clamp(0.0, 1.0)),
              blurRadius: fc * 0.5,
            ),
          ],
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas, Offset(center.dx + radius + fc * 0.45, center.dy - fc / 2));
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
