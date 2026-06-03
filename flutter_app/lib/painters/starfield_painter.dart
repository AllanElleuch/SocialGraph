import 'dart:math' as math;
import 'package:flutter/material.dart';

import 'star_style.dart';

/// A fixed background star (normalized 0..1 coords so it scales to any size).
class _BgStar {
  final double nx;
  final double ny;
  final double radius;
  final double phase;
  final double baseAlpha;
  const _BgStar(this.nx, this.ny, this.radius, this.phase, this.baseAlpha);
}

/// A soft nebula cloud (normalized center + radius fraction + tint).
class _Nebula {
  final double nx;
  final double ny;
  final double radiusFrac;
  final Color color;
  const _Nebula(this.nx, this.ny, this.radiusFrac, this.color);
}

/// Paints the deep-space backdrop behind the constellation: a dark gradient,
/// a couple of faint nebula clouds, and a seeded field of distant twinkling
/// stars. This layer is NOT transformed by the InteractiveViewer, so it reads
/// as a fixed, far-away sky while the constellation pans/zooms in front of it.
class StarfieldPainter extends CustomPainter {
  /// Drives subtle twinkle. Null → static.
  final Animation<double>? twinkle;

  StarfieldPainter({this.twinkle}) : super(repaint: twinkle);

  /// Stable star field (seeded once) so it doesn't shimmer-jump between frames.
  static final List<_BgStar> _stars = _generateStars();

  static const List<_Nebula> _nebulae = [
    _Nebula(0.25, 0.30, 0.55, Color(0xFF3B2E83)), // indigo
    _Nebula(0.78, 0.62, 0.50, Color(0xFF1E5F74)), // teal
    _Nebula(0.55, 0.85, 0.45, Color(0xFF5B2A86)), // violet
  ];

  static List<_BgStar> _generateStars() {
    final rng = math.Random(20260603); // fixed seed → stable sky
    return List.generate(220, (_) {
      final depth = rng.nextDouble(); // 0 = far/faint, 1 = near/bright
      return _BgStar(
        rng.nextDouble(),
        rng.nextDouble(),
        0.4 + depth * 1.3,
        rng.nextDouble() * 2 * math.pi,
        0.18 + depth * 0.55,
      );
    });
  }

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;

    // Base gradient: deep space, slightly brighter toward the center.
    canvas.drawRect(
      rect,
      Paint()
        ..shader = const RadialGradient(
          center: Alignment.center,
          radius: 0.9,
          colors: [Color(0xFF131A33), Color(0xFF05070F), Color(0xFF02030A)],
          stops: [0.0, 0.6, 1.0],
        ).createShader(rect),
    );

    // Nebula clouds.
    for (final n in _nebulae) {
      final center = Offset(n.nx * size.width, n.ny * size.height);
      final radius = n.radiusFrac * size.shortestSide;
      canvas.drawCircle(
        center,
        radius,
        Paint()
          ..shader = RadialGradient(
            colors: [
              n.color.withValues(alpha: 0.16),
              n.color.withValues(alpha: 0.0),
            ],
          ).createShader(Rect.fromCircle(center: center, radius: radius)),
      );
    }

    // Distant stars with a gentle twinkle.
    final time = (twinkle?.value ?? 0.0) * 2 * math.pi;
    final paint = Paint()..color = Colors.white;
    for (final s in _stars) {
      final tw = twinkleBrightness(time, s.phase, amount: 0.35);
      paint.color = Colors.white.withValues(
        alpha: (s.baseAlpha * tw).clamp(0.0, 1.0),
      );
      canvas.drawCircle(
        Offset(s.nx * size.width, s.ny * size.height),
        s.radius,
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant StarfieldPainter oldDelegate) => true;
}
