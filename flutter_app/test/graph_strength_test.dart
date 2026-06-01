import 'package:flutter_test/flutter_test.dart';
import 'package:social_graph/models/contact.dart';
import 'package:social_graph/painters/graph_painter.dart';
import 'package:social_graph/services/relationship_strength.dart';

/// Pure tests for the RFC-006 U6.3 graph strength weighting helper
/// (`nodeRadiusForStrength`). No canvas / widget rendering involved.
void main() {
  group('nodeRadiusForStrength', () {
    test('zero strength yields exactly the base radius', () {
      expect(nodeRadiusForStrength(0.0), kNodeBaseRadius);
    });

    test('result is always finite and >= base across the full 0..100 range',
        () {
      for (var s = 0.0; s <= 100.0; s += 1.0) {
        final r = nodeRadiusForStrength(s);
        expect(r.isFinite, isTrue, reason: 'radius must be finite at s=$s');
        expect(r, greaterThanOrEqualTo(kNodeBaseRadius),
            reason: 'radius must never drop below base at s=$s');
      }
    });

    test('is monotonic non-decreasing in strength', () {
      var previous = nodeRadiusForStrength(0.0);
      for (var s = 0.0; s <= 100.0; s += 0.5) {
        final r = nodeRadiusForStrength(s);
        expect(r, greaterThanOrEqualTo(previous),
            reason: 'radius decreased between ${s - 0.5} and $s');
        previous = r;
      }
    });

    test('a strong node is strictly larger than a weak node', () {
      // Only meaningful while weighting is enabled.
      if (kStrengthRadiusFactor != 0) {
        expect(nodeRadiusForStrength(100.0),
            greaterThan(nodeRadiusForStrength(0.0)));
        expect(nodeRadiusForStrength(80.0),
            greaterThan(nodeRadiusForStrength(20.0)));
      }
    });

    test('matches the documented formula for the default factor', () {
      // radius = base + factor * (strength / 100)
      for (final s in [0.0, 25.0, 50.0, 75.0, 100.0]) {
        final expected =
            kNodeBaseRadius + kStrengthRadiusFactor * (s / 100.0);
        expect(nodeRadiusForStrength(s), closeTo(expected, 1e-9));
      }
    });

    test('full strength stays within the bounded growth window', () {
      // Strong nodes should be larger but never "runaway" — at most base+factor.
      expect(nodeRadiusForStrength(100.0),
          closeTo(kNodeBaseRadius + kStrengthRadiusFactor, 1e-9));
    });

    test('out-of-range and non-finite strengths are clamped safely', () {
      // Above 100 clamps to the 100 result; below 0 clamps to base.
      expect(nodeRadiusForStrength(1000.0),
          closeTo(nodeRadiusForStrength(100.0), 1e-9));
      expect(nodeRadiusForStrength(-50.0), kNodeBaseRadius);

      // Non-finite inputs never produce NaN/infinite radii.
      expect(nodeRadiusForStrength(double.nan), kNodeBaseRadius);
      expect(nodeRadiusForStrength(double.infinity).isFinite, isTrue);
      expect(nodeRadiusForStrength(double.negativeInfinity), kNodeBaseRadius);
    });
  });

  group('strength weighting integration', () {
    Contact contact({
      required String id,
      DateTime? lastInteraction,
      int interactionCount = 0,
      List<String> connections = const [],
      List<String> tags = const [],
    }) {
      return Contact(
        id: id,
        firstName: 'C',
        lastName: id,
        tags: tags,
        locationMet: '',
        connections: connections,
        lastInteraction: lastInteraction,
        interactions: List.generate(
          interactionCount,
          (i) => InteractionEvent(
            id: '$id-$i',
            date: DateTime(2026, 1, 1),
            type: InteractionType.note,
          ),
        ),
      );
    }

    test('a clearly strong contact maps to a larger radius than a weak one',
        () {
      final now = DateTime(2026, 6, 1);

      final strong = contact(
        id: 'strong',
        lastInteraction: now, // full recency
        interactionCount: 30,
        connections: List.generate(15, (i) => 'c$i'),
        tags: const ['family'],
      );
      final weak = contact(id: 'weak'); // no signals at all

      final strongScore = strengthScore(strong, now: now);
      final weakScore = strengthScore(weak, now: now);

      expect(strongScore, greaterThan(weakScore));
      expect(
        nodeRadiusForStrength(strongScore),
        greaterThan(nodeRadiusForStrength(weakScore)),
      );

      // Sanity: a zero-signal contact renders at the base radius.
      expect(nodeRadiusForStrength(weakScore), kNodeBaseRadius);
    });
  });
}
