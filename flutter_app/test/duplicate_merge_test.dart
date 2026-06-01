import 'package:flutter_test/flutter_test.dart';
import 'package:social_graph/models/contact.dart';
import 'package:social_graph/services/duplicate_detector.dart';
import 'package:social_graph/services/contact_merge.dart';

Contact makeContact({
  required String id,
  String firstName = '',
  String lastName = '',
  String workplace = '',
  String homeAddress = '',
  String phone = '',
  String email = '',
  String notes = '',
  List<String> tags = const [],
  String locationMet = '',
  double? lat,
  double? lng,
  DateTime? dateMet,
  List<String> connections = const [],
  DateTime? lastInteraction,
  List<InteractionEvent> interactions = const [],
  DateTime? updatedAt,
}) {
  return Contact(
    id: id,
    firstName: firstName,
    lastName: lastName,
    workplace: workplace,
    homeAddress: homeAddress,
    phone: phone,
    email: email,
    notes: notes,
    tags: tags,
    locationMet: locationMet,
    lat: lat,
    lng: lng,
    dateMet: dateMet ?? DateTime(2020, 1, 1),
    connections: connections,
    lastInteraction: lastInteraction,
    interactions: interactions,
    updatedAt: updatedAt,
  );
}

void main() {
  group('findDuplicateGroups', () {
    test('"Bob Smith" vs "bob smith" are grouped (case-insensitive name)', () {
      final a = makeContact(id: 'a', firstName: 'Bob', lastName: 'Smith');
      final b = makeContact(id: 'b', firstName: 'bob', lastName: 'smith');

      final groups = findDuplicateGroups([a, b]);

      expect(groups, hasLength(1));
      expect(groups.first.map((c) => c.id).toSet(), {'a', 'b'});
    });

    test('same email with different names are grouped (strong signal)', () {
      final a = makeContact(
        id: 'a',
        firstName: 'Robert',
        lastName: 'Jones',
        email: 'Same@Example.com',
      );
      final b = makeContact(
        id: 'b',
        firstName: 'Bobby',
        lastName: 'Williams',
        email: 'same@example.com',
      );

      final groups = findDuplicateGroups([a, b]);

      expect(groups, hasLength(1));
      expect(groups.first.map((c) => c.id).toSet(), {'a', 'b'});
    });

    test('same phone (different formatting) are grouped', () {
      final a = makeContact(
        id: 'a',
        firstName: 'Alice',
        lastName: 'Adams',
        phone: '(555) 123-4567',
      );
      final b = makeContact(
        id: 'b',
        firstName: 'Alicia',
        lastName: 'Brown',
        phone: '555.123.4567',
      );

      final groups = findDuplicateGroups([a, b]);

      expect(groups, hasLength(1));
      expect(groups.first.map((c) => c.id).toSet(), {'a', 'b'});
    });

    test('same workplace + firstName are grouped', () {
      final a = makeContact(
        id: 'a',
        firstName: 'Sam',
        lastName: 'Carter',
        workplace: 'Acme Corp',
      );
      final b = makeContact(
        id: 'b',
        firstName: 'sam',
        lastName: 'Delgado',
        workplace: 'acme corp',
      );

      final groups = findDuplicateGroups([a, b]);

      expect(groups, hasLength(1));
      expect(groups.first.map((c) => c.id).toSet(), {'a', 'b'});
    });

    test('unrelated contacts are not grouped', () {
      final a = makeContact(
        id: 'a',
        firstName: 'Bob',
        lastName: 'Smith',
        email: 'bob@example.com',
        phone: '111',
      );
      final b = makeContact(
        id: 'b',
        firstName: 'Carla',
        lastName: 'Vasquez',
        email: 'carla@other.com',
        phone: '222',
      );

      final groups = findDuplicateGroups([a, b]);

      expect(groups, isEmpty);
    });

    test('singletons are omitted, groups are deterministic by first id', () {
      final dupA = makeContact(id: 'zzz', firstName: 'Bob', lastName: 'Smith');
      final dupB = makeContact(id: 'aaa', firstName: 'Bob', lastName: 'Smith');
      final solo = makeContact(id: 'mmm', firstName: 'Nina', lastName: 'Park');

      final groups = findDuplicateGroups([dupA, dupB, solo]);

      expect(groups, hasLength(1));
      // First contact in group keeps input order: dupA ('zzz') came first.
      expect(groups.first.first.id, 'zzz');
      expect(groups.first.map((c) => c.id).toSet(), {'zzz', 'aaa'});
    });
  });

  group('mergeContacts', () {
    test('merged tags are a deduped union', () {
      final primary = makeContact(
        id: 'p',
        firstName: 'Bob',
        lastName: 'Smith',
        tags: ['friend', 'gym'],
      );
      final other = makeContact(
        id: 'o',
        firstName: 'Bob',
        lastName: 'Smith',
        tags: ['gym', 'work', 'friend'],
      );

      final merged = mergeContacts(primary, [other]);

      expect(merged.tags, ['friend', 'gym', 'work']);
    });

    test('earliest dateMet wins', () {
      final primary = makeContact(
        id: 'p',
        firstName: 'Bob',
        dateMet: DateTime(2022, 5, 1),
      );
      final other = makeContact(
        id: 'o',
        firstName: 'Bob',
        dateMet: DateTime(2019, 3, 15),
      );

      final merged = mergeContacts(primary, [other]);

      expect(merged.dateMet, DateTime(2019, 3, 15));
    });

    test('primary id is preserved', () {
      final primary = makeContact(id: 'primary-id', firstName: 'Bob');
      final other = makeContact(id: 'other-id', firstName: 'Bob');

      final merged = mergeContacts(primary, [other]);

      expect(merged.id, 'primary-id');
    });

    test('prefers primary non-empty scalar, else first non-empty other', () {
      final primary = makeContact(
        id: 'p',
        firstName: 'Bob',
        phone: '',
        workplace: 'Primary Co',
      );
      final other1 = makeContact(id: 'o1', firstName: 'Bob', phone: '');
      final other2 = makeContact(
        id: 'o2',
        firstName: 'Bob',
        phone: '5551234',
        workplace: 'Other Co',
      );

      final merged = mergeContacts(primary, [other1, other2]);

      expect(merged.phone, '5551234'); // filled from other2
      expect(merged.workplace, 'Primary Co'); // primary wins
    });

    test('interactions concatenated newest-first by date', () {
      final primary = makeContact(
        id: 'p',
        firstName: 'Bob',
        interactions: [
          InteractionEvent(
            id: 'i1',
            date: DateTime(2021, 1, 1),
            type: InteractionType.note,
          ),
        ],
      );
      final other = makeContact(
        id: 'o',
        firstName: 'Bob',
        interactions: [
          InteractionEvent(
            id: 'i2',
            date: DateTime(2023, 6, 1),
            type: InteractionType.call,
          ),
        ],
      );

      final merged = mergeContacts(primary, [other]);

      expect(merged.interactions.map((e) => e.id).toList(), ['i2', 'i1']);
    });

    test('connections union excludes merged ids and self', () {
      final primary = makeContact(
        id: 'p',
        firstName: 'Bob',
        connections: ['x', 'o'],
      );
      final other = makeContact(
        id: 'o',
        firstName: 'Bob',
        connections: ['y', 'p'],
      );

      final merged = mergeContacts(primary, [other]);

      // 'o' (merged-away) and 'p' (self) removed; union deduped.
      expect(merged.connections, ['x', 'y']);
    });

    test('updatedAt is the latest among inputs', () {
      final primary = makeContact(
        id: 'p',
        firstName: 'Bob',
        updatedAt: DateTime(2024, 1, 1),
      );
      final other = makeContact(
        id: 'o',
        firstName: 'Bob',
        updatedAt: DateTime(2025, 1, 1),
      );

      final merged = mergeContacts(primary, [other]);

      expect(merged.updatedAt, DateTime(2025, 1, 1));
    });
  });

  group('rewriteConnections', () {
    test('no dangling or duplicate connection ids after rewrite', () {
      // Surviving 'p'; 'o1' and 'o2' merged away.
      final survivor = makeContact(
        id: 'p',
        firstName: 'Bob',
        connections: const [],
      );
      // c1 referenced both merged ids -> should collapse to single 'p'.
      final c1 = makeContact(
        id: 'c1',
        firstName: 'C',
        connections: ['o1', 'o2', 'z'],
      );
      // c2 references a merged id equal to itself situation not applicable;
      // it points to 'o1' and already has 'p' -> dedupe to single 'p'.
      final c2 = makeContact(
        id: 'c2',
        firstName: 'D',
        connections: ['p', 'o1'],
      );
      // The survivor referencing a merged-away id would become self -> dropped.
      final survivorWithSelf = makeContact(
        id: 'p',
        firstName: 'Bob',
        connections: ['o1', 'w'],
      );

      final rewritten = rewriteConnections(
        [survivorWithSelf, c1, c2],
        'p',
        {'o1', 'o2'},
      );

      final byId = {for (final c in rewritten) c.id: c};

      // Survivor: 'o1' -> 'p' == self, dropped; keeps 'w'.
      expect(byId['p']!.connections, ['w']);
      // c1: o1,o2 -> p,p deduped to single 'p'; plus 'z'.
      expect(byId['c1']!.connections, ['p', 'z']);
      // c2: p, o1->p deduped to single 'p'.
      expect(byId['c2']!.connections, ['p']);

      // No connection references a merged-away id anywhere.
      for (final c in rewritten) {
        expect(c.connections.contains('o1'), isFalse);
        expect(c.connections.contains('o2'), isFalse);
        // No self references.
        expect(c.connections.contains(c.id), isFalse);
        // No duplicates.
        expect(c.connections.toSet().length, c.connections.length);
      }

      // Unused survivor object referenced to avoid analyzer warnings.
      expect(survivor.id, 'p');
    });

    test('returns same list reference semantics when no merged ids', () {
      final list = [makeContact(id: 'a', connections: ['b'])];
      final result = rewriteConnections(list, 'x', {});
      expect(identical(result, list), isTrue);
    });
  });
}
