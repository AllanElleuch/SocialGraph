import '../models/contact.dart';
import 'interaction_log.dart';

/// Direction of a phone call from the device call log.
enum CallDirection { incoming, outgoing, missed }

/// A platform-agnostic call-log entry. The Android `call_log` plugin entries are
/// mapped onto this so the merge logic below stays pure and testable (no plugin,
/// no platform channels, no clock).
class CallRecord {
  final String number;
  final DateTime timestamp;
  final CallDirection direction;
  final int durationSeconds;

  const CallRecord({
    required this.number,
    required this.timestamp,
    required this.direction,
    this.durationSeconds = 0,
  });
}

/// Stable interaction id for a call-log entry, so re-syncing the same call never
/// creates a duplicate interaction. Two calls to/from the same person can't
/// share a millisecond, so the timestamp alone is a safe key.
String callInteractionId(CallRecord r) =>
    'calllog-${r.timestamp.millisecondsSinceEpoch}';

/// Reduces a phone number to comparable digits: strips all non-digits and keeps
/// the last [_matchDigits] so differing country-code/formatting still matches
/// (e.g. "+1 (415) 555-0100" and "415-555-0100"). Returns null when blank.
String? normalizePhone(String phone) {
  final digits = phone.replaceAll(RegExp(r'[^0-9]'), '');
  if (digits.isEmpty) return null;
  return digits.length <= _matchDigits
      ? digits
      : digits.substring(digits.length - _matchDigits);
}

const int _matchDigits = 9;

/// Whether a call record represents an actual conversation worth logging as an
/// interaction: a connected incoming/outgoing call. Missed calls and
/// zero-duration (declined / unanswered) calls are skipped so the timeline and
/// stats reflect real contact, not ring attempts.
bool isLoggableCall(CallRecord r) =>
    r.direction != CallDirection.missed && r.durationSeconds > 0;

String _formatDuration(int seconds) {
  if (seconds < 60) return '${seconds}s';
  final m = seconds ~/ 60;
  final s = seconds % 60;
  return s == 0 ? '${m}m' : '${m}m ${s}s';
}

/// Human-readable note stored on the logged interaction, e.g.
/// "Incoming call · 3m 12s".
String callNoteLabel(CallRecord r) {
  final dir = switch (r.direction) {
    CallDirection.incoming => 'Incoming call',
    CallDirection.outgoing => 'Outgoing call',
    CallDirection.missed => 'Missed call',
  };
  if (r.durationSeconds <= 0 || r.direction == CallDirection.missed) return dir;
  return '$dir · ${_formatDuration(r.durationSeconds)}';
}

/// Returns a new contact list with a `call` interaction added for every
/// loggable [records] entry whose number matches a contact, skipping any call
/// already logged (idempotent — safe to run on every launch). Inputs are never
/// mutated.
List<Contact> applyCallRecords(
  List<Contact> contacts,
  List<CallRecord> records,
) {
  if (records.isEmpty) return contacts;

  // Index contacts by normalized phone for O(1) matching.
  final byPhone = <String, int>{};
  for (var i = 0; i < contacts.length; i++) {
    final n = normalizePhone(contacts[i].phone);
    if (n != null) byPhone.putIfAbsent(n, () => i);
  }
  if (byPhone.isEmpty) return contacts;

  final result = [...contacts];
  // Lazily-built set of existing interaction ids per touched contact, so
  // dedup is cheap even when a contact has many interactions.
  final seenIds = <int, Set<String>>{};

  for (final r in records) {
    if (!isLoggableCall(r)) continue;
    final n = normalizePhone(r.number);
    if (n == null) continue;
    final idx = byPhone[n];
    if (idx == null) continue;

    final ids = seenIds.putIfAbsent(
      idx,
      () => result[idx].interactions.map((e) => e.id).toSet(),
    );
    final id = callInteractionId(r);
    if (!ids.add(id)) continue; // already logged

    result[idx] = result[idx].logInteraction(
      InteractionEvent(
        id: id,
        date: r.timestamp,
        type: InteractionType.call,
        note: callNoteLabel(r),
      ),
    );
  }
  return result;
}
