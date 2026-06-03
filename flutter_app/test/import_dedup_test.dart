import 'package:flutter_test/flutter_test.dart';
import 'package:social_graph/models/contact.dart';
import 'package:social_graph/services/import_dedup.dart';

Contact c({
  required String id,
  String first = 'A',
  String last = 'B',
  String phone = '',
  String email = '',
  String? deviceId,
}) {
  return Contact(
    id: id,
    firstName: first,
    lastName: last,
    phone: phone,
    email: email,
    tags: const [],
    locationMet: '',
    connections: const [],
    origin: deviceId == null
        ? null
        : ContactOrigin.imported(platform: 'iOS', deviceId: deviceId),
  );
}

void main() {
  group('dedupeImportedContacts', () {
    test('adds everything when nothing exists and no internal dupes', () {
      final incoming = [
        c(id: '1', first: 'Ada', phone: '111'),
        c(id: '2', first: 'Bob', phone: '222'),
      ];
      final added = dedupeImportedContacts(const [], incoming);
      expect(added.map((x) => x.firstName), ['Ada', 'Bob']);
    });

    test('collapses one person split across several numbered entries', () {
      // Same name, different numbers — the "multiple numbers" duplicate case.
      final incoming = [
        c(id: '1', first: 'Ada', last: 'Lovelace', phone: '111'),
        c(id: '2', first: 'Ada', last: 'Lovelace', phone: '222'),
        c(id: '3', first: 'Ada', last: 'Lovelace', phone: '333'),
      ];
      final added = dedupeImportedContacts(const [], incoming);
      expect(added, hasLength(1));
      expect(added.single.phone, '111'); // first occurrence wins
    });

    test('re-import is idempotent via the device id', () {
      final existing = [c(id: 'import-d1', first: 'Ada', deviceId: 'd1')];
      // Same device entry, even if the name/number changed slightly.
      final incoming = [c(id: 'import-d1', first: 'Adita', deviceId: 'd1')];
      expect(dedupeImportedContacts(existing, incoming), isEmpty);
    });

    test('skips an incoming contact that shares a phone with an existing one',
        () {
      final existing = [c(id: '1', first: 'Ada', phone: '(555) 111-2222')];
      // Different formatting, same digits.
      final incoming = [c(id: '2', first: 'Adita', phone: '555-111-2222')];
      expect(dedupeImportedContacts(existing, incoming), isEmpty);
    });

    test('skips an incoming contact that shares an email (case-insensitive)',
        () {
      final existing = [c(id: '1', first: 'Ada', email: 'ada@x.io')];
      final incoming = [c(id: '2', first: 'Other', email: 'ADA@X.io')];
      expect(dedupeImportedContacts(existing, incoming), isEmpty);
    });

    test('keeps genuinely distinct people', () {
      final existing = [c(id: '1', first: 'Ada', phone: '111')];
      final incoming = [
        c(id: '2', first: 'Grace', phone: '222', email: 'grace@x.io'),
      ];
      expect(dedupeImportedContacts(existing, incoming), hasLength(1));
    });
  });
}
