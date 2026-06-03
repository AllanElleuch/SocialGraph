/// Weekly reach-out streaks (Stats tab gamification).
///
/// Pure, deterministic: streaks are computed from the set of weeks in which at
/// least one interaction was logged across the whole network. Weekly (rather
/// than daily) granularity keeps the streak forgiving — a relationship app
/// shouldn't punish you for missing a single day.
///
/// A "week" is the Monday-anchored 7-day window containing a date. The caller
/// supplies `now` so the result is fully deterministic.
library;

/// Returns the date-only Monday that starts the week containing [date].
DateTime weekStart(DateTime date) {
  final d = DateTime(date.year, date.month, date.day);
  // DateTime.weekday: Monday = 1 … Sunday = 7.
  return d.subtract(Duration(days: d.weekday - 1));
}

/// Immutable snapshot of weekly reach-out streaks.
class StreakStats {
  /// Number of consecutive active weeks ending at the current (or, as a grace,
  /// the immediately previous) week.
  final int currentWeeks;

  /// Longest run of consecutive active weeks ever recorded.
  final int longestWeeks;

  /// Most-recent-first activity for the last 12 weeks (index 0 = this week).
  /// Used to render the "don't break the chain" calendar.
  final List<bool> last12Weeks;

  const StreakStats({
    required this.currentWeeks,
    required this.longestWeeks,
    required this.last12Weeks,
  });

  /// Builds streak stats from interaction [dates] (any order) as of [now].
  factory StreakStats.from(Iterable<DateTime> dates, {required DateTime now}) {
    final active = <DateTime>{for (final d in dates) weekStart(d)};
    final thisWeek = weekStart(now);

    final current = _currentRun(active, thisWeek);
    final longest = _longestRun(active);
    final last12 = <bool>[
      for (var i = 0; i < 12; i++)
        active.contains(thisWeek.subtract(Duration(days: 7 * i))),
    ];

    return StreakStats(
      currentWeeks: current,
      longestWeeks: longest,
      last12Weeks: last12,
    );
  }

  /// Counts consecutive active weeks ending at [thisWeek]. A one-week grace is
  /// allowed: if this week has no activity yet but last week did, the streak is
  /// still considered alive and counted from last week.
  static int _currentRun(Set<DateTime> active, DateTime thisWeek) {
    DateTime? cursor;
    if (active.contains(thisWeek)) {
      cursor = thisWeek;
    } else {
      final lastWeek = thisWeek.subtract(const Duration(days: 7));
      if (active.contains(lastWeek)) cursor = lastWeek;
    }
    if (cursor == null) return 0;

    var count = 0;
    while (active.contains(cursor)) {
      count++;
      cursor = cursor!.subtract(const Duration(days: 7));
    }
    return count;
  }

  /// Longest run of consecutive active weeks across all recorded activity.
  static int _longestRun(Set<DateTime> active) {
    if (active.isEmpty) return 0;
    final sorted = active.toList()..sort();
    var longest = 1;
    var run = 1;
    for (var i = 1; i < sorted.length; i++) {
      final gapDays = sorted[i].difference(sorted[i - 1]).inDays;
      if (gapDays == 7) {
        run++;
        if (run > longest) longest = run;
      } else {
        run = 1;
      }
    }
    return longest;
  }

  bool get isActive => currentWeeks > 0;

  /// "5 weeks" headline (singular/plural aware).
  String get currentLabel =>
      '$currentWeeks ${currentWeeks == 1 ? 'week' : 'weeks'}';

  /// "Best: 8 weeks" subtitle.
  String get longestLabel =>
      'Best: $longestWeeks ${longestWeeks == 1 ? 'week' : 'weeks'}';
}

/// Counts how many interactions in [dates] (across one contact, any order)
/// reconnect a dormant relationship — i.e. follow the previous interaction by
/// more than [gapDays] days. Used for XP and the "Reconnector" badge.
int reconnectCountForDates(List<DateTime> dates, {required int gapDays}) {
  if (dates.length < 2) return 0;
  final sorted = [...dates]..sort();
  var count = 0;
  for (var i = 1; i < sorted.length; i++) {
    if (sorted[i].difference(sorted[i - 1]).inDays > gapDays) count++;
  }
  return count;
}
