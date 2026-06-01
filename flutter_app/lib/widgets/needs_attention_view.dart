import 'package:flutter/material.dart';

import '../models/contact.dart';
import '../services/reach_out_service.dart';
import '../services/relationship_strength.dart';

/// Dark-theme palette for the "needs attention" surface (RFC-005, U5.2).
class _Palette {
  static const Color background = Color(0xFF1A1A1A);
  static const Color border = Color(0xFF333333);
  static const Color accent = Color(0xFF818CF8);
  static const Color textPrimary = Color(0xFFE2E8F0);
  static const Color textMuted = Color(0xFF9CA3AF);
  static const Color overdue = Color(0xFFEF4444);
}

/// A prioritised list of overdue contacts that "need attention".
///
/// Pure/testable: the caller injects [now]; this widget never reads the system
/// clock. Contacts are filtered to those that are overdue via [overdueContacts],
/// then ranked by an urgency priority that weights how overdue a contact is by
/// their [strengthScore] — stronger relationships that are more overdue surface
/// first. Tapping a row invokes [onSelect] with that contact.
class NeedsAttentionView extends StatelessWidget {
  final List<Contact> contacts;
  final DateTime now;
  final void Function(Contact) onSelect;

  const NeedsAttentionView({
    super.key,
    required this.contacts,
    required this.now,
    required this.onSelect,
  });

  /// Presents the view inside a modal bottom sheet.
  static Future<void> show(
    BuildContext context, {
    required List<Contact> contacts,
    required DateTime now,
    required void Function(Contact) onSelect,
  }) {
    return showModalBottomSheet<void>(
      context: context,
      backgroundColor: _Palette.background,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (sheetContext) {
        return NeedsAttentionView(
          contacts: contacts,
          now: now,
          onSelect: (contact) {
            Navigator.of(sheetContext).pop();
            onSelect(contact);
          },
        );
      },
    );
  }

  /// Overdue contacts ranked most-urgent first.
  ///
  /// Priority = daysOverdue * (1 + strengthScore/100), so a more overdue or
  /// stronger relationship ranks higher. Ties fall back to most-overdue first.
  List<_RankedContact> _ranked() {
    final ranked = <_RankedContact>[];
    for (final contact in overdueContacts(contacts, now: now)) {
      final status = reachOutStatus(contact, now: now);
      final daysOverdue = status.dueInDays < 0 ? -status.dueInDays : 0;
      final strength = strengthScore(contact, now: now);
      final priority = daysOverdue * (1.0 + strength / 100.0);
      ranked.add(_RankedContact(
        contact: contact,
        daysOverdue: daysOverdue,
        strength: strength,
        priority: priority,
      ));
    }
    ranked.sort((a, b) {
      final byPriority = b.priority.compareTo(a.priority);
      if (byPriority != 0) return byPriority;
      return b.daysOverdue.compareTo(a.daysOverdue);
    });
    return ranked;
  }

  @override
  Widget build(BuildContext context) {
    final ranked = _ranked();

    return SafeArea(
      child: Container(
        color: _Palette.background,
        constraints: const BoxConstraints(maxHeight: 560),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const _Header(),
            if (ranked.isEmpty)
              const _EmptyState()
            else
              Flexible(
                child: ListView.separated(
                  shrinkWrap: true,
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  itemCount: ranked.length,
                  separatorBuilder: (_, __) => const Divider(
                    height: 1,
                    thickness: 1,
                    color: _Palette.border,
                  ),
                  itemBuilder: (context, index) {
                    final item = ranked[index];
                    return _AttentionRow(
                      item: item,
                      onTap: () => onSelect(item.contact),
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

class _RankedContact {
  final Contact contact;
  final int daysOverdue;
  final double strength;
  final double priority;

  const _RankedContact({
    required this.contact,
    required this.daysOverdue,
    required this.strength,
    required this.priority,
  });

  /// "Overdue by N days" label (singular/plural aware).
  String get overdueLabel =>
      'Overdue by $daysOverdue ${daysOverdue == 1 ? 'day' : 'days'}';

  /// Strength hint shown beneath the name, e.g. "Strong relationship".
  String get strengthHint => '${strengthLabel(strength)} relationship';
}

class _Header extends StatelessWidget {
  const _Header();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: _Palette.border)),
      ),
      child: Row(
        children: const [
          Icon(Icons.notifications_active_outlined,
              color: _Palette.accent, size: 22),
          SizedBox(width: 10),
          Text(
            'Needs attention',
            style: TextStyle(
              color: _Palette.textPrimary,
              fontSize: 18,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.symmetric(horizontal: 24, vertical: 48),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.check_circle_outline, color: _Palette.accent, size: 40),
          SizedBox(height: 12),
          Text(
            "You're all caught up",
            style: TextStyle(
              color: _Palette.textPrimary,
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
          SizedBox(height: 6),
          Text(
            'No contacts are overdue for a reach-out.',
            textAlign: TextAlign.center,
            style: TextStyle(color: _Palette.textMuted, fontSize: 13),
          ),
        ],
      ),
    );
  }
}

class _AttentionRow extends StatelessWidget {
  final _RankedContact item;
  final VoidCallback onTap;

  const _AttentionRow({required this.item, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final name = item.contact.displayName;
    return Semantics(
      button: true,
      label: '$name, ${item.overdueLabel}, ${item.strengthHint}',
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      style: const TextStyle(
                        color: _Palette.textPrimary,
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      item.overdueLabel,
                      style: const TextStyle(
                        color: _Palette.overdue,
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      item.strengthHint,
                      style: const TextStyle(
                        color: _Palette.textMuted,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right,
                  color: _Palette.textMuted, size: 20),
            ],
          ),
        ),
      ),
    );
  }
}
