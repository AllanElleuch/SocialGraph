/// Weekly quests (Stats tab gamification, WoW-style).
///
/// Three quests are offered each week. The *selection* is deterministic from
/// the Monday-anchored week, so quests rotate automatically every week with no
/// stored state — last week's unfinished quests simply disappear and a fresh
/// set takes their place. *Progress* is derived purely from the contacts'
/// activity within the current week.
///
/// The one thing that cannot be re-derived is the reward: completing a quest
/// is a *claim* (WoW turn-in) whose XP must outlive the weekly rotation. That
/// claim ledger lives outside this engine (see `QuestStore`); here we only take
/// the set of already-claimed quest keys as an input so the whole engine stays
/// pure and deterministic.
library;

import 'dart:math' as math;

import '../models/contact.dart';
import 'level.dart' show kReconnectGapDays;
import 'streaks.dart' as streaks;

/// How many quests are offered each week.
const int kQuestsPerWeek = 3;

/// Stable identifiers for every quest the app can offer.
enum QuestId {
  touchBase,
  busyBee,
  newFace,
  growthSpurt,
  ringRing,
  penPal,
  faceToFace,
  inbox,
  socialButterfly,
  rekindle,
  mixItUp,
}

/// A summary of one week's network activity, computed once and shared by every
/// quest's progress evaluator. Pure: derived from [contacts] within
/// `[weekStart, weekStart + 7 days)`.
class WeekActivity {
  /// Total interactions logged this week.
  final int interactionCount;

  /// Interactions this week broken down by type.
  final Map<InteractionType, int> byType;

  /// Distinct contacts you interacted with this week.
  final int distinctContacts;

  /// Contacts first met / imported this week.
  final int newContacts;

  /// Dormant relationships revived this week (an interaction following the
  /// previous one by more than [kReconnectGapDays]).
  final int reconnects;

  const WeekActivity({
    required this.interactionCount,
    required this.byType,
    required this.distinctContacts,
    required this.newContacts,
    required this.reconnects,
  });

  factory WeekActivity.from(
    List<Contact> contacts, {
    required DateTime weekStart,
  }) {
    final weekEnd = weekStart.add(const Duration(days: 7));
    bool inWeek(DateTime d) => !d.isBefore(weekStart) && d.isBefore(weekEnd);

    var interactionCount = 0;
    final byType = <InteractionType, int>{};
    var distinctContacts = 0;
    var newContacts = 0;
    var reconnects = 0;

    for (final c in contacts) {
      var touchedThisWeek = false;
      for (final e in c.interactions) {
        if (inWeek(e.date)) {
          interactionCount++;
          byType[e.type] = (byType[e.type] ?? 0) + 1;
          touchedThisWeek = true;
        }
      }
      if (touchedThisWeek) distinctContacts++;

      // Reconnects whose *later* interaction lands in this week.
      final dates = c.interactions.map((e) => e.date).toList()..sort();
      for (var i = 1; i < dates.length; i++) {
        if (inWeek(dates[i]) &&
            dates[i].difference(dates[i - 1]).inDays > kReconnectGapDays) {
          reconnects++;
        }
      }

      final added = c.dateMet ?? c.origin?.importedAt;
      if (added != null && inWeek(added)) newContacts++;
    }

    return WeekActivity(
      interactionCount: interactionCount,
      byType: byType,
      distinctContacts: distinctContacts,
      newContacts: newContacts,
      reconnects: reconnects,
    );
  }

  /// Interactions of a given [type] this week (0 when none).
  int countOf(InteractionType type) => byType[type] ?? 0;

  /// Number of distinct interaction types used this week.
  int get distinctTypes => byType.keys.length;
}

/// A quest definition: its goal ([target]), its [xpReward], and how to read its
/// current progress from a [WeekActivity]. Presentation (title, icon, copy)
/// lives in the view, not here.
class QuestDef {
  final QuestId id;
  final int target;
  final int xpReward;
  final int Function(WeekActivity) _progress;

  const QuestDef(this.id, this.target, this.xpReward, this._progress);

  int progressFor(WeekActivity a) => _progress(a);
}

/// The full pool quests are drawn from each week. Adding a quest is a matter of
/// an id here, an entry in this pool, and a presentation entry in the view.
final List<QuestDef> kQuestPool = [
  QuestDef(QuestId.touchBase, 3, 30, (a) => a.interactionCount),
  QuestDef(QuestId.busyBee, 6, 60, (a) => a.interactionCount),
  QuestDef(QuestId.newFace, 1, 25, (a) => a.newContacts),
  QuestDef(QuestId.growthSpurt, 2, 50, (a) => a.newContacts),
  QuestDef(QuestId.ringRing, 2, 30, (a) => a.countOf(InteractionType.call)),
  QuestDef(QuestId.penPal, 3, 30, (a) => a.countOf(InteractionType.text)),
  QuestDef(QuestId.faceToFace, 1, 35, (a) => a.countOf(InteractionType.meeting)),
  QuestDef(QuestId.inbox, 2, 25, (a) => a.countOf(InteractionType.email)),
  QuestDef(QuestId.socialButterfly, 4, 50, (a) => a.distinctContacts),
  QuestDef(QuestId.rekindle, 1, 40, (a) => a.reconnects),
  QuestDef(QuestId.mixItUp, 3, 40, (a) => a.distinctTypes),
];

