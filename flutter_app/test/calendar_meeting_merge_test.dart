import 'package:flutter_test/flutter_test.dart';
import 'package:social_graph/models/contact.dart';
import 'package:social_graph/services/calendar_meeting_merge.dart';

final _now = DateTime(2026, 6, 3, 12, 0);

CalendarEventRecord _ev({
  required String id,
  String title = 'Sync',
  DateTime? start,
  DateTime? end,
  List<String> attendees = const [],
  bool allDay = false,
}) => CalendarEventRecord(
  eventId: id,
  title: title,
  start: start ?? _now.subtract(const Duration(hours: 2)),
  end: end ?? _now.subtract(const Duration(hours: 1)),
  attendeeEmails: attendees,
  isAllDay: allDay,
);

void main() {
  group('meetingsFromEvents', () {
    test('emits a meeting per attendee for a past event', () {
      final out = meetingsFromEvents([
        _ev(id: 'e1', title: 'Coffee', attendees: ['ada@x.com', 'bob@x.com']),
      ], now: _now);
      expect(out, hasLength(2));
      expect(out.every((d) => d.type == InteractionType.meeting), isTrue);
      expect(out.first.id, 'calendar-e1-ada@x.com');
      expect(out.first.matchEmail, 'ada@x.com');
      expect(out.first.note, contains('Coffee'));
      expect(out.first.date, _now.subtract(const Duration(hours: 2)));
    });

    test('skips events that have not ended yet', () {
      final out = meetingsFromEvents([
        _ev(
          id: 'future',
          attendees: ['ada@x.com'],
          start: _now.add(const Duration(hours: 1)),
          end: _now.add(const Duration(hours: 2)),
        ),
        _ev(
          id: 'ongoing',
          attendees: ['ada@x.com'],
          start: _now.subtract(const Duration(hours: 1)),
          end: _now.add(const Duration(hours: 1)),
        ),
      ], now: _now);
      expect(out, isEmpty);
    });

    test('skips all-day events (holidays/birthdays are noise)', () {
      final out = meetingsFromEvents([
        _ev(id: 'allday', attendees: ['ada@x.com'], allDay: true),
      ], now: _now);
      expect(out, isEmpty);
    });

    test('excludes the user\'s own email from attendees', () {
      final out = meetingsFromEvents(
        [
          _ev(id: 'e1', attendees: ['me@x.com', 'ada@x.com']),
        ],
        now: _now,
        selfEmails: {'ME@x.com'},
      );
      expect(out, hasLength(1));
      expect(out.first.matchEmail, 'ada@x.com');
    });

    test('ignores events with no attendees', () {
      final out = meetingsFromEvents([_ev(id: 'solo')], now: _now);
      expect(out, isEmpty);
    });

    test('deterministic ids make the end-to-end merge idempotent', () {
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
      final records = meetingsFromEvents([
        _ev(id: 'e1', title: 'Coffee', attendees: ['ada@x.com']),
      ], now: _now);
      final once = applyDetectedInteractions(contacts, records);
      final twice = applyDetectedInteractions(once, records);
      expect(twice.first.interactions, hasLength(1));
      expect(twice.first.interactions.first.type, InteractionType.meeting);
    });
  });
}
