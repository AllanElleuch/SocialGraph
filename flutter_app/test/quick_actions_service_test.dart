import 'package:flutter_test/flutter_test.dart';
import 'package:social_graph/services/quick_actions_service.dart';

void main() {
  group('QuickActionsService.telUri', () {
    test('sanitizes spaces, dashes, and parens, preserving leading +', () {
      expect(
        QuickActionsService.telUri('+1 (555) 123-4567'),
        Uri.parse('tel:+15551234567'),
      );
    });

    test('strips separators without a leading +', () {
      expect(
        QuickActionsService.telUri('(555) 123-4567'),
        Uri.parse('tel:5551234567'),
      );
    });

    test('returns null for blank input', () {
      expect(QuickActionsService.telUri(''), isNull);
      expect(QuickActionsService.telUri('   '), isNull);
    });

    test('returns null when no dialable digits remain', () {
      expect(QuickActionsService.telUri('---'), isNull);
    });
  });

  group('QuickActionsService.smsUri', () {
    test('builds an sms URI with sanitized number', () {
      expect(
        QuickActionsService.smsUri('+1 (555) 123-4567'),
        Uri.parse('sms:+15551234567'),
      );
    });

    test('has sms scheme', () {
      expect(QuickActionsService.smsUri('5551234567')?.scheme, 'sms');
    });

    test('returns null for blank input', () {
      expect(QuickActionsService.smsUri(''), isNull);
      expect(QuickActionsService.smsUri('  '), isNull);
    });
  });

  group('QuickActionsService.mailtoUri', () {
    test('has mailto scheme', () {
      expect(QuickActionsService.mailtoUri('a@b.com')?.scheme, 'mailto');
    });

    test('preserves the address in the path', () {
      expect(QuickActionsService.mailtoUri('a@b.com')?.path, 'a@b.com');
    });

    test('trims surrounding whitespace', () {
      expect(QuickActionsService.mailtoUri('  a@b.com  ')?.path, 'a@b.com');
    });

    test('returns null for blank input', () {
      expect(QuickActionsService.mailtoUri(''), isNull);
      expect(QuickActionsService.mailtoUri('   '), isNull);
    });
  });

  group('QuickActionsService.sanitizePhone', () {
    test('keeps a single leading +', () {
      expect(QuickActionsService.sanitizePhone('+1-555-123-4567'),
          '+15551234567');
    });

    test('returns null for blank or digitless input', () {
      expect(QuickActionsService.sanitizePhone(''), isNull);
      expect(QuickActionsService.sanitizePhone('()- '), isNull);
    });
  });
}
