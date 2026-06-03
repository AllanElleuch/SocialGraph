import 'package:flutter_test/flutter_test.dart';
import 'package:social_graph/models/contact.dart';
import 'package:social_graph/services/tag_usage.dart';

Contact c(String id, List<String> tags) => Contact(
      id: id,
      firstName: id,
      lastName: '',
      tags: tags,
      locationMet: '',
      connections: const [],
    );

void main() {
  group('tagUsageCounts', () {
    test('counts how many contacts use each tag', () {
      final counts = tagUsageCounts([
        c('a', ['accro yoga', 'tech']),
        c('b', ['accro yoga']),
        c('c', ['accro yoga', 'design']),
      ]);
      expect(counts['accro yoga'], 3);
      expect(counts['tech'], 1);
      expect(counts['design'], 1);
    });

    test('counts a tag once per contact even if duplicated on that contact', () {
      final counts = tagUsageCounts([
        c('a', ['vip', 'vip']),
      ]);
      expect(counts['vip'], 1);
    });

    test('trims tags and ignores blanks', () {
      final counts = tagUsageCounts([
        c('a', ['  yoga ', '', '   ']),
        c('b', ['yoga']),
      ]);
      expect(counts['yoga'], 2);
      expect(counts.containsKey(''), isFalse);
    });

    test('returns an empty map for no contacts', () {
      expect(tagUsageCounts(const []), isEmpty);
    });
  });
}
