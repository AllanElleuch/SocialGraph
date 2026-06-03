import '../models/contact.dart';
import '../services/reach_out_service.dart';
import '../services/relationship_strength.dart';
import 'achievements.dart';
import 'level.dart';
import 'streaks.dart';

/// One-stop, pure aggregate of every statistic shown on the Stats tab.
///
/// Like [strengthScore] and [reachOutStatus], this reads no clock and does no
/// I/O — the caller supplies [now]. Everything is derived from the contacts
/// themselves, so a rebuild with the same inputs always produces the same
/// numbers (no stored gamification state, no migration, syncs for free).
class NetworkStats {
  final LevelStats level;
  final StreakStats streak;
  final HealthStats health;
  final GrowthStats growth;
  final InteractionStats interactions;
  final GeographyStats geography;
  final List<AchievementStat> achievements;

  const NetworkStats({
    required this.level,
    required this.streak,
    required this.health,
    required this.growth,
    required this.interactions,
    required this.geography,
    required this.achievements,
  });

  /// Number of badges already unlocked.
  int get unlockedBadgeCount => achievements.where((a) => a.unlocked).length;

  /// "3 / 12 badges" headline for the achievements section.
  String get badgeLabel =>
      '$unlockedBadgeCount / ${achievements.length} badges';

  /// Builds the full snapshot from [contacts] as of [now].
  factory NetworkStats.from(List<Contact> contacts, {required DateTime now}) {
    // --- gather raw interaction timeline across the whole network ---
    final allInteractionDates = <DateTime>[];
    var totalInteractions = 0;
    var totalConnections = 0;
    var totalReconnects = 0;
    final byType = <InteractionType, int>{};
    final byWeekday = <int, int>{};

    for (final c in contacts) {
      totalConnections += c.connections.length;
      final dates = <DateTime>[];
      for (final e in c.interactions) {
        totalInteractions++;
        dates.add(e.date);
        allInteractionDates.add(e.date);
        byType[e.type] = (byType[e.type] ?? 0) + 1;
        byWeekday[e.date.weekday] = (byWeekday[e.date.weekday] ?? 0) + 1;
      }
      totalReconnects += reconnectCountForDates(
        dates,
        gapDays: kReconnectGapDays,
      );
    }

    final streak = StreakStats.from(allInteractionDates, now: now);

    final xp = totalXp(
      contactCount: contacts.length,
      interactionCount: totalInteractions,
      connectionCount: totalConnections,
      reconnectCount: totalReconnects,
    );

    final growth = GrowthStats.from(contacts, now: now);
    final interactions = InteractionStats.from(
      contacts,
      total: totalInteractions,
      byType: byType,
      byWeekday: byWeekday,
    );
    final geography = GeographyStats.from(contacts);
    final health = HealthStats.from(contacts, now: now);

    final strongCount = contacts
        .where((c) => strengthScore(c, now: now) >= 66)
        .length;
    final birthdayCount = contacts.where((c) => c.birthday != null).length;

    final achievements = <AchievementStat>[
      AchievementStat(
        id: AchievementId.firstContact,
        current: contacts.length,
        target: 1,
      ),
      AchievementStat(
        id: AchievementId.collectorTen,
        current: contacts.length,
        target: 10,
      ),
      AchievementStat(
        id: AchievementId.collectorFifty,
        current: contacts.length,
        target: 50,
      ),
      AchievementStat(
        id: AchievementId.chatterbox,
        current: totalInteractions,
        target: 25,
      ),
      AchievementStat(
        id: AchievementId.centuryClub,
        current: totalInteractions,
        target: 100,
      ),
      AchievementStat(
        id: AchievementId.consistentFour,
        current: streak.longestWeeks,
        target: 4,
      ),
      AchievementStat(
        id: AchievementId.consistentTwelve,
        current: streak.longestWeeks,
        target: 12,
      ),
      AchievementStat(
        id: AchievementId.explorer,
        current: geography.distinctPlaces,
        target: 10,
      ),
      AchievementStat(
        id: AchievementId.connector,
        current: totalConnections,
        target: 20,
      ),
      AchievementStat(
        id: AchievementId.reconnector,
        current: totalReconnects,
        target: 5,
      ),
      AchievementStat(
        id: AchievementId.wellTended,
        current: strongCount,
        target: 10,
      ),
      AchievementStat(
        id: AchievementId.birthdayKnower,
        current: birthdayCount,
        target: 10,
      ),
    ];

    return NetworkStats(
      level: LevelStats.fromXp(xp),
      streak: streak,
      health: health,
      growth: growth,
      interactions: interactions,
      geography: geography,
      achievements: achievements,
    );
  }
}

/// Network-health snapshot built from each contact's reach-out cadence.
class HealthStats {
  final int onTrackCount;
  final int overdueCount;

