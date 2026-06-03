import 'package:flutter/material.dart';

import '../stats/level.dart';
import '../stats/level_requirements.dart';

/// Dark palette, matching the Stats surface.
class _P {
  static const bg = Color(0xFF161616);
  static const border = Color(0xFF333333);
  static const indigo = Color(0xFF6366F1);
  static const accent = Color(0xFF818CF8);
  static const amber = Color(0xFFF59E0B);
  static const text = Color(0xFFE2E8F0);
  static const muted = Color(0xFF9CA3AF);
  static const faint = Color(0xFF242424);
}

/// A full progression roadmap shown when the user taps the level hero card.
///
/// Renders the named 10-level ladder ([kLevelTitles]) as a vertical timeline:
/// unlocked rungs are filled with a check, the current level glows with a
/// "You are here" marker, and locked rungs are dimmed with the XP still needed.
/// At the apex, a prestige banner shows the player's Legend tier.
class LevelRoadmap extends StatelessWidget {
  final LevelStats level;

  const LevelRoadmap({super.key, required this.level});

  /// Presents the roadmap inside a scrollable modal bottom sheet.
  static Future<void> show(BuildContext context, {required LevelStats level}) {
    return showModalBottomSheet<void>(
      context: context,
      backgroundColor: _P.bg,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => LevelRoadmap(level: level),
    );
  }

