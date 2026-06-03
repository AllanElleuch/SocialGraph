import 'package:flutter_test/flutter_test.dart';
import 'package:social_graph/services/google_parsers.dart';

void main() {
  group('extractEmailAddress', () {
    test('parses "Name <email>" and bare addresses', () {
      expect(extractEmailAddress('Ada Lovelace <ada@x.com>'), 'ada@x.com');
      expect(extractEmailAddress('bob@x.com'), 'bob@x.com');
      expect(extractEmailAddress('  CARA@X.com '), 'cara@x.com');
      expect(extractEmailAddress('no address'), isNull);
    });
  });

  group('parseGmailMessage', () {
    test('maps headers + internalDate into an EmailRecord', () {
      final json = {
        'id': 'm1',
        'internalDate': '${DateTime(2026, 6, 1, 9).millisecondsSinceEpoch}',
        'payload': {
          'headers': [
            {'name': 'From', 'value': 'Ada <ada@x.com>'},
            {'name': 'To', 'value': 'me@x.com, Bob <bob@x.com>'},
            {'name': 'Subject', 'value': 'Lunch?'},
          ],
        },
      };
      final rec = parseGmailMessage(json);
      expect(rec, isNotNull);
      expect(rec!.messageId, 'm1');
      expect(rec.fromEmail, 'ada@x.com');
      expect(rec.toEmails, ['me@x.com', 'bob@x.com']);
      expect(rec.subject, 'Lunch?');
      expect(rec.date, DateTime(2026, 6, 1, 9));
    });

    test('returns null without an id or From header', () {
      expect(
        parseGmailMessage({
          'id': 'm',
          'payload': {'headers': []},
        }),
        isNull,
      );
    });
  });

  group('parseGoogleCalendarEvents', () {
    test('maps timed events with attendees', () {
      final json = {
        'items': [
          {
            'id': 'e1',
            'summary': 'Coffee',
            'start': {'dateTime': '2026-06-01T09:00:00Z'},
            'end': {'dateTime': '2026-06-01T10:00:00Z'},
            'attendees': [
              {'email': 'ada@x.com'},
              {'email': 'me@x.com', 'self': true},
            ],
          },
        ],
      };
      final out = parseGoogleCalendarEvents(json);
      expect(out, hasLength(1));
      expect(out.first.eventId, 'e1');
      expect(out.first.title, 'Coffee');
      expect(out.first.isAllDay, isFalse);
      expect(out.first.attendeeEmails, containsAll(['ada@x.com', 'me@x.com']));
    });

    test('flags all-day events (date without dateTime)', () {
      final json = {
        'items': [
          {
            'id': 'h1',
            'summary': 'Holiday',
            'start': {'date': '2026-06-01'},
            'end': {'date': '2026-06-02'},
          },
        ],
      };
      final out = parseGoogleCalendarEvents(json);
      expect(out.single.isAllDay, isTrue);
    });
  });
}