  /// Contacts whose reminders are off / have no cadence basis.
  final int untrackedCount;

  /// The most-overdue contact, if any, and how many days overdue it is.
  final Contact? mostNeglected;
  final int mostNeglectedDays;

  /// Contacts whose birthday falls within the next 30 days, soonest first.
  final List<UpcomingBirthday> upcomingBirthdays;

  const HealthStats({
    required this.onTrackCount,
    required this.overdueCount,
    required this.untrackedCount,
    required this.mostNeglected,
    required this.mostNeglectedDays,
    required this.upcomingBirthdays,
  });

  factory HealthStats.from(List<Contact> contacts, {required DateTime now}) {
    var onTrack = 0;
    var overdue = 0;
    var untracked = 0;

    for (final c in contacts) {
      final status = reachOutStatus(c, now: now);
      if (status.dueInDays == kReachOutOffDueInDays) {
        untracked++;
      } else if (status.isOverdue) {
        overdue++;
      } else {
        onTrack++;
      }
    }

    final overdueList = overdueContacts(contacts, now: now);
    Contact? worst;
    var worstDays = 0;
    if (overdueList.isNotEmpty) {
      worst = overdueList.first;
      final s = reachOutStatus(worst, now: now);
      worstDays = s.dueInDays < 0 ? -s.dueInDays : 0;
    }

    final birthdays = <UpcomingBirthday>[];
    for (final c in contacts) {
      final b = c.birthday;
      if (b == null) continue;
      final days = _daysUntilNextBirthday(b, now);
      if (days <= 30) birthdays.add(UpcomingBirthday(contact: c, inDays: days));
    }
    birthdays.sort((a, b) => a.inDays.compareTo(b.inDays));

    return HealthStats(
      onTrackCount: onTrack,
      overdueCount: overdue,
      untrackedCount: untracked,
      mostNeglected: worst,
      mostNeglectedDays: worstDays,
      upcomingBirthdays: birthdays,
    );
  }

  /// Total contacts with an active cadence (the denominator for the score).
  int get trackedCount => onTrackCount + overdueCount;

  /// Overall health 0..100 = share of tracked contacts that are on track.
  /// Null when no contact has an active cadence (nothing to score yet).
  int? get score {
    if (trackedCount == 0) return null;
    return ((onTrackCount / trackedCount) * 100).round();
  }

  /// "82%" or "--" when nothing is tracked.
  String get scoreLabel => score == null ? '--' : '$score%';

  /// Progress 0..1 for the health ring (0 when untracked).
  double get scoreFraction => score == null ? 0.0 : score! / 100.0;

  /// "12 on track · 3 overdue" summary line.
  String get summaryLabel => '$onTrackCount on track · $overdueCount overdue';

  static int _daysUntilNextBirthday(DateTime birthday, DateTime now) {
    final today = DateTime(now.year, now.month, now.day);
    var next = DateTime(today.year, birthday.month, birthday.day);
    if (next.isBefore(today)) {
      next = DateTime(today.year + 1, birthday.month, birthday.day);
    }
    return next.difference(today).inDays;
  }
}

/// An upcoming birthday entry.
class UpcomingBirthday {
  final Contact contact;
  final int inDays;

  const UpcomingBirthday({required this.contact, required this.inDays});

  /// "Today!", "Tomorrow", or "in 9 days".
  String get whenLabel {
    if (inDays == 0) return 'Today!';
    if (inDays == 1) return 'Tomorrow';
    return 'in $inDays days';
  }
}

/// Network-growth snapshot derived from when each contact was met/imported.
class GrowthStats {
  final int total;
  final int manualCount;
  final int importedCount;

  /// Contacts added in each of the last 12 months, oldest-first (length 12).
  final List<int> last12Months;

  /// Label of the busiest month for new contacts, e.g. "Mar 2026".
  final String? busiestMonthLabel;
  final int busiestMonthCount;

  const GrowthStats({
    required this.total,
    required this.manualCount,
    required this.importedCount,
    required this.last12Months,
    required this.busiestMonthLabel,
    required this.busiestMonthCount,
  });

