import 'package:flutter_test/flutter_test.dart';
import 'package:social_graph/models/contact.dart';
import 'package:social_graph/stats/quests.dart';

/// A Wednesday; its Monday-anchored week starts 2026-06-01.
final _now = DateTime(2026, 6, 3, 12, 0);
final _weekStart = DateTime(2026, 6, 1);

Contact _contact({
  required String id,
  DateTime? dateMet,
  List<InteractionEvent> interactions = const [],
}) {
  final last = interactions.isEmpty
      ? null
      : interactions.map((e) => e.date).reduce((a, b) => a.isAfter(b) ? a : b);
  return Contact(
    id: id,
    firstName: 'Test',
    lastName: id,
    tags: const [],
    locationMet: '',
    connections: const [],
    dateMet: dateMet,
    interactions: interactions,
    lastInteraction: last,
  );
}

InteractionEvent _e(String id, DateTime date, InteractionType type) =>
    InteractionEvent(id: id, date: date, type: type);

void main() {
  group('questsForWeek selection', () {
    test('offers exactly kQuestsPerWeek distinct quests', () {
      final quests = questsForWeek(_weekStart);
      expect(quests, hasLength(kQuestsPerWeek));
      expect(quests.map((q) => q.id).toSet(), hasLength(kQuestsPerWeek));
    });

    test('is stable within a week', () {
      expect(
        questsForWeek(_weekStart).map((q) => q.id).toList(),
        questsForWeek(_weekStart).map((q) => q.id).toList(),
      );
    });

    test('rotates between consecutive weeks', () {
      final thisWeek = questsForWeek(_weekStart).map((q) => q.id).toList();
      final nextWeek = questsForWeek(_weekStart.add(const Duration(days: 7)))
          .map((q) => q.id)
          .toList();
      expect(thisWeek, isNot(equals(nextWeek)));
    });
  });

  group('WeekActivity.from', () {
    test('only counts activity inside the current week', () {
      final contacts = [
        _contact(
          id: 'a',
          dateMet: _weekStart, // new this week
          interactions: [
            _e('1', _now, InteractionType.call),
            _e('2', _now, InteractionType.text),
            // Last week: must be ignored.
            _e('3', _weekStart.subtract(const Duration(days: 2)),
                InteractionType.call),
          ],
        ),
        _contact(
          id: 'b',
          dateMet: DateTime(2025, 1, 1), // met long ago
          interactions: [_e('4', _now, InteractionType.meeting)],
        ),
      ];

      final a = WeekActivity.from(contacts, weekStart: _weekStart);
      expect(a.interactionCount, 3); // 2 from a + 1 from b this week
      expect(a.countOf(InteractionType.call), 1);
      expect(a.distinctContacts, 2);
      expect(a.distinctTypes, 3); // call, text, meeting
      expect(a.newContacts, 1); // only a was met this week
    });

    test('detects a reconnect whose later interaction lands this week', () {
      final contacts = [
        _contact(
          id: 'a',
          interactions: [
            _e('old', _weekStart.subtract(const Duration(days: 120)),
                InteractionType.call),
            _e('new', _now, InteractionType.call),
          ],
        ),
      ];
      final a = WeekActivity.from(contacts, weekStart: _weekStart);
      expect(a.reconnects, 1);
    });
  });

  group('WeeklyQuests.from progress & claim state', () {
    test('marks goal met and ready-to-claim when unclaimed', () {
      // Drive a known quest: log enough interactions to satisfy any
      // interaction-count quest, then assert ready-to-claim semantics.
      final contacts = [
        _contact(
          id: 'a',
          interactions: [
            for (var i = 0; i < 6; i++)
              _e('$i', _now, InteractionType.values[i % 5]),
          ],
        ),
      ];

      final quests = WeeklyQuests.from(
        contacts,
        now: _now,
        claimedKeys: const {},
      );

      expect(quests.quests, hasLength(kQuestsPerWeek));
      // Any quest whose goal is met must be ready to claim while unclaimed.
      for (final q in quests.quests.where((q) => q.goalMet)) {
        expect(q.isReadyToClaim, isTrue);
      }
    });

    test('a claimed quest is no longer ready to claim', () {
      final contacts = [
        _contact(
          id: 'a',
          interactions: [
            for (var i = 0; i < 6; i++) _e('$i', _now, InteractionType.text),
          ],
        ),
      ];

      final unclaimed =
          WeeklyQuests.from(contacts, now: _now, claimedKeys: const {});
      final met = unclaimed.quests.firstWhere((q) => q.goalMet);

      final claimed = WeeklyQuests.from(
        contacts,
        now: _now,
        claimedKeys: {met.key},
      );
      final sameQuest = claimed.quests.firstWhere((q) => q.id == met.id);

      expect(sameQuest.claimed, isTrue);
      expect(sameQuest.isReadyToClaim, isFalse);
      expect(sameQuest.goalMet, isTrue);
    });

    test('reset label counts down to the weekly reset', () {
      final quests =
          WeeklyQuests.from(const [], now: _now, claimedKeys: const {});
      // Wed 06-03 -> week ends Mon 06-08, 5 days out.
      expect(quests.daysUntilReset(_now), 5);
      expect(quests.resetLabel(_now), 'Resets in 5 days');
    });
  });
}
