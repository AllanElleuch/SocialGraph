import 'package:flutter/material.dart';

import '../models/contact.dart';
import '../services/contact_filter.dart';
import '../services/tag_usage.dart';

class _P {
  static const surface = Color(0xFF1A1A1A);
  static const sheet = Color(0xFF111317);
  static const border = Color(0xFF2A2D34);
  static const accent = Color(0xFF818CF8);
  static const text = Color(0xFFE2E8F0);
  static const muted = Color(0xFF9CA3AF);
}

/// Bottom-sheet menu for filtering the Mutuals view by tags, family, and a few
/// quick criteria. Changes are applied live via [onChanged]; the sheet keeps a
/// local mirror of the filter so toggles update instantly.
class FilterSheet extends StatefulWidget {
  final ContactFilter filter;
  final List<Contact> contacts;
  final ValueChanged<ContactFilter> onChanged;

  const FilterSheet({
    super.key,
    required this.filter,
    required this.contacts,
    required this.onChanged,
  });

  static Future<void> show(
    BuildContext context, {
    required ContactFilter filter,
    required List<Contact> contacts,
    required ValueChanged<ContactFilter> onChanged,
  }) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => FilterSheet(
        filter: filter,
        contacts: contacts,
        onChanged: onChanged,
      ),
    );
  }

  @override
  State<FilterSheet> createState() => _FilterSheetState();
}

class _FilterSheetState extends State<FilterSheet> {
  late ContactFilter _f = widget.filter;
  late final List<MapEntry<String, int>> _tags;
  late final bool _hasFamily;

  @override
  void initState() {
    super.initState();
    // Tags sorted by usage (most-used first), then alphabetically.
    _tags = tagUsageCounts(widget.contacts).entries.toList()
      ..sort((a, b) {
        final byCount = b.value.compareTo(a.value);
        return byCount != 0 ? byCount : a.key.toLowerCase().compareTo(b.key.toLowerCase());
      });
    _hasFamily = familyContactIds(widget.contacts).isNotEmpty;
  }

  void _update(ContactFilter next) {
    setState(() => _f = next);
    widget.onChanged(next);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: _P.sheet,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        border: Border(top: BorderSide(color: _P.border)),
      ),
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.8,
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 10),
            Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: _P.border,
                borderRadius: BorderRadius.circular(100),
              ),
            ),
            _header(),
            const Divider(color: _P.border, height: 1),
            Flexible(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
                children: [
                  _sectionLabel('Quick filters'),
                  const SizedBox(height: 8),
                  _toggle(
                    icon: Icons.diversity_3,
                    label: 'Family only',
                    subtitle: _hasFamily
                        ? 'Contacts who share a last name'
                        : 'No families detected yet',
                    value: _f.familyOnly,
                    enabled: _hasFamily,
                    onChanged: (v) => _update(_f.copyWith(familyOnly: v)),
                  ),
                  _toggle(
                    icon: Icons.notifications_active_outlined,
                    label: 'Needs attention',
                    subtitle: 'Reach-out is overdue',
                    value: _f.needsAttentionOnly,
                    onChanged: (v) =>
                        _update(_f.copyWith(needsAttentionOnly: v)),
                  ),
                  _toggle(
                    icon: Icons.favorite,
                    label: 'Strong ties',
                    subtitle: 'Your closest relationships',
                    value: _f.strongOnly,
                    onChanged: (v) => _update(_f.copyWith(strongOnly: v)),
                  ),
                  _toggle(
                    icon: Icons.photo_outlined,
                    label: 'Has photo',
                    value: _f.withPhotoOnly,
                    onChanged: (v) => _update(_f.copyWith(withPhotoOnly: v)),
                  ),
                  _toggle(
                    icon: Icons.label_off_outlined,
                    label: 'Untagged only',
                    subtitle: 'Contacts with no tags',
                    value: _f.untaggedOnly,
                    onChanged: (v) => _update(_f.copyWith(
                      untaggedOnly: v,
                      // Untagged and a tag selection contradict each other.
                      tags: v ? const {} : _f.tags,
                    )),
                  ),
                  if (_tags.isNotEmpty) ...[
                    const SizedBox(height: 20),
                    _sectionLabel('Tags'),
                    const SizedBox(height: 10),
                    _tagWrap(),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _header() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 8, 8),
      child: Row(
        children: [
          const Icon(Icons.tune, color: _P.accent, size: 20),
          const SizedBox(width: 10),
          const Text(
            'Filter',
            style: TextStyle(
              color: _P.text,
              fontSize: 18,
              fontWeight: FontWeight.w700,
            ),
          ),
          const Spacer(),
          if (_f.isActive)
            TextButton(
              onPressed: () => _update(ContactFilter.none),
              child: const Text('Clear all',
                  style: TextStyle(color: _P.accent)),
            ),
          IconButton(
            onPressed: () => Navigator.of(context).pop(),
            icon: const Icon(Icons.close, color: _P.muted, size: 20),
          ),
        ],
      ),
    );
  }

  Widget _sectionLabel(String text) {
    return Text(
      text.toUpperCase(),
      style: const TextStyle(
        color: _P.muted,
        fontSize: 12,
        fontWeight: FontWeight.w600,
        letterSpacing: 1.2,
      ),
    );
  }

  Widget _toggle({
    required IconData icon,
    required String label,
    String? subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
    bool enabled = true,
  }) {
    final color = enabled ? _P.text : _P.muted.withValues(alpha: 0.5);
    return Opacity(
      opacity: enabled ? 1 : 0.6,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 2),
        child: Row(
          children: [
            Icon(icon, color: enabled ? _P.accent : _P.muted, size: 20),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label,
                      style: TextStyle(color: color, fontSize: 15)),
                  if (subtitle != null)
                    Text(subtitle,
                        style: const TextStyle(
                            color: _P.muted, fontSize: 12)),
                ],
              ),
            ),
            Switch(
              value: value,
              onChanged: enabled ? onChanged : null,
              activeTrackColor: _P.accent,
              activeThumbColor: Colors.white,
            ),
          ],
        ),
      ),
    );
  }

  Widget _tagWrap() {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final entry in _tags)
          _TagChip(
            label: entry.key,
            count: entry.value,
            selected: _f.tags.any(
                (t) => t.toLowerCase() == entry.key.toLowerCase()),
            onTap: () => _update(_f.toggleTag(entry.key)),
          ),
      ],
    );
  }
}

class _TagChip extends StatelessWidget {
  final String label;
  final int count;
  final bool selected;
  final VoidCallback onTap;

  const _TagChip({
    required this.label,
    required this.count,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color: selected
              ? _P.accent.withValues(alpha: 0.18)
              : _P.surface,
          borderRadius: BorderRadius.circular(100),
          border: Border.all(
            color: selected ? _P.accent : _P.border,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (selected) ...[
              const Icon(Icons.check, size: 14, color: _P.accent),
              const SizedBox(width: 5),
            ],
            Text(
              label,
              style: TextStyle(
                color: selected ? _P.text : _P.muted,
                fontSize: 13,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(width: 6),
            Text(
              '$count',
              style: const TextStyle(color: _P.muted, fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }
}
