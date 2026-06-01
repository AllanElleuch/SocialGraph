import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/contact.dart';

/// Local-first persistence for the contact list (RFC-004, U4.1).
///
/// Stores the JSON-encoded list of [Contact]s in [SharedPreferences] under a
/// single versioned key. The list of contacts is the unit of persistence.
///
/// Designed to be injectable/testable: pass a ready [SharedPreferences]
/// instance or a custom async getter; otherwise it defaults to
/// [SharedPreferences.getInstance].
class ContactRepository {
  /// Storage key for the cached contact list. Versioned so the schema can be
  /// migrated in future without colliding with old payloads.
  static const String storageKey = 'contacts_cache_v1';

  final Future<SharedPreferences> Function() _prefsGetter;

  /// Creates a repository.
  ///
  /// Provide [prefs] for a fixed instance, or [prefsGetter] for a custom async
  /// resolver. When neither is supplied, [SharedPreferences.getInstance] is
  /// used.
  ContactRepository({
    SharedPreferences? prefs,
    Future<SharedPreferences> Function()? prefsGetter,
  }) : _prefsGetter = prefsGetter ??
            (prefs != null
                ? (() async => prefs)
                : SharedPreferences.getInstance);

  /// Reads the cached contact list.
  ///
  /// Returns `[]` when nothing is stored. If the stored value is corrupt
  /// (invalid JSON or unexpected shape), the error is caught, logged, and `[]`
  /// is returned so the caller can fall back to seed data. Never throws on
  /// corrupt data.
  Future<List<Contact>> load() async {
    try {
      final prefs = await _prefsGetter();
      final raw = prefs.getString(storageKey);
      if (raw == null || raw.isEmpty) {
        return [];
      }

      final decoded = jsonDecode(raw);
      if (decoded is! List) {
        debugPrint(
          'ContactRepository.load: stored value is not a JSON list; '
          'returning empty list.',
        );
        return [];
      }

      return decoded
          .map((e) => Contact.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (e) {
      debugPrint('ContactRepository.load: failed to decode cache: $e');
      return [];
    }
  }

  /// JSON-encodes and persists [contacts] under [storageKey].
  Future<void> save(List<Contact> contacts) async {
    final prefs = await _prefsGetter();
    final encoded = jsonEncode(contacts.map((c) => c.toJson()).toList());
    await prefs.setString(storageKey, encoded);
  }

  /// Removes the cached contact list.
  Future<void> clear() async {
    final prefs = await _prefsGetter();
    await prefs.remove(storageKey);
  }
}
