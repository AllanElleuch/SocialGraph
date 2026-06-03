import 'package:flutter_test/flutter_test.dart';
import 'package:social_graph/painters/constellation_layout.dart';

List<({String id, String tag})> items(Map<String, int> tagCounts) {
  final out = <({String id, String tag})>[];
  tagCounts.forEach((tag, n) {
    for (var i = 0; i < n; i++) {
      out.add((id: '$tag-$i', tag: tag));
    }
  });
  return out;
}

void main() {
  test('groups contacts by tag and places every one', () {
    final sky = computeConstellationSky(items({'Work': 4, 'Family': 3}));

    expect(sky.positions.length, 7);
    // Same tag → same group index; different tags → different indices.
    expect(sky.groupIndex['Work-0'], sky.groupIndex['Work-3']);
    expect(sky.groupIndex['Family-0'], sky.groupIndex['Family-2']);
    expect(sky.groupIndex['Work-0'], isNot(sky.groupIndex['Family-0']));
    expect(sky.groups.map((g) => g.tag), containsAll(['Work', 'Family']));
  });

  test('untagged contacts form a single "Orphans" constellation', () {
    final sky = computeConstellationSky([
      (id: 'a', tag: ''),
      (id: 'b', tag: ''),
      (id: 'c', tag: 'Work'),
    ]);

    // The two untagged contacts share one group, distinct from Work.
    expect(sky.groupIndex['a'], sky.groupIndex['b']);
    expect(sky.groupIndex['a'], isNot(sky.groupIndex['c']));
    // ...and that group is the named "Orphans" constellation.
    final orphans = sky.groups.firstWhere((g) => g.tag == 'Orphans');
    expect(sky.groupIndex['a'], orphans.index);
  });

  test('is deterministic — same input yields identical positions', () {
    final input = items({'Work': 5, 'Gym': 2, 'School': 9});
    final a = computeConstellationSky(input);
    final b = computeConstellationSky(input);

    expect(a.positions.length, b.positions.length);
    for (final id in a.positions.keys) {
      expect(a.positions[id], b.positions[id]);
    }
  });

  test('a group larger than its template still places everyone', () {
    // 30 members in one tag — far more than any template has stars.
    final sky = computeConstellationSky(items({'Big': 30}));
    expect(sky.positions.length, 30);
    expect(
      sky.positions.keys.every((id) => sky.groupIndex[id] == 0),
      isTrue,
    );
  });

  test('every member of a large group is linked (no lone satellites)', () {
    final sky = computeConstellationSky(items({'Big': 30}));
    final linked = <String>{};
    for (final l in sky.lines) {
      linked..add(l.a)..add(l.b);
    }
    // All 30 members appear in at least one line.
    expect(linked.length, 30);
  });

  test('a 1500-node cluster spreads evenly, caps lines, and stays in its cell',
      () {
    final sky = computeConstellationSky(items({'Big': 1500, 'Small': 4}));
    expect(sky.positions.length, 1504);

    // Even spread: every Big node has a distinct position (no pile-up).
    final bigPositions = sky.positions.entries
        .where((e) => e.key.startsWith('Big'))
        .map((e) => e.value)
        .toSet();
    expect(bigPositions.length, 1500);

    // No hairball: lines among Big are capped (figure edges + a few satellites),
    // not ~1500.
    final bigLines = sky.lines.where((l) => l.a.startsWith('Big')).length;
    expect(bigLines, lessThan(60));

    // No overlap with the neighbouring constellation: every Big node is closer
    // to Big's center than to Small's, so the clusters don't bleed together.
    final bigCenter = sky.groups.firstWhere((g) => g.tag == 'Big').center;
    final smallCenter = sky.groups.firstWhere((g) => g.tag == 'Small').center;
    for (final e in sky.positions.entries.where((e) => e.key.startsWith('Big'))) {
      expect((e.value - bigCenter).distance,
          lessThan((e.value - smallCenter).distance));
    }
  });

  test('figure lines connect real, same-group contacts', () {
    final sky = computeConstellationSky(items({'Work': 8, 'Family': 6}));
    expect(sky.lines, isNotEmpty);
    for (final l in sky.lines) {
      expect(sky.positions.containsKey(l.a), isTrue);
      expect(sky.positions.containsKey(l.b), isTrue);
      expect(sky.groupIndex[l.a], sky.groupIndex[l.b]);
    }
  });

  group('sharedRelationLabel', () {
    test('joins the tags two contacts have in common', () {
      expect(
        sharedRelationLabel(['Work', 'Gym', 'Family'], ['Gym', 'Work']),
        'Work · Gym',
      );
    });

    test('is case-insensitive but keeps the first list\'s casing', () {
      expect(sharedRelationLabel(['Work'], ['work']), 'Work');
    });

    test('returns empty when there is no overlap or a side is empty', () {
      expect(sharedRelationLabel(['Work'], ['Family']), '');
      expect(sharedRelationLabel([], ['Work']), '');
      expect(sharedRelationLabel(['Work'], []), '');
    });

    test('de-duplicates repeated shared tags', () {
      expect(sharedRelationLabel(['Work', 'Work'], ['Work']), 'Work');
    });
  });

  test('empty input yields an empty sky', () {
    final sky = computeConstellationSky(const []);
    expect(sky.positions, isEmpty);
    expect(sky.lines, isEmpty);
    expect(sky.groups, isEmpty);
  });
}
