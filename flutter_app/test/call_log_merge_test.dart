import 'package:flutter_test/flutter_test.dart';
import 'package:social_graph/models/contact.dart';
import 'package:social_graph/services/call_log_merge.dart';

Contact makeContact({
  required String id,
  String phone = '',
  List<InteractionEvent> interactions = const [],
}) {
  return Contact(
    id: id,
    firstName: id,
    lastName: '',
    phone: phone,
    tags: const [],
    locationMet: '',
    connections: const [],
    interactions: interactions,
  );
}

CallRecord rec({
  required String number,
  required DateTime at,
  CallDirection direction = CallDirection.incoming,
  int duration = 60,
}) =>
    CallRecord(
      number: number,
      timestamp: at,
      direction: direction,
      durationSeconds: duration,
    );

void main() {
  final t0 = DateTime(2026, 6, 2, 10, 0, 0);

  group('normalizePhone', () {
    test('strips formatting and matches on the last 9 digits', () {
      expect(normalizePhone('+1 (415) 555-0100'),
          normalizePhone('415-555-0100'));
      expect(normalizePhone(''), isNull);
      expect(normalizePhone('   '), isNull);
    });
  });

  group('callNoteLabel', () {
    test('describes direction and duration', () {
      expect(
        callNoteLabel(rec(number: '1', at: t0, direction: CallDirection.outgoing, duration: 192)),
        'Outgoing call · 3m 12s',
      );
      expect(
        callNoteLabel(rec(number: '1', at: t0, direction: CallDirection.incoming, duration: 45)),
        'Incoming call · 45s',
      );
      expect(
        callNoteLabel(rec(number: '1', at: t0, direction: CallDirection.missed, duration: 0)),
        'Missed call',
      );
    });
  });

  group('applyCallRecords', () {
    test('adds a call interaction to the matching contact', () {
      final contacts = [makeContact(id: 'a', phone: '+1 415-555-0100')];
      final out = applyCallRecords(contacts, [
        rec(number: '4155550100', at: t0, direction: CallDirection.incoming),
      ]);

      expect(out.single.interactions, hasLength(1));
      final e = out.single.interactions.single;
      expect(e.type, InteractionType.call);
      expect(e.date, t0);
      expect(e.note, 'Incoming call · 1m');
    });

    test('is idempotent — re-running adds nothing', () {
      final contacts = [makeContact(id: 'a', phone: '4155550100')];
      final records = [rec(number: '4155550100', at: t0)];

      final once = applyCallRecords(contacts, records);
      final twice = applyCallRecords(once, records);

      expect(once.single.interactions, hasLength(1));
      expect(twice.single.interactions, hasLength(1));
    });

    test('skips missed and zero-duration (unanswered) calls', () {
      final contacts = [makeContact(id: 'a', phone: '4155550100')];
      final out = applyCallRecords(contacts, [
        rec(number: '4155550100', at: t0, direction: CallDirection.missed, duration: 0),
        rec(number: '4155550100', at: t0.add(const Duration(minutes: 1)), direction: CallDirection.outgoing, duration: 0),
      ]);

      expect(out.single.interactions, isEmpty);
    });

    test('ignores calls from unknown numbers', () {
      final contacts = [makeContact(id: 'a', phone: '4155550100')];
      final out = applyCallRecords(contacts, [
        rec(number: '9998887777', at: t0),
      ]);

      expect(out.single.interactions, isEmpty);
    });

    test('does not duplicate a call already logged with the same id', () {
      final id = callInteractionId(rec(number: '4155550100', at: t0));
      final contacts = [
        makeContact(
          id: 'a',
          phone: '4155550100',
          interactions: [
            InteractionEvent(id: id, date: t0, type: InteractionType.call),
          ],
        ),
      ];

      final out = applyCallRecords(contacts, [rec(number: '4155550100', at: t0)]);
      expect(out.single.interactions, hasLength(1));
    });

    test('advances lastInteraction to the call time', () {
      final contacts = [makeContact(id: 'a', phone: '4155550100')];
      final out = applyCallRecords(contacts, [rec(number: '4155550100', at: t0)]);
      expect(out.single.lastInteraction, t0);
    });

    test('returns the same list instance when there are no records', () {
      final contacts = [makeContact(id: 'a', phone: '4155550100')];
      expect(identical(applyCallRecords(contacts, const []), contacts), isTrue);
    });
  });
}