/// The stable storage key for a quest claimed in a given week, e.g.
/// `2026-06-01:touchBase`.
String questKey(DateTime weekStart, QuestId id) {
  final d = weekStart;
  final iso =
      '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
  return '$iso:${id.name}';
}

/// Deterministically selects the [kQuestsPerWeek] quests for the week beginning
/// [weekStart]. The same week always yields the same quests (so they're stable
/// within the week and rotate at the weekly reset).
List<QuestDef> questsForWeek(DateTime weekStart) {
  final weekIndex =
      weekStart.difference(DateTime(1970, 1, 1)).inDays ~/ 7;
  final pool = [...kQuestPool];
  final rng = math.Random(weekIndex);
  // Seeded Fisher–Yates shuffle, then take the first N.
  for (var i = pool.length - 1; i > 0; i--) {
    final j = rng.nextInt(i + 1);
    final tmp = pool[i];
    pool[i] = pool[j];
    pool[j] = tmp;
  }
  return pool.take(kQuestsPerWeek).toList();
}

/// One quest as offered this week, with its derived progress and claim state.
class WeeklyQuest {
  final QuestDef def;
  final int current;
  final DateTime weekStart;
  final bool claimed;

  const WeeklyQuest({
    required this.def,
    required this.current,
    required this.weekStart,
    required this.claimed,
  });

  QuestId get id => def.id;
  int get target => def.target;
  int get xpReward => def.xpReward;

  /// The goal has been reached (regardless of whether the reward was claimed).
  bool get goalMet => current >= target;

  /// The reward is sitting there waiting to be collected.
  bool get isReadyToClaim => goalMet && !claimed;

  /// Progress toward the goal, 0..1.
  double get progress {
    if (target <= 0) return 1.0;
    return (current / target).clamp(0.0, 1.0);
  }

  /// "2 / 3" style label (current capped at target).
  String get progressLabel => '${current > target ? target : current} / $target';

  /// "+30 XP" reward label.
  String get rewardLabel => '+$xpReward XP';

  /// This quest's stable claim key.
  String get key => questKey(weekStart, id);
}

/// The set of quests for the current week, with progress and claim state
/// resolved against the [claimedKeys] ledger.
class WeeklyQuests {
  final List<WeeklyQuest> quests;
  final DateTime weekStart;

  const WeeklyQuests({required this.quests, required this.weekStart});

  factory WeeklyQuests.from(
    List<Contact> contacts, {
    required DateTime now,
    required Set<String> claimedKeys,
  }) {
    final ws = streaks.weekStart(now);
    final activity = WeekActivity.from(contacts, weekStart: ws);
    final quests = [
      for (final def in questsForWeek(ws))
        WeeklyQuest(
          def: def,
          current: def.progressFor(activity),
          weekStart: ws,
          claimed: claimedKeys.contains(questKey(ws, def.id)),
        ),
    ];
    return WeeklyQuests(quests: quests, weekStart: ws);
  }

  /// Quests whose reward is ready to collect.
  int get readyCount => quests.where((q) => q.isReadyToClaim).length;

  /// Quests whose goal is met (claimed or not).
  int get completedCount => quests.where((q) => q.goalMet).length;

  /// Total XP currently sitting unclaimed.
  int get claimableXp =>
      quests.where((q) => q.isReadyToClaim).fold(0, (s, q) => s + q.xpReward);

  /// "1 / 3 done" headline for the card.
  String get summaryLabel => '$completedCount / ${quests.length} done';

  /// The Monday-anchored end of the week (start of next week).
  DateTime get weekEnd => weekStart.add(const Duration(days: 7));

  /// Whole days until the weekly reset, given [now].
  int daysUntilReset(DateTime now) {
    final diff = weekEnd.difference(now).inHours / 24.0;
    return diff.ceil().clamp(0, 7);
  }

  /// "Resets in 4 days" / "Resets tomorrow" / "Resets today".
  String resetLabel(DateTime now) {
    final d = daysUntilReset(now);
    if (d <= 0) return 'Resets today';
    if (d == 1) return 'Resets tomorrow';
    return 'Resets in $d days';
  }
}
