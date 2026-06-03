import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Persistence for *claimed* weekly-quest rewards (the gamification ledger).
///
/// The active quests and their progress are re-derived each week from the
/// contacts (see `WeeklyQuests`), so the only thing worth storing is which
/// quests the player has already turned in and how much XP each granted. The
/// XP is recorded at claim time so it survives later edits to the underlying
/// data and the weekly rotation.
///
/// Stored as a single JSON object `{ "<questKey>": <xp>, ... }` under a
/// versioned key. Injectable/testable in the same shape as [ContactRepository].
class QuestStore {
  /// Storage key for the claimed-quest ledger. Versioned for future migration.
  static const String storageKey = 'claimed_quests_v1';

  final Future<SharedPreferences> Function() _prefsGetter;

  /// Creates a store. Provide [prefs] for a fixed instance, or [prefsGetter]
  /// for a custom async resolver; otherwise [SharedPreferences.getInstance] is
  /// used.
  QuestStore({
    SharedPreferences? prefs,
    Future<SharedPreferences> Function()? prefsGetter,
  }) : _prefsGetter = prefsGetter ??
            (prefs != null
                ? (() async => prefs)
                : SharedPreferences.getInstance);

  /// Reads the claim ledger as `{ questKey: xp }`.
  ///
  /// Returns `{}` when nothing is stored or the payload is corrupt — never
  /// throws, so a bad value degrades to "no quests claimed yet" rather than a
  /// crash on the Stats tab.
  Future<Map<String, int>> load() async {
    try {
      final prefs = await _prefsGetter();
      final raw = prefs.getString(storageKey);
      if (raw == null || raw.isEmpty) return {};

      final decoded = jsonDecode(raw);
      if (decoded is! Map) {
        debugPrint('QuestStore.load: stored value is not a JSON object.');
        return {};
      }
      return decoded.map(
        (key, value) => MapEntry(key.toString(), (value as num).toInt()),
      );
    } catch (e) {
      debugPrint('QuestStore.load: failed to read ledger: $e');
      return {};
    }
  }

  /// Records a claim for [key] worth [xp] and returns the updated ledger.
  ///
  /// Idempotent: claiming an already-claimed key leaves its recorded XP
  /// untouched (you can't double-collect a reward).
  Future<Map<String, int>> claim(String key, int xp) async {
    final prefs = await _prefsGetter();
    final ledger = await load();
    if (!ledger.containsKey(key)) {
      ledger[key] = xp;
      await prefs.setString(storageKey, jsonEncode(ledger));
    }
    return ledger;
  }

  /// Total XP banked from all claimed quests.
  static int totalXp(Map<String, int> ledger) =>
      ledger.values.fold(0, (sum, xp) => sum + xp);
}
