import 'package:shared_preferences/shared_preferences.dart';

import '../painters/star_style.dart';

/// Lightweight persistence for user-facing display preferences (kept separate
/// from contact data). Backed by [SharedPreferences].
class AppPreferences {
  static const _starColorKey = 'pref.starColorMode';

  /// Loads the saved constellation star-color mode, defaulting to
  /// [StarColorMode.temperature].
  Future<StarColorMode> loadStarColorMode() async {
    final prefs = await SharedPreferences.getInstance();
    return starColorModeFromName(prefs.getString(_starColorKey));
  }

  /// Persists the chosen star-color mode.
  Future<void> saveStarColorMode(StarColorMode mode) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_starColorKey, mode.name);
  }
}
