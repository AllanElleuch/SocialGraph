import 'dart:math' as math;

/// Networker level / XP progression (Stats tab gamification).
///
/// Pure, deterministic: levels are derived entirely from the player's total XP,
/// which itself is derived from the contact data. There is no stored progress —
/// recomputing from the same contacts always yields the same level, so it needs
/// no migration and syncs for free through the existing backup.
///
/// ## XP sources (weights)
///
/// | Action                              | XP each |
/// |-------------------------------------|--------:|
/// | Contact in your network             |      10 |
/// | Logged interaction                  |       5 |
/// | Graph connection                    |       2 |
/// | Reconnect after a long dormant gap  |      15 |
///
/// ## Level curve
///
/// Cumulative XP required to *reach* level `L` (1-based) is `50 * (L - 1) * L`,
/// i.e. boundaries at 0, 100, 300, 600, 1000, … — each level costs 100 XP more
/// than the previous one.

/// XP awarded per contact in the network.
const int kXpPerContact = 10;

/// XP awarded per logged interaction event.
const int kXpPerInteraction = 5;

/// XP awarded per graph connection edge.
const int kXpPerConnection = 2;

/// XP awarded each time a dormant relationship is reconnected (see
/// [reconnectCount]).
const int kXpPerReconnect = 15;

/// A gap (in days) between consecutive interactions long enough that the later
/// interaction counts as "reconnecting" with a dormant contact.
const int kReconnectGapDays = 90;

/// Total XP earned across the whole network.
int totalXp({
  required int contactCount,
  required int interactionCount,
  required int connectionCount,
  required int reconnectCount,
}) =>
    contactCount * kXpPerContact +
    interactionCount * kXpPerInteraction +
    connectionCount * kXpPerConnection +
    reconnectCount * kXpPerReconnect;

/// Cumulative XP needed to *reach* [level] (1-based). Level 1 starts at 0 XP.
int xpForLevel(int level) {
  if (level <= 1) return 0;
  return 50 * (level - 1) * level;
}

/// The 1-based level reached with [xp] total experience.
int levelForXp(int xp) {
  if (xp <= 0) return 1;
  // Invert xp = 50*(L-1)*L  ->  L = (1 + sqrt(1 + 2*xp/25)) / 2, then floor.
  final l = (1 + math.sqrt(1 + 2 * xp / 25)) / 2;
  var level = l.floor();
  if (level < 1) level = 1;
  // Guard against floating-point edge cases at exact boundaries.
  while (xpForLevel(level + 1) <= xp) {
    level++;
  }
  while (level > 1 && xpForLevel(level) > xp) {
    level--;
  }
  return level;
}

/// A flavourful rank title for a given [level].
String rankTitleForLevel(int level) {
  if (level >= 10) return 'Networking Legend';
  if (level >= 7) return 'Super Connector';
  if (level >= 5) return 'Connector';
  if (level >= 3) return 'Networker';
  return 'Acquaintance';
}

/// Immutable snapshot of the player's level/XP standing.
class LevelStats {
  final int xp;
  final int level;

  const LevelStats({required this.xp, required this.level});

  /// Builds the standing from a raw [xp] total.
  factory LevelStats.fromXp(int xp) =>
      LevelStats(xp: xp, level: levelForXp(xp));

  /// XP threshold at the start of the current level.
  int get xpAtLevelStart => xpForLevel(level);

  /// XP threshold at the start of the next level.
  int get xpAtNextLevel => xpForLevel(level + 1);

  /// XP accumulated since the current level began.
  int get xpIntoLevel => xp - xpAtLevelStart;

  /// Total XP span of the current level.
  int get xpSpanThisLevel => xpAtNextLevel - xpAtLevelStart;

  /// XP still needed to reach the next level.
  int get xpToNextLevel => xpAtNextLevel - xp;

  /// Progress through the current level, 0..1.
  double get progress {
    final span = xpSpanThisLevel;
    if (span <= 0) return 0.0;
    return (xpIntoLevel / span).clamp(0.0, 1.0);
  }

  /// Flavour rank title, e.g. "Connector".
  String get rankTitle => rankTitleForLevel(level);

  /// "Level 4" headline.
  String get levelLabel => 'Level $level';

  /// "120 XP to Level 5" hint under the progress bar.
  String get nextLevelLabel => '$xpToNextLevel XP to Level ${level + 1}';

  /// "340 XP" total label.
  String get xpLabel => '$xp XP';
}
