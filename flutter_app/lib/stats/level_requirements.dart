/// Hard, concrete requirements that gate each level — alongside the XP
/// threshold. To *pass* a level you need both enough XP and that level's
/// requirement met (see `gatedLevel` in `level.dart`).
///
/// Pure data, no imports: the values come from the network's already-computed
/// metrics, so this file has no dependency on the level/XP math (keeping the
/// import graph acyclic).
library;

/// A single hard requirement for a level, with live progress.
class LevelRequirement {
  /// The level this requirement unlocks (2..10).
  final int level;

  /// Human description, e.g. "Add 3 contacts".
  final String label;

  /// Current value of the underlying metric.
  final int current;

  /// Value needed to satisfy the requirement.
  final int target;

  const LevelRequirement({
    required this.level,
    required this.label,
    required this.current,
    required this.target,
  });

  bool get met => current >= target;

  /// Progress toward [target], 0..1.
  double get progress => target <= 0 ? 1.0 : (current / target).clamp(0.0, 1.0);

  /// "7 / 10" (current capped at target).
  String get progressLabel =>
      '${current > target ? target : current} / $target';
}

/// The network metrics the requirements are evaluated against. Built by
/// `NetworkStats.from` from data it already computes.
class LevelMetrics {
  final int contacts;
  final int interactions;
  final int connections;
  final int distinctPlaces;
  final int reconnects;
  final int strongRelationships;

  const LevelMetrics({
    required this.contacts,
    required this.interactions,
    required this.connections,
    required this.distinctPlaces,
    required this.reconnects,
    required this.strongRelationships,
  });
}

/// Builds the hard requirement for every gated level (2..10) from [m].
///
/// The ladder deliberately mixes *what* it asks for — breadth (contacts),
/// activity (interactions), reach (places, connections), and depth (reconnects,
/// strong ties) — so leveling rewards a well-rounded network, not just grinding
/// one number.
Map<int, LevelRequirement> buildLevelRequirements(LevelMetrics m) => {
  2: LevelRequirement(
    level: 2,
    label: 'Add 3 contacts',
    current: m.contacts,
    target: 3,
  ),
  3: LevelRequirement(
    level: 3,
    label: 'Log 5 interactions',
    current: m.interactions,
    target: 5,
  ),
  4: LevelRequirement(
    level: 4,
    label: 'Grow to 10 contacts',
    current: m.contacts,
    target: 10,
  ),
  5: LevelRequirement(
    level: 5,
    label: 'Log 25 interactions',
    current: m.interactions,
    target: 25,
  ),
  6: LevelRequirement(
    level: 6,
    label: 'Meet people in 3 places',
    current: m.distinctPlaces,
    target: 3,
  ),
  7: LevelRequirement(
    level: 7,
    label: 'Map 10 connections',
    current: m.connections,
    target: 10,
  ),
  8: LevelRequirement(
    level: 8,
    label: 'Revive 5 dormant ties',
    current: m.reconnects,
    target: 5,
  ),
  9: LevelRequirement(
    level: 9,
    label: 'Build 10 strong relationships',
    current: m.strongRelationships,
    target: 10,
  ),
  10: LevelRequirement(
    level: 10,
    label: 'Reach 50 contacts',
    current: m.contacts,
    target: 50,
  ),
};
