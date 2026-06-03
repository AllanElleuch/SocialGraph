/// Pure JSON → record parsers for the Google Calendar and Gmail REST APIs.
///
/// Kept separate from the network layer so the (fiddly) header/date parsing is
/// fully unit-testable without OAuth or HTTP. The sync services call these on
/// the decoded response body.
library;

import 'calendar_meeting_merge.dart' show CalendarEventRecord;
import 'email_interaction_merge.dart' show EmailRecord;

final _angleEmail = RegExp(r'<([^>]+)>');
final _bareEmail = RegExp(r'[^\s,;<>"]+@[^\s,;<>"]+');

/// Extracts a lowercased email from a header fragment like `Ada <ada@x.com>`
/// or a bare `ada@x.com`. Returns null when none is present.
String? extractEmailAddress(String raw) {
  final angle = _angleEmail.firstMatch(raw);
  final value = angle != null ? angle.group(1)! : raw;
  final match = _bareEmail.firstMatch(value);
  return match?.group(0)!.trim().toLowerCase();
}

/// Splits a multi-recipient header (comma-separated) into emails.
List<String> _extractAll(String raw) => [
  for (final part in raw.split(','))
    if (extractEmailAddress(part) != null) extractEmailAddress(part)!,
];

String? _header(List<dynamic> headers, String name) {
  for (final h in headers) {
    if (h is Map &&
        (h['name'] as String?)?.toLowerCase() == name.toLowerCase()) {
      return h['value'] as String?;
    }
  }
  return null;
}

/// Maps a Gmail `users.messages.get` (format=metadata) payload to an
/// [EmailRecord]. Returns null if it lacks an id, sender, or date.
EmailRecord? parseGmailMessage(Map<String, dynamic> json) {
  final id = json['id'] as String?;
  final payload = json['payload'];
  if (id == null || payload is! Map) return null;
  final headers = (payload['headers'] as List?) ?? const [];

  final fromRaw = _header(headers, 'From');
  final from = fromRaw == null ? null : extractEmailAddress(fromRaw);
  if (from == null) return null;

  final toRaw = _header(headers, 'To') ?? '';
  final subject = _header(headers, 'Subject') ?? '';

  final internalMs = int.tryParse(json['internalDate'] as String? ?? '');
  if (internalMs == null) return null;

  return EmailRecord(
    messageId: id,
    fromEmail: from,
    toEmails: _extractAll(toRaw),
    subject: subject,
    date: DateTime.fromMillisecondsSinceEpoch(internalMs),
  );
}

/// Maps a Google Calendar `events.list` response to [CalendarEventRecord]s.
/// All-day events are flagged via a `date` (vs `dateTime`) start.
List<CalendarEventRecord> parseGoogleCalendarEvents(Map<String, dynamic> json) {
  final items = (json['items'] as List?) ?? const [];
  final out = <CalendarEventRecord>[];
  for (final raw in items) {
    if (raw is! Map) continue;
    final id = raw['id'] as String?;
    if (id == null) continue;

    final start = raw['start'];
    final end = raw['end'];
    if (start is! Map || end is! Map) continue;

    final isAllDay = start['dateTime'] == null && start['date'] != null;
    final startDt = _parseEventTime(start);
    final endDt = _parseEventTime(end);
    if (startDt == null || endDt == null) continue;

    final attendees = <String>[
      for (final a in (raw['attendees'] as List?) ?? const [])
        if (a is Map && a['email'] is String)
          (a['email'] as String).toLowerCase(),
    ];

    out.add(
      CalendarEventRecord(
        eventId: id,
        title: (raw['summary'] as String?) ?? '',
        start: startDt,
        end: endDt,
        attendeeEmails: attendees,
        isAllDay: isAllDay,
      ),
    );
  }
  return out;
}

DateTime? _parseEventTime(Map<dynamic, dynamic> node) {
  final dateTime = node['dateTime'] as String?;
  if (dateTime != null) return DateTime.tryParse(dateTime)?.toLocal();
  final date = node['date'] as String?;
  if (date != null) return DateTime.tryParse(date);
  return null;
}
