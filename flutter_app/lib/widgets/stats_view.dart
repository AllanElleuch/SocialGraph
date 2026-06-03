import 'package:flutter/material.dart';

import '../models/contact.dart';
import '../painters/stats_painters.dart';
import '../stats/achievements.dart';
import '../stats/network_stats.dart';
import '../stats/streaks.dart';

/// Dark-theme palette for the Stats surface, matching the rest of the app.
class _P {
  static const bg = Color(0xFF1A1A1A);
  static const card = Color(0xFF111111);
  static const border = Color(0xFF333333);
  static const indigo = Color(0xFF6366F1);
  static const accent = Color(0xFF818CF8);
  static const amber = Color(0xFFF59E0B);
  static const green = Color(0xFF34D399);
  static const red = Color(0xFFEF4444);
  static const text = Color(0xFFE2E8F0);
  static const muted = Color(0xFF9CA3AF);
  static const faint = Color(0xFF1F1F1F);
}

/// A playful, motivating statistics + gamification dashboard for the network.
///
/// Pure/testable: the caller injects [now]; this widget never reads the system
/// clock. All numbers come from [NetworkStats.from], derived entirely from
/// [contacts]. Tapping a contact-referencing stat calls [onSelectContact].
class StatsView extends StatelessWidget {
  final List<Contact> contacts;
  final DateTime now;
  final void Function(Contact) onSelectContact;

  const StatsView({
    super.key,
    required this.contacts,
    required this.now,
    required this.onSelectContact,
  });

