import '../models/contact.dart';
import 'call_log_merge.dart' show normalizePhone;
import 'interaction_log.dart';

/// A platform-agnostic interaction detected by some automatic source (device
/// calendar, Gmail, Google Calendar, an outbound action, …) before it has been
/// matched to a contact.
///
/// Every source maps its native payload onto this shape, then hands a list to
/// [applyDetectedInteractions]. Keeping the matching/dedup logic here (pure, no
/// plugins, no clock) means each source only needs a tiny, testable mapper.
///
/// Matching precedence is [matchContactId] → [matchEmail] → [matchPhone]; the
/// first that resolves to a contact wins. [id] must be deterministic for the
/// underlying real-world event so re-syncing never creates a duplicate (mirrors
/// `callInteractionId`).
class DetectedInteraction {
  final String id;
  final DateTime date;
  final InteractionType type;
  final String note;

  /// Direct contact id, when the source already knows it.
  final String? matchContactId;

  /// Email to match against [Contact.email] (case-insensitive).
  final String? matchEmail;

  /// Phone to match against [Contact.phone] (last-9-digit normalization).
  final String? matchPhone;

  const DetectedInteraction({
    required this.id,
    required this.date,
    required this.type,
    this.note = '',
    this.matchContactId,
    this.matchEmail,
    this.matchPhone,
  });
}

/// Reduces an email to a comparable key: trimmed + lower-cased. Returns null
/// when blank or obviously not an address (no `@`), so non-matches are skipped
/// rather than mis-indexed.
String? normalizeEmail(String? email) {
  if (email == null) return null;
  final e = email.trim().toLowerCase();
  if (e.isEmpty || !e.contains('@')) return null;
  return e;
}

/// Returns a new contact list with an interaction added for every [records]
/// entry that matches a contact, skipping any interaction id already present
/// (idempotent — safe to run on every launch). Inputs are never mutated; the
/// original list is returned unchanged when nothing matches.
List<Contact> applyDetectedInteractions(
  List<Contact> contacts,
  List<DetectedInteraction> records,
) {
  if (records.isEmpty) return contacts;

  final byId = <String, int>{};
  final byEmail = <String, int>{};
  final byPhone = <String, int>{};
  for (var i = 0; i < contacts.length; i++) {
    byId[contacts[i].id] = i;
    final e = normalizeEmail(contacts[i].email);
    if (e != null) byEmail.putIfAbsent(e, () => i);
    final p = normalizePhone(contacts[i].phone);
    if (p != null) byPhone.putIfAbsent(p, () => i);
  }

  List<Contact>? result; // copy-on-first-write
  final seenIds = <int, Set<String>>{};

  for (final r in records) {
    final idx = _matchIndex(r, byId, byEmail, byPhone);
    if (idx == null) continue;

    final current = result ?? contacts;
    final ids = seenIds.putIfAbsent(
      idx,
      () => current[idx].interactions.map((e) => e.id).toSet(),
    );
    if (!ids.add(r.id)) continue; // already logged

    result ??= [...contacts];
    result[idx] = result[idx].logInteraction(
      InteractionEvent(id: r.id, date: r.date, type: r.type, note: r.note),
    );
  }

  return result ?? contacts;
}

int? _matchIndex(
  DetectedInteraction r,
  Map<String, int> byId,
  Map<String, int> byEmail,
  Map<String, int> byPhone,
) {
  final cid = r.matchContactId;
  if (cid != null && byId.containsKey(cid)) return byId[cid];
  final e = normalizeEmail(r.matchEmail);
  if (e != null && byEmail.containsKey(e)) return byEmail[e];
  final p = normalizePhone(r.matchPhone ?? '');
  if (p != null && byPhone.containsKey(p)) return byPhone[p];
  return null;
}
