import 'package:flutter_test/flutter_test.dart';
import 'package:social_graph/models/contact.dart';
import 'package:social_graph/services/outbound_prompt.dart';

final _now = DateTime(2026, 6, 3, 12, 0, 0);

PendingOutbound _p({
  DateTime? launchedAt,
  InteractionType type = InteractionType.call,
}) => PendingOutbound(
  contactId: 'a',
  contactName: 'Ada',
  eventId: 'evt-1',
  type: type,
  launchedAt: launchedAt ?? _now.subtract(const Duration(seconds: 30)),
);

void main() {
  group('shouldConfirmOnResume', () {
    test('prompts when the app was backgrounded for a real interval', () {
      expect(
        shouldConfirmOnResume(_p(), wentBackground: true, now: _now),
        isTrue,
      );
    });

    test('does not prompt if the app never went to the background', () {
      // e.g. a manual note logged without leaving the app.
      expect(
        shouldConfirmOnResume(_p(), wentBackground: false, now: _now),
        isFalse,
      );
    });

    test('does not prompt for an instant bail-out (mis-tap)', () {
      final p = _p(launchedAt: _now.subtract(const Duration(seconds: 1)));
      expect(
        shouldConfirmOnResume(p, wentBackground: true, now: _now),
        isFalse,
      );
    });

    test('does not prompt for a stale pending action', () {
      final p = _p(launchedAt: _now.subtract(const Duration(hours: 4)));
      expect(
        shouldConfirmOnResume(p, wentBackground: true, now: _now),
        isFalse,
      );
    });
  });

  group('isOutboundType', () {
    test('call/text/email are outbound; note is not', () {
      expect(isOutboundType(InteractionType.call), isTrue);
      expect(isOutboundType(InteractionType.text), isTrue);
      expect(isOutboundType(InteractionType.email), isTrue);
      expect(isOutboundType(InteractionType.note), isFalse);
      expect(isOutboundType(InteractionType.meeting), isFalse);
    });
  });

  group('confirmLabel', () {
    test('reads naturally per type', () {
      expect(
        confirmLabel(_p(type: InteractionType.call)),
        'Logged a call with Ada',
      );
      expect(
        confirmLabel(_p(type: InteractionType.text)),
        'Logged a text with Ada',
      );
      expect(
        confirmLabel(_p(type: InteractionType.email)),
        'Logged an email with Ada',
      );
    });
  });
}