  @override
  Widget build(BuildContext context) {
    final stats = NetworkStats.from(contacts, now: now);

    if (contacts.isEmpty) {
      return const _EmptyState();
    }

    return Container(
      color: _P.bg,
      child: ListView(
        // Top inset clears the floating header; bottom clears the controls bar.
        padding: const EdgeInsets.fromLTRB(16, 100, 16, 140),
        children: [
          const _ScreenTitle(),
          const SizedBox(height: 16),
          _HeroCard(stats: stats),
          const SizedBox(height: 12),
          _StreakCard(streak: stats.streak),
          const SizedBox(height: 12),
          _HealthCard(health: stats.health, onSelectContact: onSelectContact),
          const SizedBox(height: 12),
          _BadgesCard(
            achievements: stats.achievements,
            label: stats.badgeLabel,
          ),
          const SizedBox(height: 12),
          _GrowthCard(growth: stats.growth),
          const SizedBox(height: 12),
          _InteractionsCard(
            stats: stats.interactions,
            onSelectContact: onSelectContact,
          ),
          const SizedBox(height: 12),
          _GeographyCard(geo: stats.geography),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────
// Shared building blocks
// ─────────────────────────────────────────────────────────────────────────

class _ScreenTitle extends StatelessWidget {
  const _ScreenTitle();

  @override
  Widget build(BuildContext context) {
    return Row(
      children: const [
        Icon(Icons.emoji_events_outlined, color: _P.amber, size: 24),
        SizedBox(width: 10),
        Text(
          'Your network at a glance',
          style: TextStyle(
            color: _P.text,
            fontSize: 20,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }
}

class _Card extends StatelessWidget {
  final String title;
  final IconData icon;
  final Color iconColor;
  final Widget child;
  final Widget? trailing;

  const _Card({
    required this.title,
    required this.icon,
    required this.iconColor,
    required this.child,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _P.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _P.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: iconColor, size: 18),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    color: _P.text,
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              if (trailing != null) trailing!,
            ],
          ),
          const SizedBox(height: 14),
          child,
        ],
      ),
    );
  }
}

/// A small "pill" used for trailing counts in card headers.
class _Pill extends StatelessWidget {
  final String text;
  final Color color;
  const _Pill(this.text, {this.color = _P.muted});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(100),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: color,
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

/// A labelled horizontal bar (value relative to [max]).
class _BarRow extends StatelessWidget {
  final String label;
  final int value;
  final int max;
  final Color color;

  const _BarRow({
    required this.label,
    required this.value,
    required this.max,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final fraction = max <= 0 ? 0.0 : (value / max).clamp(0.0, 1.0);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          SizedBox(
            width: 78,
            child: Text(
              label,
              style: const TextStyle(color: _P.muted, fontSize: 13),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(100),
              child: LinearProgressIndicator(
                value: fraction,
                minHeight: 8,
                backgroundColor: _P.faint,
                valueColor: AlwaysStoppedAnimation<Color>(color),
              ),
            ),
          ),
          const SizedBox(width: 10),
          SizedBox(
            width: 28,
            child: Text(
              '$value',
              textAlign: TextAlign.right,
              style: const TextStyle(
                color: _P.text,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────
// Hero — level / XP / streak
// ─────────────────────────────────────────────────────────────────────────

class _HeroCard extends StatelessWidget {
  final NetworkStats stats;
  const _HeroCard({required this.stats});

  @override
  Widget build(BuildContext context) {
    final level = stats.level;
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF312E81), Color(0xFF1E1B4B)],
        ),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: _P.indigo.withValues(alpha: 0.4)),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 78,
            height: 78,
            child: Stack(
              alignment: Alignment.center,
              children: [
                CustomPaint(
                  size: const Size(78, 78),
                  painter: RingPainter(
                    progress: level.progress,
                    color: _P.amber,
                    trackColor: Colors.white.withValues(alpha: 0.15),
                    strokeWidth: 7,
                  ),
                ),
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text(
                      'LVL',
                      style: TextStyle(
                        color: _P.muted,
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 1,
                      ),
                    ),
                    Text(
                      '${level.level}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 26,
                        fontWeight: FontWeight.w800,
                        height: 1,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 18),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  level.rankTitle,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  level.xpLabel,
                  style: const TextStyle(color: _P.accent, fontSize: 13),
                ),
                const SizedBox(height: 10),
                ClipRRect(
                  borderRadius: BorderRadius.circular(100),
                  child: LinearProgressIndicator(
                    value: level.progress,
                    minHeight: 6,
                    backgroundColor: Colors.white.withValues(alpha: 0.12),
                    valueColor: const AlwaysStoppedAnimation<Color>(_P.amber),
                  ),
                ),
                const SizedBox(height: 6),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      level.nextLevelLabel,
                      style: const TextStyle(color: _P.muted, fontSize: 11),
                    ),
                    _StreakBadge(weeks: stats.streak.currentWeeks),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _StreakBadge extends StatelessWidget {
  final int weeks;
  const _StreakBadge({required this.weeks});

  @override
  Widget build(BuildContext context) {
    final active = weeks > 0;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          Icons.local_fire_department,
          size: 14,
          color: active ? _P.amber : _P.muted,
        ),
        const SizedBox(width: 3),
        Text(
          '$weeks wk',
          style: TextStyle(
            color: active ? _P.amber : _P.muted,
            fontSize: 11,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────
// Streak — weekly "don't break the chain"
// ─────────────────────────────────────────────────────────────────────────

class _StreakCard extends StatelessWidget {
  final StreakStats streak;
  const _StreakCard({required this.streak});

  @override
  Widget build(BuildContext context) {
    final weeks = streak.last12Weeks.reversed.toList();
    return _Card(
      title: 'Reach-out streak',
      icon: Icons.local_fire_department,
      iconColor: _P.amber,
      trailing: _Pill(
        streak.currentLabel,
        color: streak.isActive ? _P.amber : _P.muted,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              for (final active in weeks)
                Expanded(
                  child: Container(
                    height: 26,
                    margin: const EdgeInsets.symmetric(horizontal: 2),
                    decoration: BoxDecoration(
                      color: active
                          ? _P.amber.withValues(alpha: 0.85)
                          : _P.faint,
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(
                        color: active ? _P.amber : _P.border,
                        width: 1,
                      ),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                '12 weeks ago',
                style: TextStyle(color: _P.muted, fontSize: 11),
              ),
              Text(
                streak.longestLabel,
                style: const TextStyle(color: _P.muted, fontSize: 11),
              ),
              const Text(
                'This week',
                style: TextStyle(color: _P.muted, fontSize: 11),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────
// Health
// ─────────────────────────────────────────────────────────────────────────

class _HealthCard extends StatelessWidget {
  final HealthStats health;
  final void Function(Contact) onSelectContact;
  const _HealthCard({required this.health, required this.onSelectContact});

  @override
  Widget build(BuildContext context) {
    final score = health.score;
    final ringColor = score == null
        ? _P.muted
        : score >= 75
        ? _P.green
        : score >= 40
        ? _P.amber
        : _P.red;

    return _Card(
      title: 'Network health',
      icon: Icons.favorite_outline,
      iconColor: _P.green,
      child: Column(
        children: [
          Row(
            children: [
              SizedBox(
                width: 72,
                height: 72,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    CustomPaint(
                      size: const Size(72, 72),
                      painter: RingPainter(
                        progress: health.scoreFraction,
                        color: ringColor,
                        trackColor: _P.faint,
                        strokeWidth: 7,
                      ),
                    ),
                    Text(
                      health.scoreLabel,
                      style: TextStyle(
                        color: ringColor,
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 18),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      health.summaryLabel,
                      style: const TextStyle(
                        color: _P.text,
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      health.untrackedCount > 0
                          ? '${health.untrackedCount} without a cadence'
                          : 'Everyone has a reach-out cadence',
                      style: const TextStyle(color: _P.muted, fontSize: 12),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (health.mostNeglected != null) ...[
            const SizedBox(height: 14),
            _TappableRow(
              icon: Icons.warning_amber_rounded,
              iconColor: _P.red,
              title: health.mostNeglected!.displayName,
              subtitle:
                  'Most neglected · ${health.mostNeglectedDays} days overdue',
              onTap: () => onSelectContact(health.mostNeglected!),
            ),
          ],
          if (health.upcomingBirthdays.isNotEmpty) ...[
            const SizedBox(height: 8),
            for (final b in health.upcomingBirthdays.take(3))
              _TappableRow(
                icon: Icons.cake_outlined,
                iconColor: _P.accent,
                title: b.contact.displayName,
                subtitle: 'Birthday ${b.whenLabel}',
                onTap: () => onSelectContact(b.contact),
              ),
          ],
        ],
      ),
    );
  }
}

class _TappableRow extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _TappableRow({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
        child: Row(
          children: [
            Icon(icon, color: iconColor, size: 18),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      color: _P.text,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: const TextStyle(color: _P.muted, fontSize: 12),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, color: _P.muted, size: 18),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────
// Badges
// ─────────────────────────────────────────────────────────────────────────

class _BadgesCard extends StatelessWidget {
  final List<AchievementStat> achievements;
  final String label;
  const _BadgesCard({required this.achievements, required this.label});

  @override
  Widget build(BuildContext context) {
    return _Card(
      title: 'Badges',
      icon: Icons.workspace_premium_outlined,
      iconColor: _P.amber,
      trailing: _Pill(label, color: _P.amber),
      child: Wrap(
        spacing: 10,
        runSpacing: 10,
        children: [for (final a in achievements) _BadgeChip(stat: a)],
      ),
    );
  }
}

class _BadgeChip extends StatelessWidget {
  final AchievementStat stat;
  const _BadgeChip({required this.stat});

  @override
  Widget build(BuildContext context) {
    final meta = _badgeMeta[stat.id]!;
    final unlocked = stat.unlocked;
    return Tooltip(
      message:
          '${meta.title}\n${meta.description}'
          '${unlocked ? '' : '\n${stat.progressLabel}'}',
      child: Container(
        width: 92,
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 6),
        decoration: BoxDecoration(
          color: unlocked ? _P.amber.withValues(alpha: 0.10) : _P.faint,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: unlocked ? _P.amber.withValues(alpha: 0.5) : _P.border,
          ),
        ),
        child: Column(
          children: [
            Icon(meta.icon, size: 26, color: unlocked ? _P.amber : _P.muted),
            const SizedBox(height: 6),
            Text(
              meta.title,
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: unlocked ? _P.text : _P.muted,
                fontSize: 11,
                fontWeight: FontWeight.w600,
                height: 1.1,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              unlocked ? 'Unlocked' : stat.progressLabel,
              style: TextStyle(
                color: unlocked ? _P.amber : _P.muted,
                fontSize: 10,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Presentation metadata for a badge (icon + copy live in the view, not the
/// pure engine).
class _BadgeMeta {
  final IconData icon;
  final String title;
  final String description;
  const _BadgeMeta(this.icon, this.title, this.description);
}

const Map<AchievementId, _BadgeMeta> _badgeMeta = {
  AchievementId.firstContact: _BadgeMeta(
    Icons.person_add_alt,
    'First Contact',
    'Add your first contact',
  ),
  AchievementId.collectorTen: _BadgeMeta(
    Icons.groups_outlined,
    'Collector',
    'Reach 10 contacts',
  ),
  AchievementId.collectorFifty: _BadgeMeta(
    Icons.diversity_3,
    'Super Collector',
    'Reach 50 contacts',
  ),
  AchievementId.chatterbox: _BadgeMeta(
    Icons.chat_bubble_outline,
    'Chatterbox',
    'Log 25 interactions',
  ),
  AchievementId.centuryClub: _BadgeMeta(
    Icons.bolt,
    'Century Club',
    'Log 100 interactions',
  ),
  AchievementId.consistentFour: _BadgeMeta(
    Icons.local_fire_department,
    'On a Roll',
    '4-week streak',
  ),
  AchievementId.consistentTwelve: _BadgeMeta(
    Icons.whatshot,
    'Unstoppable',
    '12-week streak',
  ),
  AchievementId.explorer: _BadgeMeta(
    Icons.public,
    'Explorer',
    'Meet people in 10 places',
  ),
  AchievementId.connector: _BadgeMeta(
    Icons.hub_outlined,
    'Connector',
    'Map 20 connections',
  ),
  AchievementId.reconnector: _BadgeMeta(
    Icons.history,
    'Reconnector',
    'Revive 5 dormant ties',
  ),
  AchievementId.wellTended: _BadgeMeta(
    Icons.spa_outlined,
    'Gardener',
    '10 strong relationships',
  ),
  AchievementId.birthdayKnower: _BadgeMeta(
    Icons.cake_outlined,
    'Cake Boss',
    'Know 10 birthdays',
  ),
};

// ─────────────────────────────────────────────────────────────────────────
// Growth
// ─────────────────────────────────────────────────────────────────────────

class _GrowthCard extends StatelessWidget {
  final GrowthStats growth;
  const _GrowthCard({required this.growth});

  @override
  Widget build(BuildContext context) {
    return _Card(
      title: 'Network growth',
      icon: Icons.trending_up,
      iconColor: _P.green,
      trailing: _Pill('${growth.total} total', color: _P.green),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            height: 56,
            width: double.infinity,
            child: CustomPaint(
              painter: SparklinePainter(
                values: growth.last12Months,
                color: _P.green,
              ),
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            'New contacts · last 12 months',
            style: TextStyle(color: _P.muted, fontSize: 11),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _MiniStat(
                  label: 'Added by hand',
                  value: '${growth.manualCount}',
                ),
              ),
              Expanded(
                child: _MiniStat(
                  label: 'Imported',
                  value: '${growth.importedCount}',
                ),
              ),
              Expanded(
                child: _MiniStat(
                  label: 'Busiest month',
                  value: growth.busiestMonthLabel ?? '--',
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _MiniStat extends StatelessWidget {
  final String label;
  final String value;
  const _MiniStat({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          value,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            color: _P.text,
            fontSize: 15,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 2),
        Text(label, style: const TextStyle(color: _P.muted, fontSize: 11)),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────
// Interactions
// ─────────────────────────────────────────────────────────────────────────

class _InteractionsCard extends StatelessWidget {
  final InteractionStats stats;
  final void Function(Contact) onSelectContact;
  const _InteractionsCard({required this.stats, required this.onSelectContact});

  static const _typeOrder = [
    (InteractionType.call, 'Calls', Color(0xFF60A5FA)),
    (InteractionType.text, 'Texts', Color(0xFF34D399)),
    (InteractionType.meeting, 'Meetings', Color(0xFFF59E0B)),
    (InteractionType.email, 'Emails', Color(0xFFA78BFA)),
    (InteractionType.note, 'Notes', Color(0xFF9CA3AF)),
  ];

  @override
  Widget build(BuildContext context) {
    final maxCount = _typeOrder
        .map((t) => stats.countOf(t.$1))
        .fold<int>(0, (a, b) => a > b ? a : b);

    return _Card(
      title: 'Interactions',
      icon: Icons.forum_outlined,
      iconColor: _P.indigo,
      trailing: _Pill('${stats.total} total', color: _P.indigo),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final t in _typeOrder)
            _BarRow(
              label: t.$2,
              value: stats.countOf(t.$1),
              max: maxCount,
              color: t.$3,
            ),
          const SizedBox(height: 10),
          if (stats.mostContacted != null)
            _TappableRow(
              icon: Icons.star_outline,
              iconColor: _P.amber,
              title: stats.mostContacted!.displayName,
              subtitle:
                  'Most contacted · ${stats.mostContactedCount} interactions',
              onTap: () => onSelectContact(stats.mostContacted!),
            ),
          Padding(
            padding: const EdgeInsets.only(top: 6, left: 4),
            child: Row(
              children: [
                const Icon(
                  Icons.calendar_today_outlined,
                  size: 15,
                  color: _P.muted,
                ),
                const SizedBox(width: 8),
                Text(
                  'Most active on ${stats.mostActiveWeekdayLabel}',
                  style: const TextStyle(color: _P.muted, fontSize: 12),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────
// Geography & diversity
// ─────────────────────────────────────────────────────────────────────────

class _GeographyCard extends StatelessWidget {
  final GeographyStats geo;
  const _GeographyCard({required this.geo});

  @override
  Widget build(BuildContext context) {
    final maxTag = geo.topTags.isEmpty ? 0 : geo.topTags.first.count;
    return _Card(
      title: 'Where & who',
      icon: Icons.map_outlined,
      iconColor: _P.accent,
      trailing: _Pill('${geo.distinctPlaces} places', color: _P.accent),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (geo.topPlaces.isNotEmpty) ...[
            const Text(
              'Top places you met people',
              style: TextStyle(color: _P.muted, fontSize: 12),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final p in geo.topPlaces.take(6))
                  _Pill('${p.place} · ${p.count}', color: _P.accent),
              ],
            ),
            const SizedBox(height: 14),
          ],
          if (geo.topTags.isNotEmpty) ...[
            const Text(
              'Tag breakdown',
              style: TextStyle(color: _P.muted, fontSize: 12),
            ),
            const SizedBox(height: 8),
            for (final t in geo.topTags.take(6))
              _BarRow(
                label: t.tag,
                value: t.count,
                max: maxTag,
                color: _P.indigo,
              ),
          ],
          if (geo.topPlaces.isEmpty && geo.topTags.isEmpty)
            const Text(
              'Add places met and tags to see your map of who & where.',
              style: TextStyle(color: _P.muted, fontSize: 13),
            ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────
// Empty state
// ─────────────────────────────────────────────────────────────────────────

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return Container(
      color: _P.bg,
      child: const Center(
        child: Padding(
          padding: EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.insights_outlined, color: _P.accent, size: 44),
              SizedBox(height: 14),
              Text(
                'No stats yet',
                style: TextStyle(
                  color: _P.text,
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                ),
              ),
              SizedBox(height: 6),
              Text(
                'Add a few contacts and log interactions to start leveling up '
                'your network.',
                textAlign: TextAlign.center,
                style: TextStyle(color: _P.muted, fontSize: 13),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
