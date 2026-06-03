import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:social_graph/models/contact.dart';
import 'package:social_graph/stats/achievements.dart';
import 'package:social_graph/stats/level.dart';
import 'package:social_graph/stats/network_stats.dart';
import 'package:social_graph/stats/streaks.dart';

/// Fixed "now" so every assertion is deterministic. A Wednesday.
final _now = DateTime(2026, 6, 3, 12, 0);

Contact _contact({
  required String id,
  String firstName = 'Test',
  String lastName = 'User',
  List<String> tags = const [],
  List<String> connections = const [],
  String locationMet = '',
  DateTime? dateMet,
  DateTime? birthday,
  int? reminderCadenceDays,
  ContactOrigin? origin,
  List<InteractionEvent> interactions = const [],
  Uint8List? photoThumbnail,
}) {
  final last = interactions.isEmpty
      ? null
      : interactions
          .map((e) => e.date)
          .reduce((a, b) => a.isAfter(b) ? a : b);
  return Contact(
    id: id,
    firstName: firstName,
    lastName: lastName,
    tags: tags,
    locationMet: locationMet,
    connections: connections,
    dateMet: dateMet,
    birthday: birthday,
    reminderCadenceDays: reminderCadenceDays,
    origin: origin,
    interactions: interactions,
    lastInteraction: last,
    photoThumbnail: photoThumbnail,
  );
}

InteractionEvent _event(String id, DateTime date,
        [InteractionType type = InteractionType.note]) =>
    InteractionEvent(id: id, date: date, type: type);

