import '../models/contact.dart';

/// Tracks an outbound action (call/text/email) the user just launched from a
/// contact card, so that when they return to the app we can confirm it really
/// happened — and let them remove it with one tap if it didn't (wrong number,
/// no answer, butterfingers).
///
/// In-app quick actions already log optimistically on tap; this turns that
/// optimistic log into a confirmable one without changing the tap behaviour.
class PendingOutbound {
  final String contactId;
  final String contactName;

  /// Id of the interaction that was optimistically logged, so "Remove" can undo
  /// exactly that event.
  final String eventId;
  final InteractionType type;
  final DateTime launchedAt;

  const PendingOutbound({
    required this.contactId,
    required this.contactName,
    required this.eventId,
    required this.type,
    required this.launchedAt,
  });
}

/// Below this, returning to the app is treated as an immediate bail-out
/// (mis-tap) and we stay quiet.
const Duration _kMinAway = Duration(seconds: 5);

/// Above this, the pending action is stale (the user did other things); we
/// don't surface a late, confusing prompt.
const Duration _kMaxWindow = Duration(hours: 2);

/// Whether [type] is an outbound action that sends the user to an external app
/// (and therefore backgrounds us). Only these warrant a return-prompt; manual
/// notes and detected meetings do not.
bool isOutboundType(InteractionType type) =>
    type == InteractionType.call ||
    type == InteractionType.text ||
    type == InteractionType.email;

/// Decides whether to surface the confirm/undo prompt when the app resumes.
///
/// Pure: the caller supplies [now] and whether the app actually went to the
/// background ([wentBackground]). We only prompt when the user genuinely left
/// for an external app for a plausible interval.
bool shouldConfirmOnResume(
  PendingOutbound pending, {
  required bool wentBackground,
  required DateTime now,
}) {
  if (!wentBackground) return false;
  final away = now.difference(pending.launchedAt);
  return away >= _kMinAway && away <= _kMaxWindow;
}

/// "Logged a call with Ada" / "Logged an email with Ada".
String confirmLabel(PendingOutbound pending) {
  final noun = switch (pending.type) {
    InteractionType.call => 'a call',
    InteractionType.text => 'a text',
    InteractionType.email => 'an email',
    InteractionType.meeting => 'a meeting',
    InteractionType.note => 'a note',
  };
  return 'Logged $noun with ${pending.contactName}';
}
