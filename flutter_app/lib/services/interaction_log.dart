import 'package:social_graph/models/contact.dart';

/// Interaction logging core (RFC-003, U3.1).
///
/// Provides immutable helpers for appending [InteractionEvent]s to a [Contact].
/// All methods return a new [Contact] via `copyWith` and never mutate inputs.
extension InteractionLog on Contact {
  /// Returns a new [Contact] with [event] inserted into [interactions] kept
  /// sorted newest-first, and [lastInteraction] advanced to the max of the
  /// current value and [event.date].
  ///
  /// Logging an older event never regresses [lastInteraction].
  Contact logInteraction(InteractionEvent event) {
    final updatedEvents = <InteractionEvent>[...interactions, event]
      ..sort((a, b) => b.date.compareTo(a.date));

    final existing = lastInteraction;
    final newLast = (existing == null || event.date.isAfter(existing))
        ? event.date
        : existing;

    return copyWith(
      interactions: updatedEvents,
      lastInteraction: newLast,
    );
  }

  /// Builds an [InteractionEvent] from the given fields and logs it.
  ///
  /// [id] and [now] are passed in (rather than generated internally) so the
  /// result stays deterministic and testable; this method never calls
  /// `DateTime.now()`.
  Contact logInteractionNow(
    InteractionType type, {
    String note = '',
    required String id,
    required DateTime now,
  }) {
    return logInteraction(
      InteractionEvent(id: id, date: now, type: type, note: note),
    );
  }
}
