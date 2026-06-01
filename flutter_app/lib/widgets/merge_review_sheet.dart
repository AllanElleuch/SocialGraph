import 'package:flutter/material.dart';

import '../models/contact.dart';
import '../services/contact_merge.dart';

/// RFC-002 merge-review UI.
///
/// Presents the duplicate groups returned by `findDuplicateGroups` and lets the
/// user merge or dismiss each group. Merging calls back with the merged contact
/// and the ids of the contacts that were merged away; both actions remove the
/// group's row from the sheet locally.
class MergeReviewSheet extends StatefulWidget {
  /// Duplicate groups to review. Each inner list has >= 2 contacts.
  final List<List<Contact>> groups;

  /// Called when the user confirms a merge for a group. [merged] is the result
  /// of merging `group.first` with the rest; [mergedAwayIds] are the ids of the
  /// non-primary contacts in the group.
  final void Function(Contact merged, List<String> mergedAwayIds) onMergeGroup;

  const MergeReviewSheet({
    super.key,
    required this.groups,
    required this.onMergeGroup,
  });

  /// Opens the sheet in a [showModalBottomSheet] with the dark merge-review
  /// theme applied.
  static Future<void> show(
    BuildContext context, {
    required List<List<Contact>> groups,
    required void Function(Contact, List<String>) onMergeGroup,
  }) {
    return showModalBottomSheet<void>(
      context: context,
      backgroundColor: _MergeColors.background,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) => SafeArea(
        child: FractionallySizedBox(
          heightFactor: 0.85,
          child: MergeReviewSheet(
            groups: groups,
            onMergeGroup: onMergeGroup,
          ),
        ),
      ),
    );
  }

  @override
  State<MergeReviewSheet> createState() => _MergeReviewSheetState();
}

class _MergeColors {
  const _MergeColors._();

  static const Color background = Color(0xFF1A1A1A);
  static const Color border = Color(0xFF333333);
  static const Color accent = Color(0xFF6366F1);
  static const Color accentLight = Color(0xFF818CF8);
  static const Color textPrimary = Color(0xFFE2E8F0);
  static const Color textSecondary = Color(0xFF9CA3AF);
}

class _MergeReviewSheetState extends State<MergeReviewSheet> {
  /// Indices of groups (into [widget.groups]) still visible in the sheet.
  late List<int> _visible;

  @override
  void initState() {
    super.initState();
    _visible = List<int>.generate(widget.groups.length, (i) => i);
  }

  void _handleMerge(int groupIndex) {
    final group = widget.groups[groupIndex];
    final merged = mergeContacts(group.first, group.sublist(1));
    final mergedAwayIds = group.sublist(1).map((c) => c.id).toList();
    widget.onMergeGroup(merged, mergedAwayIds);
    setState(() => _visible.remove(groupIndex));
  }

  void _handleDismiss(int groupIndex) {
    setState(() => _visible.remove(groupIndex));
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const _SheetHeader(),
        Expanded(
          child: _visible.isEmpty
              ? const _EmptyState()
              : ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: _visible.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 16),
                  itemBuilder: (context, i) {
                    final groupIndex = _visible[i];
                    return _GroupCard(
                      key: ValueKey<int>(groupIndex),
                      group: widget.groups[groupIndex],
                      onMerge: () => _handleMerge(groupIndex),
                      onDismiss: () => _handleDismiss(groupIndex),
                    );
                  },
                ),
        ),
      ],
    );
  }
}

class _SheetHeader extends StatelessWidget {
  const _SheetHeader();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
      decoration: const BoxDecoration(
        border: Border(
          bottom: BorderSide(color: _MergeColors.border),
        ),
      ),
      child: const Text(
        'Review duplicates',
        style: TextStyle(
          color: _MergeColors.textPrimary,
          fontSize: 18,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Text(
        'No duplicates to review',
        style: TextStyle(color: _MergeColors.textSecondary, fontSize: 14),
      ),
    );
  }
}

class _GroupCard extends StatelessWidget {
  final List<Contact> group;
  final VoidCallback onMerge;
  final VoidCallback onDismiss;

  const _GroupCard({
    super.key,
    required this.group,
    required this.onMerge,
    required this.onDismiss,
  });

  @override
  Widget build(BuildContext context) {
    final merged = mergeContacts(group.first, group.sublist(1));
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _MergeColors.background,
        border: Border.all(color: _MergeColors.border),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            '${group.length} possible duplicates',
            style: const TextStyle(
              color: _MergeColors.accentLight,
              fontSize: 12,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.4,
            ),
          ),
          const SizedBox(height: 12),
          for (final contact in group) ...[
            _ContactRow(contact: contact, label: 'Candidate'),
            const SizedBox(height: 8),
          ],
          const Divider(color: _MergeColors.border, height: 24),
          _ContactRow(contact: merged, label: 'Merged result', highlight: true),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: onDismiss,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: _MergeColors.textSecondary,
                    side: const BorderSide(color: _MergeColors.border),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                  child: const Text('Dismiss'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton(
                  onPressed: onMerge,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _MergeColors.accent,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                  child: const Text('Merge'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ContactRow extends StatelessWidget {
  final Contact contact;
  final String label;
  final bool highlight;

  const _ContactRow({
    required this.contact,
    required this.label,
    this.highlight = false,
  });

  @override
  Widget build(BuildContext context) {
    final details = <String>[
      if (contact.phone.trim().isNotEmpty) contact.phone.trim(),
      if (contact.email.trim().isNotEmpty) contact.email.trim(),
      if (contact.workplace.trim().isNotEmpty) contact.workplace.trim(),
    ];
    final name = contact.displayName.isEmpty ? '(no name)' : contact.displayName;

    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: highlight
            ? _MergeColors.accent.withValues(alpha: 0.12)
            : Colors.transparent,
        border: Border.all(
          color: highlight ? _MergeColors.accent : _MergeColors.border,
        ),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label.toUpperCase(),
            style: TextStyle(
              color: highlight
                  ? _MergeColors.accentLight
                  : _MergeColors.textSecondary,
              fontSize: 10,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.6,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            name,
            style: const TextStyle(
              color: _MergeColors.textPrimary,
              fontSize: 15,
              fontWeight: FontWeight.w600,
            ),
          ),
          if (details.isNotEmpty) ...[
            const SizedBox(height: 2),
            Text(
              details.join('  •  '),
              style: const TextStyle(
                color: _MergeColors.textSecondary,
                fontSize: 13,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
