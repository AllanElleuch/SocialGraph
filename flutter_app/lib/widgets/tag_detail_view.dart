import 'package:flutter/material.dart';

import '../models/contact.dart';
import '../services/tag_membership.dart';

/// Palette matching the app's dark surfaces.
class _Palette {
  static const Color background = Color(0xFF0A0A0A);
  static const Color surface = Color(0xFF1A1A1A);
  static const Color border = Color(0xFF333333);
  static const Color accent = Color(0xFF818CF8);
  static const Color textPrimary = Color(0xFFE2E8F0);
  static const Color textMuted = Color(0xFF9CA3AF);
}

/// A full-screen view of a single tag: see who has it and quickly toggle people
/// in or out of it from one list — far faster than editing contacts one by one.
///
/// The view owns a working set of members and applies the change once, on Save,
/// via [onApply] (called with the final member id set). Cancelling discards.
class TagDetailView extends StatefulWidget {
  final String tag;
  final List<Contact> contacts;
  final void Function(Set<String> memberIds) onApply;

  const TagDetailView({
    super.key,
    required this.tag,
    required this.contacts,
    required this.onApply,
  });

  static Future<void> show(
    BuildContext context, {
    required String tag,
    required List<Contact> contacts,
    required void Function(Set<String> memberIds) onApply,
  }) {
    return Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => TagDetailView(
          tag: tag,
          contacts: contacts,
          onApply: onApply,
        ),
      ),
    );
  }

  @override
  State<TagDetailView> createState() => _TagDetailViewState();
}

class _TagDetailViewState extends State<TagDetailView> {
  late final Set<String> _members;
  String _query = '';
  bool _dirty = false;

  @override
  void initState() {
    super.initState();
    _members = {
      for (final c in widget.contacts)
        if (hasTag(c, widget.tag)) c.id,
    };
  }

  void _toggle(Contact c) {
    setState(() {
      if (!_members.remove(c.id)) _members.add(c.id);
      _dirty = true;
    });
  }

  void _save() {
    if (_dirty) widget.onApply(_members);
    Navigator.of(context).pop();
  }

  /// Tags every contact in the current (filtered) list.
  void _selectAll() {
    setState(() {
      for (final c in _filtered) {
        if (_members.add(c.id)) _dirty = true;
      }
    });
  }

  /// Untags every contact in the current (filtered) list.
  void _unselectAll() {
    setState(() {
      for (final c in _filtered) {
        if (_members.remove(c.id)) _dirty = true;
      }
    });
  }

  List<Contact> get _filtered {
    final query = _query.trim().toLowerCase();
    final list = [...widget.contacts]..sort((a, b) =>
        a.displayName.toLowerCase().compareTo(b.displayName.toLowerCase()));
    if (query.isEmpty) return list;
    return list
        .where((c) => c.displayName.toLowerCase().contains(query))
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _filtered;
    return Scaffold(
      backgroundColor: _Palette.background,
      appBar: AppBar(
        backgroundColor: _Palette.surface,
        elevation: 0,
        iconTheme: const IconThemeData(color: _Palette.textPrimary),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              widget.tag,
              style: const TextStyle(
                color: _Palette.textPrimary,
                fontSize: 18,
                fontWeight: FontWeight.w600,
              ),
              overflow: TextOverflow.ellipsis,
            ),
            Text(
              '${_members.length} '
              'tagged${_dirty ? ' · unsaved' : ''}',
              style: const TextStyle(color: _Palette.textMuted, fontSize: 12),
            ),
          ],
        ),
        actions: [
          PopupMenuButton<String>(
            tooltip: 'Select',
            color: _Palette.surface,
            icon: const Icon(Icons.more_vert, color: _Palette.textPrimary),
            onSelected: (value) {
              if (value == 'all') _selectAll();
              if (value == 'none') _unselectAll();
            },
            itemBuilder: (ctx) => const [
              PopupMenuItem(
                value: 'all',
                child: Row(
                  children: [
                    Icon(Icons.done_all, color: _Palette.accent, size: 18),
                    SizedBox(width: 10),
                    Text('Select all',
                        style: TextStyle(color: _Palette.textPrimary)),
                  ],
                ),
              ),
              PopupMenuItem(
                value: 'none',
                child: Row(
                  children: [
                    Icon(Icons.remove_done, color: _Palette.textMuted, size: 18),
                    SizedBox(width: 10),
                    Text('Unselect all',
                        style: TextStyle(color: _Palette.textPrimary)),
                  ],
                ),
              ),
            ],
          ),
          TextButton(
            onPressed: _dirty ? _save : () => Navigator.of(context).pop(),
            child: Text(
              _dirty ? 'Save' : 'Done',
              style: const TextStyle(
                  color: _Palette.accent, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: TextField(
              autofocus: false,
              onChanged: (v) => setState(() => _query = v),
              style: const TextStyle(color: _Palette.textPrimary, fontSize: 14),
              decoration: InputDecoration(
                hintText: 'Search contacts to tag…',
                hintStyle: const TextStyle(color: _Palette.textMuted),
                prefixIcon:
                    const Icon(Icons.search, color: _Palette.textMuted, size: 18),
                filled: true,
                fillColor: _Palette.surface,
                contentPadding: const EdgeInsets.symmetric(vertical: 0),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(100),
                  borderSide: const BorderSide(color: _Palette.border),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(100),
                  borderSide: const BorderSide(color: _Palette.border),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(100),
                  borderSide: const BorderSide(color: _Palette.accent),
                ),
              ),
            ),
          ),
          Expanded(
            child: filtered.isEmpty
                ? const Center(
                    child: Text('No matching contacts',
                        style: TextStyle(color: _Palette.textMuted)),
                  )
                : ListView.builder(
                    itemCount: filtered.length,
                    itemBuilder: (context, i) {
                      final c = filtered[i];
                      return _ContactToggleRow(
                        contact: c,
                        selected: _members.contains(c.id),
                        onTap: () => _toggle(c),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

class _ContactToggleRow extends StatelessWidget {
  final Contact contact;
  final bool selected;
  final VoidCallback onTap;

  const _ContactToggleRow({
    required this.contact,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final name = contact.displayName;
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        child: Row(
          children: [
            if (contact.hasPhoto)
              CircleAvatar(
                radius: 16,
                backgroundColor: _Palette.border,
                backgroundImage: MemoryImage(contact.photoThumbnail!),
              )
            else
              CircleAvatar(
                radius: 16,
                backgroundColor: _Palette.surface,
                child: Text(
                  // First grapheme, not name[0], to avoid splitting an emoji
                  // surrogate pair into invalid UTF-16.
                  name.isNotEmpty ? name.characters.first.toUpperCase() : '?',
                  style: const TextStyle(
                      color: _Palette.accent,
                      fontSize: 13,
                      fontWeight: FontWeight.bold),
                ),
              ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                name.isEmpty ? '(no name)' : name,
                style: const TextStyle(
                    color: _Palette.textPrimary, fontSize: 15),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            Icon(
              selected ? Icons.check_circle : Icons.radio_button_unchecked,
              color: selected ? _Palette.accent : _Palette.textMuted,
              size: 22,
            ),
          ],
        ),
      ),
    );
  }
}
