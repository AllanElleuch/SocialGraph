import '../models/contact.dart';

/// Result of evaluating a contact's stay-in-touch cadence.
///
/// [dueInDays] is the number of whole days until the next reach-out is due.
/// A negative value means the reach-out is overdue (that many days past due).
/// [isOverdue] is true when [now] is strictly after the computed due date.
class ReachOutStatus {
  final int dueInDays;
  final bool isOverdue;

  const ReachOutStatus({
    required this.dueInDays,
    required this.isOverdue,
  });
}

/// Sentinel "due in days" used when cadence is off (no reminders).
const int kReachOutOffDueInDays = 1 << 30;

/// Tag-based default cadences (days between reach-outs).
const int _familyCadenceDays = 30;
const int _friendsCadenceDays = 45;
const int _defaultCadenceDays = 90;

/// Resolves the effective cadence (in days) for [c].
///
/// Uses the explicit [Contact.reminderCadenceDays] when set, otherwise falls
/// back to a tag default: Family=30, Friends=45, otherwise 90.
int _effectiveCadenceDays(Contact c) {
  final explicit = c.reminderCadenceDays;
  if (explicit != null) return explicit;

  if (c.tags.contains('Family')) return _familyCadenceDays;
  if (c.tags.contains('Friends')) return _friendsCadenceDays;
  return _defaultCadenceDays;
}

/// Computes the stay-in-touch status for [c] relative to [now].
///
/// Pure logic: [now] must be supplied by the caller; this never reads the
/// system clock.
ReachOutStatus reachOutStatus(Contact c, {required DateTime now}) {
  final cadence = _effectiveCadenceDays(c);

  // Cadence of zero or below means reminders are off for this contact.
  if (cadence <= 0) {
    return const ReachOutStatus(
      dueInDays: kReachOutOffDueInDays,
      isOverdue: false,
    );
  }

  // With no interaction history and an unknown "date met" there is no basis
  // to compute a reach-out cadence, so reminders stay off for this contact.
  final baseline = c.lastInteraction ?? c.dateMet;
  if (baseline == null) {
    return const ReachOutStatus(
      dueInDays: kReachOutOffDueInDays,
      isOverdue: false,
    );
  }
  final dueDate = baseline.add(Duration(days: cadence));

  return ReachOutStatus(
    dueInDays: dueDate.difference(now).inDays,
    isOverdue: now.isAfter(dueDate),
  );
}

/// Returns the overdue contacts from [all], sorted most-overdue first
/// (most negative [ReachOutStatus.dueInDays] first).
List<Contact> overdueContacts(List<Contact> all, {required DateTime now}) {
  final overdue = <(Contact, int)>[];
  for (final c in all) {
    final status = reachOutStatus(c, now: now);
    if (status.isOverdue) {
      overdue.add((c, status.dueInDays));
    }
  }

  overdue.sort((a, b) => a.$2.compareTo(b.$2));
  return overdue.map((e) => e.$1).toList();
}
