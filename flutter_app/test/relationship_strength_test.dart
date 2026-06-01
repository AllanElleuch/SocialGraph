import 'package:flutter_test/flutter_test.dart';
import 'package:social_graph/models/contact.dart';
import 'package:social_graph/services/relationship_strength.dart';

/// Builds a [Contact] with sensible defaults for scoring tests.
Contact buildContact({
  DateTime? lastInteraction,
  List<InteractionEvent> interactions = const [],
  List<String> connections = const [],
  List<String> tags = const [],
}) {
  return Contact(
    id: 'c1',
    firstName: 'Test',
    lastName: 'Contact',
    tags: tags,
    locationMet: 'Online',
    dateMet: DateTime(2020, 1, 1),
    connections: connections,
    lastInteraction: lastInteraction,
    interactions: interactions,
  );
}

InteractionEvent event(DateTime date) => InteractionEvent(
      id: 'e-${date.microsecondsSinceEpoch}',
      date: date,
      type: InteractionType.note,
    );

void main() {
  final now = DateTime(2026, 6, 1, 12);

  group('strengthScore', () {
    test('recent + frequent + connected scores higher than stale + isolated',
        () {
      final strong = buildContact(
        lastInteraction: now.subtract(const Duration(days: 1)),
        interactions:
            List.generate(20, (i) => event(now.subtract(Duration(days: i)))),
        connections: List.generate(12, (i) => 'conn-$i'),
        tags: const ['Family'],
      );
      final weak = buildContact(
        lastInteraction: now.subtract(const Duration(days: 800)),
        interactions: const [],
        connections: const [],
        tags: const [],
      );

      final strongScore = strengthScore(strong, now: now);
      final weakScore = strengthScore(weak, now: now);

      expect(strongScore, greaterThan(weakScore));
    });

    test('score is always within 0..100 across varied inputs', () {
      final samples = <Contact>[
        buildContact(),
        buildContact(lastInteraction: now),
        buildContact(
          lastInteraction: now.add(const Duration(days: 5)), // future-dated
          interactions: List.generate(
              200, (i) => event(now.subtract(Duration(days: i)))),
          connections: List.generate(500, (i) => 'c$i'),
          tags: const ['Family', 'Friend'],
        ),
        buildContact(lastInteraction: now.subtract(const Duration(days: 5000))),
      ];

      for (final c in samples) {
        final score = strengthScore(c, now: now);
        expect(score, greaterThanOrEqualTo(0.0));
        expect(score, lessThanOrEqualTo(100.0));
      }
    });

    test('null lastInteraction contributes nothing from recency', () {
      final withRecency = buildContact(lastInteraction: now);
      final withoutRecency = buildContact(lastInteraction: null);

      expect(
        strengthScore(withRecency, now: now),
        greaterThan(strengthScore(withoutRecency, now: now)),
      );
    });

    test('deterministic for a fixed input and now', () {
      final c = buildContact(
        lastInteraction: now.subtract(const Duration(days: 10)),
        interactions:
            List.generate(5, (i) => event(now.subtract(Duration(days: i)))),
        connections: const ['a', 'b', 'c'],
        tags: const ['Friend'],
      );

      final first = strengthScore(c, now: now);
      final second = strengthScore(c, now: now);
      expect(first, equals(second));
    });

    test('close tag boost increases score, case-insensitively', () {
      final base = buildContact(lastInteraction: now);
      final tagged = buildContact(lastInteraction: now, tags: const ['family']);

      expect(
        strengthScore(tagged, now: now),
        greaterThan(strengthScore(base, now: now)),
      );
    });

    test('recency decays: more recent scores higher than older', () {
      final recent =
          buildContact(lastInteraction: now.subtract(const Duration(days: 1)));
      final older =
          buildContact(lastInteraction: now.subtract(const Duration(days: 90)));

      expect(
        strengthScore(recent, now: now),
        greaterThan(strengthScore(older, now: now)),
      );
    });
  });

  group('strengthLabel', () {
    test('bands are correct at boundaries', () {
      expect(strengthLabel(0), 'Weak');
      expect(strengthLabel(32.9), 'Weak');
      expect(strengthLabel(33), 'Moderate');
      expect(strengthLabel(65.9), 'Moderate');
      expect(strengthLabel(66), 'Strong');
      expect(strengthLabel(100), 'Strong');
    });
  });
}
