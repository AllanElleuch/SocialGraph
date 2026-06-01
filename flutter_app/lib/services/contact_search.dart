import '../models/contact.dart';

/// Returns only the digit characters of [input] (strips spaces, dashes,
/// parentheses, plus signs, etc.). Returns an empty string when none.
String _digitsOnly(String input) {
  return input.replaceAll(RegExp(r'\D'), '');
}

/// Returns true when [c] matches the free-text [query].
///
/// Rules:
/// - An empty or whitespace-only [query] matches every contact.
/// - Otherwise the (trimmed, lower-cased) query is matched as a
///   case-insensitive substring against the contact's display name, phone,
///   email, workplace, location met, and each tag.
/// - For phone matching, if the query contains digits, those digits are also
///   matched as a substring of the contact's phone digits (both stripped of
///   non-digit characters). This lets "5551234" match "(555) 123-4..." style
///   formatting.
bool contactMatchesQuery(Contact c, String query) {
  final trimmed = query.trim();
  if (trimmed.isEmpty) return true;

  final q = trimmed.toLowerCase();

  final haystacks = <String>[
    c.displayName,
    c.phone,
    c.email,
    c.workplace,
    c.locationMet,
    ...c.tags,
  ];

  for (final field in haystacks) {
    if (field.toLowerCase().contains(q)) return true;
  }

  final queryDigits = _digitsOnly(trimmed);
  if (queryDigits.isNotEmpty) {
    final phoneDigits = _digitsOnly(c.phone);
    if (phoneDigits.isNotEmpty && phoneDigits.contains(queryDigits)) {
      return true;
    }
  }

  return false;
}
