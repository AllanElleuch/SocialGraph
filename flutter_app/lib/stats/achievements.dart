/// Achievement / badge catalogue (Stats tab gamification).
///
/// Pure, deterministic and presentation-free: the engine only knows each
/// badge's *progress* (current vs. target). The Stats view maps each
/// [AchievementId] to a title, description and icon. Adding a badge is a matter
/// of adding an id here and an entry in [NetworkStats]'s evaluation plus the
/// view's presentation map.
library;

/// Stable identifiers for every badge the app can award.
enum AchievementId {
  firstContact,
  collectorTen,
  collectorFifty,
  chatterbox,
  centuryClub,
  consistentFour,
  consistentTwelve,
  explorer,
  connector,
  reconnector,
  wellTended,
  birthdayKnower,
}

/// Progress toward a single badge.
///
/// [current] is clamped display-side against [target]; [unlocked] is true once
/// [current] reaches [target].
class AchievementStat {
  final AchievementId id;
  final int current;
  final int target;

  const AchievementStat({
    required this.id,
    required this.current,
    required this.target,
  });

  bool get unlocked => current >= target;

  /// Progress toward the target, 0..1.
  double get progress {
    if (target <= 0) return 1.0;
    return (current / target).clamp(0.0, 1.0);
  }

  /// "7 / 10" style progress label (current capped at target).
  String get progressLabel =>
      '${current > target ? target : current} / $target';
}
