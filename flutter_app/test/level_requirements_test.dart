import 'package:flutter_test/flutter_test.dart';
import 'package:social_graph/stats/level.dart';
import 'package:social_graph/stats/level_requirements.dart';

LevelMetrics _m({
  int contacts = 0,
  int interactions = 0,
  int connections = 0,
  int distinctPlaces = 0,
  int reconnects = 0,
  int strongRelationships = 0,
}) => LevelMetrics(
  contacts: contacts,
  interactions: interactions,
  connections: connections,
  distinctPlaces: distinctPlaces,
  reconnects: reconnects,
  strongRelationships: strongRelationships,
);

void main() {
  group('buildLevelRequirements', () {
    test('covers levels 2..10 with progress', () {
      final reqs = buildLevelRequirements(_m(contacts: 3, interactions: 2));
      expect(reqs.keys, containsAll([2, 3, 4, 5, 6, 7, 8, 9, 10]));
      expect(reqs[2]!.met, isTrue); // 3 of 3 contacts
      expect(reqs[3]!.met, isFalse); // 2 of 5 interactions
      expect(reqs[3]!.progressLabel, '2 / 5');
    });
  });

  group('gatedLevel', () {
    test('XP alone is not enough — the hard requirement also gates', () {
      // xp past level 4 (600), but only 1 contact → fails L2 requirement (3).
      final reqs = buildLevelRequirements(_m(contacts: 1, interactions: 100));
      expect(gatedLevel(1000, reqs), 1);
    });

    test('advances when both XP and requirement are met, sequentially', () {
      // Meets L2 (3 contacts) and L3 (5 interactions), xp past level 3 (300).
      final reqs = buildLevelRequirements(_m(contacts: 3, interactions: 5));
      expect(gatedLevel(300, reqs), 3);
      // …but not L4 (needs 10 contacts) even with more XP.
      expect(gatedLevel(1000, reqs), 3);
    });

    test('requirement met but XP missing also blocks', () {
      final reqs = buildLevelRequirements(_m(contacts: 50, interactions: 100));
      // Requirements for many levels satisfied, but only 50 XP → still level 1.
      expect(gatedLevel(50, reqs), 1);
    });

    test('prestige past the apex is XP-only', () {
      final reqs = buildLevelRequirements(
        _m(
          contacts: 50,
          interactions: 100,
          connections: 20,
          distinctPlaces: 5,
          reconnects: 5,
          strongRelationships: 10,
        ),
      );
      // All requirements met; xp at level 11 (5500) → prestige level 11.
      expect(gatedLevel(5500, reqs), 11);
    });
  });

  group('LevelStats.gated', () {
    test('exposes the requirement blocking the next level', () {
      final reqs = buildLevelRequirements(_m(contacts: 3, interactions: 5));
      final l = LevelStats.gated(xp: 1000, requirements: reqs);
      expect(l.level, 3);
      // L4 needs 10 contacts; XP (1000) already past level 4 (600).
      expect(l.nextRequirement?.level, 4);
      expect(l.blockedByRequirement, isTrue);
      expect(l.nextLevelLabel, contains('contacts'));
    });
  });
}
