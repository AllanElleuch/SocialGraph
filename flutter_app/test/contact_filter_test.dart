import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:social_graph/models/contact.dart';
import 'package:social_graph/services/contact_filter.dart';

final _now = DateTime(2026, 6, 3);

Contact c({
  required String id,
  String first = 'A',
  String last = '',
  List<String> tags = const [],
  bool photo = false,
  DateTime? lastInteraction,
  int? cadenceDays,
}) {
  return Contact(
    id: id,
    firstName: first,
    lastName: last,
    tags: tags,
    locationMet: '',
    connections: const [],
    lastInteraction: lastInteraction,
    reminderCadenceDays: cadenceDays,
    photoThumbnail: photo ? Uint8List.fromList(const [1, 2, 3]) : null,
  );
}

List<Contact> apply(List<Contact> list, ContactFilter f) =>
    applyContactFilter(list, f, now: _now);

void main() {
  test('inactive filter returns the same list instance', () {
    final list = [c(id: 'a')];
    expect(identical(apply(list, ContactFilter.none), list), isTrue);
    expect(ContactFilter.none.isActive, isFalse);
  });

  group('tags', () {
    final list = [
      c(id: 'a', tags: ['Work']),
      c(id: 'b', tags: ['Family']),
      c(id: 'c', tags: ['Work', 'Gym']),
      c(id: 'd'),
    ];

    test('matches ANY selected tag, case-insensitive', () {
      final out = apply(list, const ContactFilter(tags: {'work'}));
      expect(out.map((e) => e.id), ['a', 'c']);
    });

    test('multiple tags union', () {
      final out = apply(list, const ContactFilter(tags: {'Family', 'Gym'}));
      expect(out.map((e) => e.id).toSet(), {'b', 'c'});
    });
  });

  test('untaggedOnly keeps only contacts with no tags', () {
    final list = [
      c(id: 'a', tags: ['Work']),
      c(id: 'b'),
      c(id: 'c', tags: ['  ']), // whitespace-only = effectively untagged
    ];
    final out = apply(list, const ContactFilter(untaggedOnly: true));
    expect(out.map((e) => e.id).toSet(), {'b', 'c'});
  });

  test('withPhotoOnly keeps only contacts with a photo', () {
    final list = [c(id: 'a', photo: true), c(id: 'b')];
    expect(apply(list, const ContactFilter(withPhotoOnly: true)).map((e) => e.id),
        ['a']);
  });

  group('family', () {
    final list = [
      c(id: 'a', last: 'Smith'),
      c(id: 'b', last: 'smith'), // same surname, different case
      c(id: 'c', last: 'Jones'),
      c(id: 'd', last: ''),
    ];

    test('familyContactIds groups shared last names (case-insensitive)', () {
      expect(familyContactIds(list), {'a', 'b'});
    });

    test('familyOnly keeps only contacts with a relative', () {
      final out = apply(list, const ContactFilter(familyOnly: true));
      expect(out.map((e) => e.id).toSet(), {'a', 'b'});
    });
  });

  test('needsAttentionOnly keeps overdue contacts', () {
    final list = [
      // Overdue: cadence 7 days, last contact 30 days ago.
      c(id: 'overdue', cadenceDays: 7, lastInteraction: _now.subtract(const Duration(days: 30))),
      // Fresh: contacted today.
      c(id: 'fresh', cadenceDays: 7, lastInteraction: _now),
    ];
    final out = apply(list, const ContactFilter(needsAttentionOnly: true));
    expect(out.map((e) => e.id), ['overdue']);
  });

  test('criteria are ANDed together', () {
    final list = [
      c(id: 'a', tags: ['Work'], photo: true),
      c(id: 'b', tags: ['Work']), // no photo
      c(id: 'c', photo: true), // no Work tag
    ];
    final out = apply(
      list,
      const ContactFilter(tags: {'Work'}, withPhotoOnly: true),
    );
    expect(out.map((e) => e.id), ['a']);
  });

  group('ContactFilter helpers', () {
    test('activeCount counts each tag and each flag', () {
      const f = ContactFilter(tags: {'Work', 'Gym'}, familyOnly: true);
      expect(f.activeCount, 3);
      expect(f.isActive, isTrue);
    });

    test('toggleTag adds/removes and clears untaggedOnly when selecting', () {
      const start = ContactFilter(untaggedOnly: true);
      final added = start.toggleTag('Work');
      expect(added.tags, {'Work'});
      expect(added.untaggedOnly, isFalse);
      final removed = added.toggleTag('Work');
      expect(removed.tags, isEmpty);
    });
  });
}
