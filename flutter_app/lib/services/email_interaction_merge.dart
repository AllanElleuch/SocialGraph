import '../models/contact.dart';
import 'interaction_match.dart';

export 'interaction_match.dart' show applyDetectedInteractions;

/// A platform-agnostic email message (metadata only — never body content). The
/// Gmail and Microsoft Graph clients map their responses onto this so the
/// interaction-detection logic below stays pure and testable.
///
/// Only headers are needed: from / to / date / subject. Reading just metadata
/// keeps the OAuth scope as narrow as possible.
class EmailRecord {
  final String messageId;
  final String fromEmail;
  final List<String> toEmails;
  final String subject;
  final DateTime date;

  const EmailRecord({
    required this.messageId,
    required this.fromEmail,
    required this.toEmails,
    required this.subject,
    required this.date,
  });
}

/// Turns email [messages] into detected `email` interactions with the *other*
/// party — pure, no network, no clock.
///
///   * **Inbound** (sender ≠ you): one interaction with the sender.
///   * **Outbound** (sender is one of [selfEmails]): one interaction per
///     non-self recipient.
///
/// Your own addresses ([selfEmails], matched case-insensitively) are never
/// logged as a counterpart. Each id is `gmail-<messageId>-<party>`,
/// deterministic so re-syncing the same message never duplicates.
List<DetectedInteraction> emailInteractionsFrom(
  List<EmailRecord> messages, {
  required Set<String> selfEmails,
}) {
  final self = {
    for (final e in selfEmails)
      if (normalizeEmail(e) != null) normalizeEmail(e)!,
  };

  final out = <DetectedInteraction>[];
  for (final m in messages) {
    final from = normalizeEmail(m.fromEmail);
    final fromIsSelf = from != null && self.contains(from);

    final parties = <String>[];
    if (from == null) {
      // Unknown sender — nothing to attribute reliably.
      continue;
    } else if (!fromIsSelf) {
      parties.add(from); // inbound: log with the sender
    } else {
      for (final raw in m.toEmails) {
        final to = normalizeEmail(raw);
        if (to != null && !self.contains(to)) parties.add(to);
      }
    }

    final direction = fromIsSelf ? 'Sent' : 'Received';
    for (final party in parties) {
      out.add(
        DetectedInteraction(
          id: 'gmail-${m.messageId}-$party',
          date: m.date,
          type: InteractionType.email,
          note: _noteFor(direction, m.subject),
          matchEmail: party,
        ),
      );
    }
  }
  return out;
}

String _noteFor(String direction, String subject) {
  final s = subject.trim();
  return s.isEmpty ? '$direction email' : '$direction email: $s';
}
