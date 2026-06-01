import 'package:flutter/foundation.dart';
import 'package:url_launcher/url_launcher.dart';

/// Service for launching quick contact actions: phone call, SMS, and email.
///
/// All public methods return `false` on blank input or launch failure and
/// never throw. The URI-building logic is exposed as pure static helpers so it
/// can be tested without a platform channel.
class QuickActionsService {
  const QuickActionsService();

  /// Sanitizes a phone number by stripping spaces, dashes, and parentheses
  /// while preserving a single leading `+`.
  ///
  /// Returns `null` if the input is blank or contains no dialable digits.
  static String? sanitizePhone(String phone) {
    final trimmed = phone.trim();
    if (trimmed.isEmpty) return null;

    final hasLeadingPlus = trimmed.startsWith('+');
    // Keep only digits; drop spaces, dashes, parens, and any other separators.
    final digits = trimmed.replaceAll(RegExp(r'[^0-9]'), '');
    if (digits.isEmpty) return null;

    return hasLeadingPlus ? '+$digits' : digits;
  }

  /// Builds a `tel:` URI for the given phone number, or `null` if blank.
  static Uri? telUri(String phone) {
    final sanitized = sanitizePhone(phone);
    if (sanitized == null) return null;
    return Uri(scheme: 'tel', path: sanitized);
  }

  /// Builds an `sms:` URI for the given phone number, or `null` if blank.
  static Uri? smsUri(String phone) {
    final sanitized = sanitizePhone(phone);
    if (sanitized == null) return null;
    return Uri(scheme: 'sms', path: sanitized);
  }

  /// Builds a `mailto:` URI for the given email address, or `null` if blank.
  static Uri? mailtoUri(String address) {
    final trimmed = address.trim();
    if (trimmed.isEmpty) return null;
    return Uri(scheme: 'mailto', path: trimmed);
  }

  /// Launches the phone dialer for [phone]. Returns `false` on blank input or
  /// launch failure.
  Future<bool> call(String phone) => _launch(telUri(phone));

  /// Launches the SMS composer for [phone]. Returns `false` on blank input or
  /// launch failure.
  Future<bool> sms(String phone) => _launch(smsUri(phone));

  /// Launches the email composer for [address]. Returns `false` on blank input
  /// or launch failure.
  Future<bool> email(String address) => _launch(mailtoUri(address));

  Future<bool> _launch(Uri? uri) async {
    if (uri == null) return false;
    try {
      return await launchUrl(uri);
    } catch (e) {
      debugPrint('QuickActionsService launch failed for $uri: $e');
      return false;
    }
  }
}
