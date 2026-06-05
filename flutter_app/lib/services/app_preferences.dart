import 'package:shared_preferences/shared_preferences.dart';

import '../painters/star_style.dart';
import '../painters/cluster_layouts.dart';

/// Lightweight persistence for user-facing display preferences (kept separate
/// from contact data). Backed by [SharedPreferences].
class AppPreferences {
  static const _starColorKey = 'pref.starColorMode';
  static const _layoutOverridesKey = 'pref.clusterLayoutOverrides';

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

  /// Loads per-cluster layout overrides (tag → chosen rendering).
  Future<Map<String, ClusterLayout>> loadLayoutOverrides() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getStringList(_layoutOverridesKey) ?? const [];
    final map = <String, ClusterLayout>{};
    for (final entry in raw) {
      final i = entry.indexOf('=');
      if (i <= 0) continue;
      map[entry.substring(0, i)] =
          clusterLayoutFromName(entry.substring(i + 1));
    }
    return map;
  }

  /// Persists per-cluster layout overrides.
  Future<void> saveLayoutOverrides(Map<String, ClusterLayout> overrides) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(
      _layoutOverridesKey,
      [for (final e in overrides.entries) '${e.key}=${e.value.name}'],
    );
  }
}
