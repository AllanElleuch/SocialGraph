import 'package:flutter_test/flutter_test.dart';
import 'package:social_graph/models/contact.dart';
import 'package:social_graph/services/interaction_match.dart';

Contact _c({
  required String id,
  String phone = '',
  String email = '',
  List<InteractionEvent> interactions = const [],
}) => Contact(
  id: id,
  firstName: id,
  lastName: '',
  tags: const [],
  locationMet: '',
  connections: const [],
  phone: phone,
  email: email,
  interactions: interactions,
);

DetectedInteraction _d({
  required String id,
  String? email,
  String? phone,
  String? contactId,
  InteractionType type = InteractionType.meeting,
  DateTime? date,
  String note = '',
}) => DetectedInteraction(
  id: id,
  date: date ?? DateTime(2026, 6, 1),
  type: type,
  note: note,
  matchEmail: email,
  matchPhone: phone,
  matchContactId: contactId,
);

void main() {
  group('normalizeEmail', () {
    test('lowercases and trims', () {
      expect(normalizeEmail('  Ada@Example.COM '), 'ada@example.com');
    });
    test('returns null for blank or invalid', () {
      expect(normalizeEmail(''), isNull);
      expect(normalizeEmail('   '), isNull);
      expect(normalizeEmail('not-an-email'), isNull);
    });
  });

  group('applyDetectedInteractions', () {
    test('matches by email and logs the interaction', () {
      final contacts = [_c(id: 'a', email: 'Ada@Example.com')];
      final out = applyDetectedInteractions(contacts, [
        _d(id: 'x1', email: 'ada@example.com'),
      ]);
      expect(out.first.interactions, hasLength(1));
      expect(out.first.interactions.first.id, 'x1');
      expect(out.first.interactions.first.type, InteractionType.meeting);
    });

    test('matches by phone using last-9-digit normalization', () {
      final contacts = [_c(id: 'a', phone: '+1 (415) 555-0100')];
      final out = applyDetectedInteractions(contacts, [
        _d(id: 'x1', phone: '415-555-0100', type: InteractionType.call),
      ]);
      expect(out.first.interactions, hasLength(1));
    });

    test('matches by explicit contactId over email/phone', () {
      final contacts = [
        _c(id: 'a', email: 'a@x.com'),
        _c(id: 'b', email: 'b@x.com'),
      ];
      final out = applyDetectedInteractions(contacts, [
        _d(id: 'x1', contactId: 'b', email: 'a@x.com'),
      ]);
      expect(out[0].interactions, isEmpty);
      expect(out[1].interactions, hasLength(1));
    });

    test('is idempotent — re-applying the same id does not duplicate', () {
      final contacts = [_c(id: 'a', email: 'a@x.com')];
      final once = applyDetectedInteractions(contacts, [
        _d(id: 'x1', email: 'a@x.com'),
      ]);
      final twice = applyDetectedInteractions(once, [
        _d(id: 'x1', email: 'a@x.com'),
      ]);
      expect(twice.first.interactions, hasLength(1));
    });

    test('drops records that match no contact', () {
      final contacts = [_c(id: 'a', email: 'a@x.com')];
      final out = applyDetectedInteractions(contacts, [
        _d(id: 'x1', email: 'nobody@x.com'),
      ]);
      expect(out.first.interactions, isEmpty);
      expect(identical(out, contacts), isTrue); // unchanged input returned
    });

    test('does not mutate the input list or contacts', () {
      final contacts = [_c(id: 'a', email: 'a@x.com')];
      applyDetectedInteractions(contacts, [_d(id: 'x1', email: 'a@x.com')]);
      expect(contacts.first.interactions, isEmpty);
    });
  });
}
