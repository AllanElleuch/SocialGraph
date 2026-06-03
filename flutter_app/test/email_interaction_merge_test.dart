import 'package:flutter_test/flutter_test.dart';
import 'package:social_graph/models/contact.dart';
import 'package:social_graph/services/email_interaction_merge.dart';

final _date = DateTime(2026, 6, 1, 9, 0);

EmailRecord _msg({
  required String id,
  required String from,
  List<String> to = const [],
  String subject = 'Hi',
  DateTime? date,
}) => EmailRecord(
  messageId: id,
  fromEmail: from,
  toEmails: to,
  subject: subject,
  date: date ?? _date,
);

void main() {
  final self = {'me@x.com'};

  group('emailInteractionsFrom', () {
    test('inbound email logs an interaction with the sender', () {
      final out = emailInteractionsFrom([
        _msg(id: 'm1', from: 'ada@x.com', to: ['me@x.com'], subject: 'Lunch?'),
      ], selfEmails: self);
      expect(out, hasLength(1));
      expect(out.first.matchEmail, 'ada@x.com');
      expect(out.first.type, InteractionType.email);
      expect(out.first.id, 'gmail-m1-ada@x.com');
      expect(out.first.note, contains('Lunch?'));
      expect(out.first.date, _date);
    });

    test('outbound email logs one interaction per non-self recipient', () {
      final out = emailInteractionsFrom([
        _msg(
          id: 'm2',
          from: 'me@x.com',
          to: ['ada@x.com', 'bob@x.com', 'me@x.com'],
        ),
      ], selfEmails: self);
      expect(out.map((d) => d.matchEmail).toSet(), {'ada@x.com', 'bob@x.com'});
    });

    test('self-to-self and unknown-party messages produce nothing', () {
      final out = emailInteractionsFrom([
        _msg(id: 'm3', from: 'me@x.com', to: ['me@x.com']),
      ], selfEmails: self);
      expect(out, isEmpty);
    });

    test('invalid addresses are skipped', () {
      final out = emailInteractionsFrom([
        _msg(id: 'm4', from: 'not-an-email', to: ['me@x.com']),
      ], selfEmails: self);
      expect(out, isEmpty);
    });

    test('end-to-end merge is idempotent via deterministic ids', () {
      final contacts = [
        Contact(
          id: 'a',
          firstName: 'Ada',
          lastName: '',
          tags: const [],
          locationMet: '',
          connections: const [],
          email: 'ada@x.com',
        ),
      ];
      final records = emailInteractionsFrom([
        _msg(id: 'm1', from: 'ada@x.com', to: ['me@x.com']),
      ], selfEmails: self);
      final once = applyDetectedInteractions(contacts, records);
      final twice = applyDetectedInteractions(once, records);
      expect(twice.first.interactions, hasLength(1));
    });
  });
}