  @override
  Widget build(BuildContext context) {
    // The current named rung (apex caps at 10 even with prestige).
    final currentRung = level.level.clamp(1, kMaxNamedLevel);

    return SafeArea(
      top: false,
      child: DraggableScrollableSheet(
        initialChildSize: 0.85,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        expand: false,
        builder: (context, controller) => Column(
          children: [
            const SizedBox(height: 10),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: _P.border,
                borderRadius: BorderRadius.circular(100),
              ),
            ),
            _Header(level: level),
            Expanded(
              child: ListView.builder(
                controller: controller,
                padding: const EdgeInsets.fromLTRB(20, 4, 20, 28),
                itemCount: kMaxNamedLevel,
                itemBuilder: (context, i) {
                  final rungLevel = i + 1;
                  return _Rung(
                    rungLevel: rungLevel,
                    title: kLevelTitles[i],
                    threshold: xpForLevel(rungLevel),
                    currentXp: level.xp,
                    currentRung: currentRung,
                    requirement: level.requirements?[rungLevel],
                    isFirst: i == 0,
                    isLast: i == kMaxNamedLevel - 1,
                    prestige: rungLevel == kMaxNamedLevel ? level.prestige : 0,
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  final LevelStats level;
  const _Header({required this.level});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: const [
              Icon(Icons.flag_outlined, color: _P.amber, size: 22),
              SizedBox(width: 10),
              Text(
                'Your journey',
                style: TextStyle(
                  color: _P.text,
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            'You are ${level.rankTitle} · ${level.levelLabel} · ${level.xpLabel}',
            style: const TextStyle(color: _P.accent, fontSize: 13),
          ),
          if (level.prestige > 0) ...[
            const SizedBox(height: 10),
            _PrestigeBanner(prestige: level.prestige, title: level.rankTitle),
          ],
        ],
      ),
    );
  }
}

class _PrestigeBanner extends StatelessWidget {
  final int prestige;
  final String title;
  const _PrestigeBanner({required this.prestige, required this.title});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF3B2F0B), Color(0xFF1E1B4B)],
        ),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _P.amber.withValues(alpha: 0.5)),
      ),
      child: Row(
        children: [
          for (var i = 0; i < (prestige > 5 ? 5 : prestige); i++)
            const Padding(
              padding: EdgeInsets.only(right: 2),
              child: Icon(Icons.star, color: _P.amber, size: 16),
            ),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              'Apex reached — $title',
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

/// One node of the vertical timeline: a rail (line + dot) on the left and the
/// level's title / status on the right.
class _Rung extends StatelessWidget {
  final int rungLevel;
  final String title;
  final int threshold;
  final int currentXp;
  final int currentRung;
  final LevelRequirement? requirement;
  final bool isFirst;
  final bool isLast;
  final int prestige;

  const _Rung({
    required this.rungLevel,
    required this.title,
    required this.threshold,
    required this.currentXp,
    required this.currentRung,
    required this.requirement,
    required this.isFirst,
    required this.isLast,
    required this.prestige,
  });

  bool get _isCurrent => rungLevel == currentRung;
  bool get _isUnlocked => rungLevel < currentRung;
  bool get _isLocked => rungLevel > currentRung;

  Color get _nodeColor {
    if (_isCurrent) return _P.indigo;
    if (_isUnlocked) return _P.amber;
    return _P.faint;
  }

  @override
  Widget build(BuildContext context) {
    final lineAbove = isFirst ? Colors.transparent : _railColor(rungLevel - 1);
    final lineBelow = isLast ? Colors.transparent : _railColor(rungLevel);

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Left rail: line above, node, line below.
          SizedBox(
            width: 30,
            child: Column(
              children: [
                Expanded(child: Container(width: 2, color: lineAbove)),
                _node(),
                Expanded(child: Container(width: 2, color: lineBelow)),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: _content(),
            ),
          ),
        ],
      ),
    );
  }

  /// The rail above/below a node is "lit" once that boundary is passed.
  Color _railColor(int belowLevel) =>
      belowLevel < currentRung ? _P.amber : _P.border;

  Widget _node() {
    final color = _nodeColor;
    return Container(
      width: 26,
      height: 26,
      decoration: BoxDecoration(
        color: _isLocked ? _P.faint : color,
        shape: BoxShape.circle,
        border: Border.all(color: _isLocked ? _P.border : color, width: 2),
        boxShadow: _isCurrent
            ? [
                BoxShadow(
                  color: _P.indigo.withValues(alpha: 0.6),
                  blurRadius: 12,
                ),
              ]
            : null,
      ),
      child: Center(
        child: _isUnlocked
            ? const Icon(Icons.check, size: 15, color: Colors.white)
            : _isCurrent
            ? const Icon(Icons.person, size: 14, color: Colors.white)
            : Text(
                '$rungLevel',
                style: const TextStyle(
                  color: _P.muted,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
      ),
    );
  }

  Widget _content() {
    final titleColor = _isLocked ? _P.muted : _P.text;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              'Lv $rungLevel',
              style: TextStyle(
                color: _isLocked ? _P.muted : _P.accent,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(width: 8),
            Flexible(
              child: Text(
                prestige > 0 ? 'Networking Legend' : title,
                style: TextStyle(
                  color: titleColor,
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        const SizedBox(height: 2),
        if (_isCurrent)
          Text(
            prestige > 0
                ? 'You are here · prestige tier $prestige'
                : 'You are here',
            style: const TextStyle(
              color: _P.indigo,
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          )
        else if (_isUnlocked)
          const Text('Passed', style: TextStyle(color: _P.amber, fontSize: 12)),
        const SizedBox(height: 6),
        // Requirements to pass this level: BOTH the XP threshold and the hard
        // requirement must be met. Level 1 is the starting point (no gate).
        if (rungLevel == 1)
          const Text(
            'Starting point',
            style: TextStyle(color: _P.muted, fontSize: 12),
          )
        else ...[
          _GateLine(
            icon: Icons.bolt,
            met: currentXp >= threshold,
            text: '$threshold XP',
            detail: currentXp >= threshold ? null : '$currentXp / $threshold',
          ),
          const SizedBox(height: 4),
          if (requirement != null)
            _GateLine(
              icon: Icons.flag_outlined,
              met: requirement!.met,
              text: requirement!.label,
              detail: requirement!.met ? null : requirement!.progressLabel,
            ),
        ],
      ],
    );
  }
}

/// A single "requirement to pass" line: a check when met, otherwise a muted
/// progress hint (e.g. "Add 3 contacts · 2/3").
class _GateLine extends StatelessWidget {
  final IconData icon;
  final bool met;
  final String text;
  final String? detail;

  const _GateLine({
    required this.icon,
    required this.met,
    required this.text,
    required this.detail,
  });

  @override
  Widget build(BuildContext context) {
    final color = met ? _P.amber : _P.muted;
    return Row(
      children: [
        Icon(met ? Icons.check_circle : icon, size: 14, color: color),
        const SizedBox(width: 6),
        Flexible(
          child: Text(
            detail == null ? text : '$text · $detail',
            style: TextStyle(
              color: met ? _P.text : _P.muted,
              fontSize: 12,
              fontWeight: met ? FontWeight.w500 : FontWeight.w400,
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}
