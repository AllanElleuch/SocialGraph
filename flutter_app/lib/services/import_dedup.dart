import '../models/contact.dart';

/// Returns the contacts from [incoming] that should actually be added to
/// [existing] — dropping any that already exist and any that repeat an earlier
/// entry within [incoming] itself.
///
/// This fixes two ways device imports otherwise create duplicates:
///   - **One person, several numbers.** Address books can expose a single
///     person as multiple raw entries (same name, different numbers); without
///     within-batch dedup each lands as its own row.
///   - **Re-import.** Importing again should never re-add someone already
///     present; the stable device id makes that idempotent.
///
/// Two contacts are treated as the same person when they share ANY of:
///   1. the import device id (the same address-book entry, re-imported),
///   2. a phone number (compared digits-only),
///   3. an email (case-insensitive), or
///   4. a normalized display name.
///
/// Order is preserved: the first occurrence wins, later duplicates are skipped.
List<Contact> dedupeImportedContacts(
  List<Contact> existing,
  List<Contact> incoming,
) {
  final deviceIds = <String>{};
  final phones = <String>{};
  final emails = <String>{};
  final names = <String>{};

  void register(Contact c) {
    final deviceId = c.origin?.deviceId ?? '';
    if (deviceId.isNotEmpty) deviceIds.add(deviceId);
    final phone = _digitsOnly(c.phone);
    if (phone.isNotEmpty) phones.add(phone);
    final email = c.email.trim().toLowerCase();
    if (email.isNotEmpty) emails.add(email);
    final name = _normalizeName(c.displayName);
    if (name.isNotEmpty) names.add(name);
  }

  bool isDuplicate(Contact c) {
    final deviceId = c.origin?.deviceId ?? '';
    if (deviceId.isNotEmpty && deviceIds.contains(deviceId)) return true;
    final phone = _digitsOnly(c.phone);
    if (phone.isNotEmpty && phones.contains(phone)) return true;
    final email = c.email.trim().toLowerCase();
    if (email.isNotEmpty && emails.contains(email)) return true;
    final name = _normalizeName(c.displayName);
    if (name.isNotEmpty && names.contains(name)) return true;
    return false;
  }

  for (final c in existing) {
    register(c);
  }

  final toAdd = <Contact>[];
  for (final c in incoming) {
    if (isDuplicate(c)) continue;
    toAdd.add(c);
    register(c);
  }
  return toAdd;
}

/// Keeps only the digits of a phone string so formatting differences
/// (spaces, dashes, "+") don't defeat matching.
String _digitsOnly(String phone) {
  final buffer = StringBuffer();
  for (final unit in phone.codeUnits) {
    if (unit >= 0x30 && unit <= 0x39) buffer.writeCharCode(unit);
  }
  return buffer.toString();
}

/// Lowercases, collapses whitespace, and drops punctuation so trivially
/// different renderings of the same name compare equal.
String _normalizeName(String name) {
  final raw = name.toLowerCase();
  final buffer = StringBuffer();
  var lastWasSpace = false;
  for (final rune in raw.runes) {
    final isAlphaNum =
        (rune >= 0x30 && rune <= 0x39) || (rune >= 0x61 && rune <= 0x7a);
    if (isAlphaNum) {
      buffer.writeCharCode(rune);
      lastWasSpace = false;
    } else if (rune == 0x20 || rune == 0x09) {
      if (!lastWasSpace) {
        buffer.write(' ');
        lastWasSpace = true;
      }
    }
  }
  return buffer.toString().trim();
}
