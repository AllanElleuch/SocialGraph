import 'package:flutter_test/flutter_test.dart';
import 'package:social_graph/models/contact.dart';
import 'package:social_graph/services/tag_membership.dart';

Contact c(String id, List<String> tags) => Contact(
      id: id,
      firstName: id,
      lastName: '',
      tags: tags,
      locationMet: '',
      connections: const [],
    );

void main() {
  group('applyTagMembership', () {
    final now = DateTime(2026, 6, 3);

    test('adds the tag to new members and removes it from dropped ones', () {
      final all = [
        c('1', ['yoga']), // stays a member
        c('2', ['tech']), // becomes a member
        c('3', ['yoga']), // dropped from the tag
      ];

      final out = applyTagMembership(all, 'yoga', {'1', '2'}, now: now);

      expect(out.firstWhere((c) => c.id == '1').tags, ['yoga']);
      expect(out.firstWhere((c) => c.id == '2').tags, ['tech', 'yoga']);
      expect(out.firstWhere((c) => c.id == '3').tags, isEmpty);
    });

    test('leaves other tags untouched and bumps updatedAt only on change', () {
      final all = [
        c('1', ['tech', 'design']),
        c('2', ['yoga']),
      ];
      final out = applyTagMembership(all, 'yoga', {'1'}, now: now);

      final one = out.firstWhere((c) => c.id == '1');
      expect(one.tags, ['tech', 'design', 'yoga']);
      expect(one.updatedAt, now);
      // #2 lost membership -> changed; #1 gained -> changed.
      expect(out.firstWhere((c) => c.id == '2').tags, isEmpty);
    });

    test('unchanged contacts keep their identity', () {
      final all = [
        c('1', ['yoga']),
        c('2', ['tech']),
      ];
      // #1 stays member, #2 stays non-member -> nothing changes.
      final out = applyTagMembership(all, 'yoga', {'1'}, now: now);
      expect(identical(out[0], all[0]), isTrue);
      expect(identical(out[1], all[1]), isTrue);
    });

    test('blank tag is a no-op', () {
      final all = [c('1', ['yoga'])];
      final out = applyTagMembership(all, '   ', {'1'}, now: now);
      expect(identical(out, all), isTrue);
    });

    test('hasTag compares trimmed', () {
      expect(hasTag(c('1', ['  yoga ']), 'yoga'), isTrue);
      expect(hasTag(c('1', ['tech']), 'yoga'), isFalse);
    });
  });
}