void main() {
  group('level / XP', () {
    test('xp sums weighted actions', () {
      expect(
        totalXp(
          contactCount: 3,
          interactionCount: 4,
          connectionCount: 2,
          reconnectCount: 1,
        ),
        // 3*10 + 4*5 + 2*2 + 1*15 = 30+20+4+15 = 69
        69,
      );
    });

    test('level boundaries are 0, 100, 300, 600', () {
      expect(levelForXp(0), 1);
      expect(levelForXp(99), 1);
      expect(levelForXp(100), 2);
      expect(levelForXp(299), 2);
      expect(levelForXp(300), 3);
      expect(levelForXp(600), 4);
    });

    test('progress and labels', () {
      final l = LevelStats.fromXp(200); // level 2, span 100..300
      expect(l.level, 2);
      expect(l.xpIntoLevel, 100);
      expect(l.xpSpanThisLevel, 200);
      expect(l.progress, closeTo(0.5, 1e-9));
      expect(l.xpToNextLevel, 100);
      expect(l.rankTitle, 'Acquaintance');
    });

    test('rank titles climb with level', () {
      expect(rankTitleForLevel(1), 'Acquaintance');
      expect(rankTitleForLevel(3), 'Networker');
      expect(rankTitleForLevel(5), 'Connector');
      expect(rankTitleForLevel(7), 'Super Connector');
      expect(rankTitleForLevel(10), 'Networking Legend');
    });
  });

  group('weekly streaks', () {
    test('weekStart anchors to Monday', () {
      // 2026-06-03 is a Wednesday -> Monday is 2026-06-01.
      expect(weekStart(_now), DateTime(2026, 6, 1));
    });

    test('counts consecutive active weeks ending this week', () {
      final dates = [
        _now, // this week
        _now.subtract(const Duration(days: 7)), // last week
        _now.subtract(const Duration(days: 14)), // 2 weeks ago
        _now.subtract(const Duration(days: 35)), // gap -> breaks the run
      ];
      final s = StreakStats.from(dates, now: _now);
      expect(s.currentWeeks, 3);
      expect(s.isActive, isTrue);
      expect(s.last12Weeks.first, isTrue); // this week active
    });

    test('one-week grace keeps the streak alive', () {
      final dates = [
        _now.subtract(const Duration(days: 7)), // last week only
        _now.subtract(const Duration(days: 14)),
      ];
      final s = StreakStats.from(dates, now: _now);
      expect(s.currentWeeks, 2);
    });

    test('a two-week gap resets the current streak to zero', () {
      final dates = [_now.subtract(const Duration(days: 21))];
      final s = StreakStats.from(dates, now: _now);
      expect(s.currentWeeks, 0);
      expect(s.longestWeeks, 1);
    });

    test('reconnect counts gaps longer than the threshold', () {
      final dates = [
        DateTime(2026, 1, 1),
        DateTime(2026, 1, 5), // small gap, no reconnect
        DateTime(2026, 5, 1), // big gap -> reconnect
      ];
      expect(reconnectCountForDates(dates, gapDays: 90), 1);
    });
  });

  group('NetworkStats.from', () {
    test('empty network is safe and zeroed', () {
      final s = NetworkStats.from([], now: _now);
      expect(s.level.level, 1);
      expect(s.streak.currentWeeks, 0);
      expect(s.health.score, isNull);
      expect(s.growth.total, 0);
      expect(s.interactions.total, 0);
      expect(s.unlockedBadgeCount, 0);
    });

    test('aggregates interactions, growth, geography and badges', () {
      final contacts = [
        _contact(
          id: 'a',
          firstName: 'Ada',
          tags: const ['Friends'],
          locationMet: 'Paris',
          dateMet: DateTime(2026, 5, 10),
          connections: const ['b'],
          interactions: [
            _event('1', _now, InteractionType.call),
            _event('2', _now.subtract(const Duration(days: 7)),
                InteractionType.text),
          ],
        ),
        _contact(
          id: 'b',
          firstName: 'Bob',
          locationMet: 'Paris',
          dateMet: DateTime(2026, 5, 12),
          connections: const ['a'],
          origin: ContactOrigin.imported(platform: 'iOS'),
          interactions: [_event('3', _now, InteractionType.meeting)],
        ),
      ];

      final s = NetworkStats.from(contacts, now: _now);

      expect(s.interactions.total, 3);
      expect(s.interactions.countOf(InteractionType.call), 1);
      expect(s.interactions.mostContacted?.id, 'a');
      expect(s.interactions.mostContactedCount, 2);

      expect(s.growth.total, 2);
      expect(s.growth.manualCount, 1);
      expect(s.growth.importedCount, 1);

      expect(s.geography.distinctPlaces, 1); // both Paris
      expect(s.geography.topPlaces.first.place, 'Paris');
      expect(s.geography.topPlaces.first.count, 2);

      // First-contact badge unlocked once any contact exists.
      final first =
          s.achievements.firstWhere((a) => a.id == AchievementId.firstContact);
      expect(first.unlocked, isTrue);
      expect(s.streak.currentWeeks, greaterThanOrEqualTo(1));
    });

    test('legacy imports (Imported tag, no origin) count as imported', () {
      // Contacts imported before provenance tracking carry the "Imported" tag
      // but have origin == null; they must still be classified as imported so
      // the growth card agrees with the tag breakdown.
      final contacts = [
        _contact(id: 'legacy', tags: const ['Imported']),
        _contact(id: 'manual'),
        _contact(id: 'new', origin: ContactOrigin.imported(platform: 'iOS')),
      ];

      final s = NetworkStats.from(contacts, now: _now);

      expect(s.growth.importedCount, 2); // legacy tag + structured origin
      expect(s.growth.manualCount, 1);
    });

    test('bonusXp from claimed quests folds into the level standing', () {
      final contacts = [_contact(id: 'a')];
      final base = NetworkStats.from(contacts, now: _now);
      final boosted = NetworkStats.from(contacts, now: _now, bonusXp: 300);

      expect(boosted.level.xp, base.level.xp + 300);
      expect(boosted.level.level, greaterThan(base.level.level));
    });

    test('picture-perfect badge unlocks only when every contact has a photo',
        () {
      final photo = Uint8List.fromList([1, 2, 3]);

      AchievementStat badgeOf(List<Contact> contacts) =>
          NetworkStats.from(contacts, now: _now)
              .achievements
              .firstWhere((a) => a.id == AchievementId.picturePerfect);

      // Empty network: locked, not a trivial 0/0 unlock.
      expect(badgeOf(const []).unlocked, isFalse);

      // Some contacts missing a photo: locked, progress reflects the share.
      final mixed = badgeOf([
        _contact(id: 'a', photoThumbnail: photo),
        _contact(id: 'b'),
      ]);
      expect(mixed.unlocked, isFalse);
      expect(mixed.current, 1);
      expect(mixed.target, 2);
      expect(mixed.progressLabel, '1 / 2');

      // Every contact has a photo: unlocked.
      final all = badgeOf([
        _contact(id: 'a', photoThumbnail: photo),
        _contact(id: 'b', photoThumbnail: photo),
      ]);
      expect(all.unlocked, isTrue);
    });

    test('health reflects overdue cadence and surfaces most neglected', () {
      final contacts = [
        // On track: contacted today, 30-day cadence.
        _contact(
          id: 'fresh',
          reminderCadenceDays: 30,
          interactions: [_event('1', _now)],
        ),
        // Overdue: last contact 200 days ago, 30-day cadence.
        _contact(
          id: 'stale',
          firstName: 'Stale',
          reminderCadenceDays: 30,
          interactions: [
            _event('2', _now.subtract(const Duration(days: 200))),
          ],
        ),
      ];

      final s = NetworkStats.from(contacts, now: _now);
      expect(s.health.onTrackCount, 1);
      expect(s.health.overdueCount, 1);
      expect(s.health.score, 50); // 1 of 2 tracked on track
      expect(s.health.mostNeglected?.id, 'stale');
      expect(s.health.mostNeglectedDays, greaterThan(0));
    });

    test('upcoming birthday within 30 days is surfaced', () {
      final contacts = [
        _contact(
          id: 'bday',
          birthday: DateTime(1990, 6, 10), // 7 days after fixed now
        ),
      ];
      final s = NetworkStats.from(contacts, now: _now);
      expect(s.health.upcomingBirthdays, hasLength(1));
      expect(s.health.upcomingBirthdays.first.inDays, 7);
    });
  });
}