  factory GrowthStats.from(List<Contact> contacts, {required DateTime now}) {
    var manual = 0;
    var imported = 0;
    final monthCounts = <String, int>{};
    final addedDates = <DateTime>[];

    for (final c in contacts) {
      if (c.origin?.isImported == true) {
        imported++;
      } else {
        manual++;
      }
      final added = c.dateMet ?? c.origin?.importedAt;
      if (added != null) {
        addedDates.add(added);
        final key = _monthKey(added);
        monthCounts[key] = (monthCounts[key] ?? 0) + 1;
      }
    }

    // Last 12 calendar months, oldest-first.
    final last12 = <int>[];
    for (var i = 11; i >= 0; i--) {
      final m = DateTime(now.year, now.month - i, 1);
      last12.add(monthCounts[_monthKey(m)] ?? 0);
    }

    String? busiestLabel;
    var busiestCount = 0;
    monthCounts.forEach((key, count) {
      if (count > busiestCount) {
        busiestCount = count;
        busiestLabel = _labelFromKey(key);
      }
    });

    return GrowthStats(
      total: contacts.length,
      manualCount: manual,
      importedCount: imported,
      last12Months: last12,
      busiestMonthLabel: busiestLabel,
      busiestMonthCount: busiestCount,
    );
  }

  /// "5 added · 2 imported" composition line.
  String get compositionLabel => '$manualCount added · $importedCount imported';

  static const List<String> _months = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', //
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
  ];

  static String _monthKey(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}';

  static String _labelFromKey(String key) {
    final parts = key.split('-');
    final year = parts[0];
    final month = int.parse(parts[1]);
    return '${_months[month - 1]} $year';
  }
}

/// Interaction-pattern snapshot.
class InteractionStats {
  final int total;
  final Map<InteractionType, int> byType;
  final Contact? mostContacted;
  final int mostContactedCount;
  final int? mostActiveWeekday; // 1=Mon … 7=Sun
  final int mostActiveWeekdayCount;

  const InteractionStats({
    required this.total,
    required this.byType,
    required this.mostContacted,
    required this.mostContactedCount,
    required this.mostActiveWeekday,
    required this.mostActiveWeekdayCount,
  });

  factory InteractionStats.from(
    List<Contact> contacts, {
    required int total,
    required Map<InteractionType, int> byType,
    required Map<int, int> byWeekday,
  }) {
    Contact? top;
    var topCount = 0;
    for (final c in contacts) {
      if (c.interactions.length > topCount) {
        topCount = c.interactions.length;
        top = c;
      }
    }

    int? bestDay;
    var bestDayCount = 0;
    byWeekday.forEach((day, count) {
      if (count > bestDayCount) {
        bestDayCount = count;
        bestDay = day;
      }
    });

    return InteractionStats(
      total: total,
      byType: byType,
      mostContacted: topCount > 0 ? top : null,
      mostContactedCount: topCount,
      mostActiveWeekday: bestDay,
      mostActiveWeekdayCount: bestDayCount,
    );
  }

  static const List<String> _weekdays = [
    'Monday', 'Tuesday', 'Wednesday', 'Thursday', //
    'Friday', 'Saturday', 'Sunday',
  ];

  /// "Friday" or "--" when there is no activity.
  String get mostActiveWeekdayLabel =>
      mostActiveWeekday == null ? '--' : _weekdays[mostActiveWeekday! - 1];

  /// Count for a given interaction [type] (0 when none).
  int countOf(InteractionType type) => byType[type] ?? 0;
}

/// Geography & diversity snapshot.
class GeographyStats {
  final int distinctPlaces;
  final int withLocationCount;

  /// Places you met people, most-frequent first.
  final List<PlaceCount> topPlaces;

  /// Tag usage, most-frequent first.
  final List<TagCount> topTags;

  const GeographyStats({
    required this.distinctPlaces,
    required this.withLocationCount,
    required this.topPlaces,
    required this.topTags,
  });

  factory GeographyStats.from(List<Contact> contacts) {
    final placeCounts = <String, int>{};
    final tagCounts = <String, int>{};
    var withLocation = 0;

    for (final c in contacts) {
      final place = c.locationMet.trim();
      if (place.isNotEmpty) {
        withLocation++;
        placeCounts[place] = (placeCounts[place] ?? 0) + 1;
      }
      for (final t in c.tags) {
        final tag = t.trim();
        if (tag.isNotEmpty) tagCounts[tag] = (tagCounts[tag] ?? 0) + 1;
      }
    }

    final places =
        placeCounts.entries
            .map((e) => PlaceCount(place: e.key, count: e.value))
            .toList()
          ..sort((a, b) => b.count.compareTo(a.count));
    final tags =
        tagCounts.entries
            .map((e) => TagCount(tag: e.key, count: e.value))
            .toList()
          ..sort((a, b) => b.count.compareTo(a.count));

    return GeographyStats(
      distinctPlaces: placeCounts.length,
      withLocationCount: withLocation,
      topPlaces: places,
      topTags: tags,
    );
  }
}

/// A place you met contacts and how many you met there.
class PlaceCount {
  final String place;
  final int count;
  const PlaceCount({required this.place, required this.count});
}

/// A tag and how many contacts carry it.
class TagCount {
  final String tag;
  final int count;
  const TagCount({required this.tag, required this.count});
}
