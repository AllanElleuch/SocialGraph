import 'dart:math' as math;

import 'level_requirements.dart';

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

/// The named progression ladder, level 1..10 (index 0 == level 1). Level 10 is
/// the apex; beyond it, players earn prestige tiers (see [rankTitleForLevel]).
const List<String> kLevelTitles = [
  'Newcomer',
  'Acquaintance',
  'Friendly Face',
  'Networker',
  'Connector',
  'Super Connector',
  'Networking Pro',
  'Relationship Master',
  'Social Architect',
  'Networking Legend',
];

/// Highest named level; XP past this earns prestige tiers instead of new names.
const int kMaxNamedLevel = 10;

/// A flavourful rank title for a given [level].
///
/// Levels 1..10 map to [kLevelTitles]. Past 10, the title stays "Networking
/// Legend" with a prestige roman numeral appended — "Networking Legend II" at
/// level 11, "III" at 12, and so on — so there is always a next goal.
String rankTitleForLevel(int level) {
  if (level <= 1) return kLevelTitles.first;
  if (level <= kMaxNamedLevel) return kLevelTitles[level - 1];
  return '${kLevelTitles.last} ${_roman(level - kMaxNamedLevel + 1)}';
}

const List<(int, String)> _romanUnits = [
  (1000, 'M'), (900, 'CM'), (500, 'D'), (400, 'CD'), //
  (100, 'C'), (90, 'XC'), (50, 'L'), (40, 'XL'), //
  (10, 'X'), (9, 'IX'), (5, 'V'), (4, 'IV'), (1, 'I'),
];

/// Compact roman numeral for prestige tiers (e.g. 2 -> "II", 14 -> "XIV").
String _roman(int n) {
  if (n <= 0) return '';
  final sb = StringBuffer();
  var value = n;
  for (final (amount, symbol) in _romanUnits) {
    while (value >= amount) {
      sb.write(symbol);
      value -= amount;
    }
  }
  return sb.toString();
}

/// The level actually reached when each rung is gated by **both** its XP
/// threshold and its hard [LevelRequirement].
///
/// Progression is sequential and contiguous: you advance to level L only when,
/// for every rung up to L, the XP threshold is reached *and* that rung's
/// requirement is met. The first rung that fails either condition caps you.
/// Past the apex ([kMaxNamedLevel]) there are no hard requirements, so prestige
/// tiers advance on XP alone.
int gatedLevel(int xp, Map<int, LevelRequirement> requirements) {
  var level = 1;
  for (var l = 2; l <= kMaxNamedLevel; l++) {
    final xpOk = xp >= xpForLevel(l);
    final req = requirements[l];
    final reqOk = req == null || req.met;
    if (xpOk && reqOk) {
      level = l;
    } else {
      return level; // blocked here; nothing above can unlock
    }
  }
  // At the apex: prestige tiers are XP-only.
  final byXp = levelForXp(xp);
  return byXp > level ? byXp : level;
}

/// Immutable snapshot of the player's level/XP standing.
class LevelStats {
  final int xp;
  final int level;

  /// Hard requirements by level (2..10), when this standing was computed with
  /// gating. Null for XP-only standings (e.g. [LevelStats.fromXp]).
  final Map<int, LevelRequirement>? requirements;

  const LevelStats({required this.xp, required this.level, this.requirements});

  /// Builds a pure XP standing (no hard-requirement gating).
  factory LevelStats.fromXp(int xp) =>
      LevelStats(xp: xp, level: levelForXp(xp));

  /// Builds a gated standing: the level is capped by both XP and the hard
  /// [requirements] (see [gatedLevel]).
  factory LevelStats.gated({
    required int xp,
    required Map<int, LevelRequirement> requirements,
  }) => LevelStats(
    xp: xp,
    level: gatedLevel(xp, requirements),
    requirements: requirements,
  );

  /// The hard requirement guarding the *next* level, if any (null at the apex
  /// or for ungated standings).
  LevelRequirement? get nextRequirement => requirements?[level + 1];

  /// Whether the next level's XP is already earned but its hard requirement is
  /// still unmet — i.e. a requirement (not XP) is what's holding you back.
  bool get blockedByRequirement {
    final req = nextRequirement;
    return req != null && !req.met && xp >= xpAtNextLevel;
  }

  /// XP threshold at the start of the current level.
  int get xpAtLevelStart => xpForLevel(level);

  /// XP threshold at the start of the next level.
  int get xpAtNextLevel => xpForLevel(level + 1);

  /// XP accumulated since the current level began.
  int get xpIntoLevel => xp - xpAtLevelStart;

  /// Total XP span of the current level.
  int get xpSpanThisLevel => xpAtNextLevel - xpAtLevelStart;

  /// XP still needed to reach the next level (never negative — when gated by a
  /// requirement the XP can already be past the band).
  int get xpToNextLevel {
    final gap = xpAtNextLevel - xp;
    return gap < 0 ? 0 : gap;
  }

  /// Progress through the current level, 0..1.
  double get progress {
    final span = xpSpanThisLevel;
    if (span <= 0) return 0.0;
    return (xpIntoLevel / span).clamp(0.0, 1.0);
  }

  /// Flavour rank title, e.g. "Connector" or "Networking Legend II".
  String get rankTitle => rankTitleForLevel(level);

  /// Prestige tier earned past the apex: 0 at level ≤ 10, 1 at level 11
  /// ("Legend II"), 2 at level 12, and so on. Drives the prestige banner.
  int get prestige => level <= kMaxNamedLevel ? 0 : level - kMaxNamedLevel;

  /// Whether the player has reached the apex named level (10+).
  bool get isLegend => level >= kMaxNamedLevel;

  /// "Level 4" headline.
  String get levelLabel => 'Level $level';

  /// "120 XP to Level 5" hint under the progress bar — or, when XP is already
  /// earned and a hard requirement is the blocker, surfaces that instead.
  String get nextLevelLabel {
    final req = nextRequirement;
    if (req != null && !req.met && xp >= xpAtNextLevel) {
      return 'Need: ${req.label} (${req.progressLabel})';
    }
    return '$xpToNextLevel XP to Level ${level + 1}';
  }

  /// "340 XP" total label.
  String get xpLabel => '$xp XP';

  /// "286 / 500 XP" — XP earned into the current level over the XP the level
  /// spans, so the progress bar's fill is quantified. Falls back to the total
  /// XP label if the level span is degenerate.
  String get xpRatioLabel {
    final span = xpSpanThisLevel;
    if (span <= 0) return xpLabel;
    return '$xpIntoLevel / $span XP';
  }

  /// "57%" — how far through the current level (matches the progress bar).
  String get progressPercentLabel => '${(progress * 100).round()}%';
}
