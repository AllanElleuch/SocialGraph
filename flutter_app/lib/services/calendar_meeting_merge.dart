import '../models/contact.dart';
import 'interaction_match.dart';

export 'interaction_match.dart' show applyDetectedInteractions;

/// A platform-agnostic calendar event. The device calendar plugin
/// (`device_calendar`) and the Google Calendar API both map their events onto
/// this so the meeting-detection logic below stays pure and testable.
class CalendarEventRecord {
  final String eventId;
  final String title;
  final DateTime start;
  final DateTime end;

  /// Attendee email addresses (organizer + invitees). Used to match contacts.
  final List<String> attendeeEmails;

  final bool isAllDay;

  const CalendarEventRecord({
    required this.eventId,
    required this.title,
    required this.start,
    required this.end,
    this.attendeeEmails = const [],
    this.isAllDay = false,
  });
}

/// Turns calendar [events] into detected `meeting` interactions, one per
/// matched attendee. Pure: the caller supplies [now]; no clock, no plugin.
///
/// Rules that keep auto-logged meetings trustworthy:
///   * Only events that have **already ended** (`end <= now`) are logged, so a
///     meeting you might still skip isn't recorded prematurely.
///   * **All-day** events are ignored — they're usually holidays/birthdays, not
///     real meetings.
///   * The user's own addresses ([selfEmails], matched case-insensitively) are
///     excluded so you don't log a meeting "with yourself".
///
/// Each interaction id is `calendar-<eventId>-<email>`, deterministic so
/// re-syncing the same event never duplicates (see [applyDetectedInteractions]).
List<DetectedInteraction> meetingsFromEvents(
  List<CalendarEventRecord> events, {
  required DateTime now,
  Set<String> selfEmails = const {},
}) {
  final self = {
    for (final e in selfEmails)
      if (normalizeEmail(e) != null) normalizeEmail(e)!,
  };

  final out = <DetectedInteraction>[];
  for (final ev in events) {
    if (ev.isAllDay) continue;
    if (ev.end.isAfter(now)) continue; // not finished yet

    for (final raw in ev.attendeeEmails) {
      final email = normalizeEmail(raw);
      if (email == null || self.contains(email)) continue;
      out.add(
        DetectedInteraction(
          id: 'calendar-${ev.eventId}-$email',
          date: ev.start,
          type: InteractionType.meeting,
          note: _noteFor(ev.title),
          matchEmail: email,
        ),
      );
    }
  }
  return out;
}

String _noteFor(String title) {
  final t = title.trim();
  return t.isEmpty ? 'Calendar meeting' : 'Meeting: $t';
}
