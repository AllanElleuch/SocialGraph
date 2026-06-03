import 'package:flutter_test/flutter_test.dart';
import 'package:social_graph/models/contact.dart';
import 'package:social_graph/services/relatives.dart';

Contact c(String id, String first, String last,
        {List<String> connections = const []}) =>
    Contact(
      id: id,
      firstName: first,
      lastName: last,
      tags: const [],
      locationMet: '',
      connections: connections,
    );

void main() {
  group('relativesOf', () {
    final all = [
      c('1', 'Ada', 'Lovelace'),
      c('2', 'Bob', 'lovelace'), // different case
      c('3', 'Cara', 'Lovelace '), // trailing space
      c('4', 'Dan', 'Turing'),
      c('5', 'Eve', ''), // no last name
    ];

    test('finds same-last-name contacts case/space-insensitively', () {
      final rels = relativesOf(all[0], all);
      expect(rels.map((r) => r.id), ['2', '3']); // sorted by display name
    });

    test('excludes the contact itself', () {
      expect(relativesOf(all[0], all).any((r) => r.id == '1'), isFalse);
    });

    test('returns empty for a contact with no last name', () {
      expect(relativesOf(all[4], all), isEmpty);
    });

    test('returns empty when nobody else shares the last name', () {
      expect(relativesOf(all[3], all), isEmpty);
    });
  });

  group('sameLastNameLinks', () {
    test('chains each surname group (N members -> N-1 edges)', () {
      final links = sameLastNameLinks([
        c('1', 'Ada', 'Lovelace'),
        c('2', 'Bob', 'Lovelace'),
        c('3', 'Cara', 'Lovelace'),
        c('4', 'Dan', 'Turing'), // singleton -> no edge
      ]);
      expect(links, hasLength(2)); // 3 Lovelaces -> 2 chain edges
      // Endpoints all come from the Lovelace group.
      final ids = {for (final l in links) ...[l.a, l.b]};
      expect(ids, {'1', '2', '3'});
    });

    test('no edges when every last name is unique', () {
      final links = sameLastNameLinks([
        c('1', 'Ada', 'Lovelace'),
        c('2', 'Dan', 'Turing'),
      ]);
      expect(links, isEmpty);
    });
  });

  group('linkRelativesOf', () {
    test('cross-links the saved contact and its same-last-name peers', () {
      final all = [
        c('1', 'Ada', 'Lovelace'),
        c('2', 'Bob', 'Lovelace'),
        c('3', 'Dan', 'Turing'),
      ];

      final linked = linkRelativesOf(all[0], all, now: DateTime(2026, 6, 3));

      final ada = linked.firstWhere((c) => c.id == '1');
      final bob = linked.firstWhere((c) => c.id == '2');
      final dan = linked.firstWhere((c) => c.id == '3');
      expect(ada.connections, contains('2'));
      expect(bob.connections, contains('1'));
      expect(dan.connections, isEmpty); // untouched (different surname)
      expect(ada.updatedAt, DateTime(2026, 6, 3)); // bumped for sync
    });

    test('is additive — keeps existing connections', () {
      final all = [
        c('1', 'Ada', 'Lovelace', connections: const ['x']),
        c('2', 'Bob', 'Lovelace'),
      ];
      final linked = linkRelativesOf(all[0], all, now: DateTime(2026, 6, 3));
      expect(linked.firstWhere((c) => c.id == '1').connections,
          containsAll(['x', '2']));
    });

    test('no-op for a contact with no last name', () {
      final all = [c('1', 'Ada', ''), c('2', 'Bob', '')];
      final linked = linkRelativesOf(all[0], all, now: DateTime(2026, 6, 3));
      expect(linked.firstWhere((c) => c.id == '1').connections, isEmpty);
    });
  });

  group('linkAllRelatives', () {
    test('cross-links every surname group in one pass', () {
      final all = [
        c('1', 'Ada', 'Lovelace'),
        c('2', 'Bob', 'Lovelace'),
        c('3', 'Cara', 'Turing'),
        c('4', 'Dan', 'Turing'),
        c('5', 'Eve', 'Solo'), // singleton -> unchanged
      ];

      final linked = linkAllRelatives(all, now: DateTime(2026, 6, 3));

      expect(linked.firstWhere((c) => c.id == '1').connections, ['2']);
      expect(linked.firstWhere((c) => c.id == '2').connections, ['1']);
      expect(linked.firstWhere((c) => c.id == '3').connections, ['4']);
      expect(linked.firstWhere((c) => c.id == '4').connections, ['3']);
      // Singleton and identity preserved for unchanged contacts.
      expect(identical(linked[4], all[4]), isTrue);
    });

    test('is idempotent — a second pass changes nothing', () {
      final all = [
        c('1', 'Ada', 'Lovelace'),
        c('2', 'Bob', 'Lovelace'),
      ];
      final once = linkAllRelatives(all, now: DateTime(2026, 6, 3));
      final twice = linkAllRelatives(once, now: DateTime(2026, 6, 4));
      // No new links -> same instances returned.
      expect(identical(twice[0], once[0]), isTrue);
      expect(identical(twice[1], once[1]), isTrue);
    });

    test('preserves order so callers can diff by index', () {
      final all = [
        c('3', 'C', 'Z'),
        c('1', 'A', 'Z'),
        c('2', 'B', 'Y'),
      ];
      final linked = linkAllRelatives(all, now: DateTime(2026, 6, 3));
      expect(linked.map((c) => c.id), ['3', '1', '2']);
    });
  });
}
