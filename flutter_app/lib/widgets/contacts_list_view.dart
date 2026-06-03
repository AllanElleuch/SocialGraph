import 'package:flutter/material.dart';

import '../models/contact.dart';
import '../services/contact_sort.dart';

class _P {
  static const bg = Color(0xFF0A0A0A);
  static const text = Color(0xFFE2E8F0);
  static const muted = Color(0xFF6B7280);
  static const accent = Color(0xFF818CF8);
  static const divider = Color(0xFF1E1E1E);
}

/// One row of the flat list: either a section header or a contact row.
class _Entry {
  final String? header; // non-null → a section header
  final Contact? contact; // non-null → a contact row
  const _Entry.header(this.header) : contact = null;
  const _Entry.contact(this.contact) : header = null;
}

const double _headerHeight = 34;
const double _rowHeight = 64;
const double _topInset = 116; // clears the floating header/search
const double _bottomInset = 120; // clears the bottom controls bar

/// A classic address-book style list: contacts grouped A–Z with avatars, an
/// alphabet scrubber, and tap-to-open (which surfaces the existing contact card
/// with its call / message / social actions).
class ContactsListView extends StatefulWidget {
  final List<Contact> contacts;
  final ValueChanged<Contact> onSelectContact;

  const ContactsListView({
    super.key,
    required this.contacts,
    required this.onSelectContact,
  });

  @override
  State<ContactsListView> createState() => _ContactsListViewState();
}

class _ContactsListViewState extends State<ContactsListView> {
  final ScrollController _scroll = ScrollController();

  List<_Entry> _entries = const [];
  // Scroll offset (within the list content) for each present section letter.
  final Map<String, double> _sectionOffset = {};

  @override
  void initState() {
    super.initState();
    _rebuild();
  }

  @override
  void didUpdateWidget(ContactsListView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.contacts != widget.contacts) _rebuild();
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  void _rebuild() {
    final sorted = sortedForContactList(widget.contacts);
    final entries = <_Entry>[];
    _sectionOffset.clear();
    var offset = 0.0;
    String? current;
    for (final c in sorted) {
      final letter = contactSectionLetter(c);
      if (letter != current) {
        current = letter;
        _sectionOffset[letter] = offset;
        entries.add(_Entry.header(letter));
        offset += _headerHeight;
      }
      entries.add(_Entry.contact(c));
      offset += _rowHeight;
    }
    _entries = entries;
  }

  void _jumpTo(String letter) {
    // Jump to the chosen section, or the next present one alphabetically.
    const order = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ#';
    var target = _sectionOffset[letter];
    if (target == null) {
      final from = order.indexOf(letter);
      for (var i = from + 1; i < order.length && target == null; i++) {
        target = _sectionOffset[order[i]];
      }
    }
    if (target == null) return;
    final max = _scroll.position.hasContentDimensions
        ? _scroll.position.maxScrollExtent
        : double.infinity;
    _scroll.jumpTo(target.clamp(0.0, max));
  }

  @override
  Widget build(BuildContext context) {
    if (widget.contacts.isEmpty) {
      return Container(
        color: _P.bg,
        alignment: Alignment.center,
        child: const Text('No contacts',
            style: TextStyle(color: Color(0xFF94a3b8))),
      );
    }

    return Container(
      color: _P.bg,
      child: Stack(
        children: [
          ListView.builder(
            controller: _scroll,
            padding: const EdgeInsets.only(top: _topInset, bottom: _bottomInset),
            itemCount: _entries.length,
            itemBuilder: (context, i) {
              final e = _entries[i];
              if (e.header != null) return _sectionHeader(e.header!);
              return _ContactRow(
                contact: e.contact!,
                onTap: () => widget.onSelectContact(e.contact!),
              );
            },
          ),
          Positioned(
            right: 2,
            top: _topInset,
            bottom: _bottomInset,
            child: _AlphabetBar(onSelect: _jumpTo),
          ),
        ],
      ),
    );
  }

  Widget _sectionHeader(String letter) {
    return Container(
      height: _headerHeight,
      padding: const EdgeInsets.only(left: 20, bottom: 4),
      alignment: Alignment.bottomLeft,
      child: Text(
        letter,
        style: const TextStyle(
          color: _P.muted,
          fontSize: 13,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _ContactRow extends StatelessWidget {
  final Contact contact;
  final VoidCallback onTap;

  const _ContactRow({required this.contact, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: SizedBox(
        height: _rowHeight,
        child: Column(
          children: [
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  children: [
                    _Avatar(contact: contact),
                    const SizedBox(width: 14),
                    Expanded(child: _name(context)),
                    const Icon(Icons.chevron_right,
                        color: _P.muted, size: 18),
                  ],
                ),
              ),
            ),
            const Divider(
              height: 1,
              thickness: 1,
              indent: 70,
              color: _P.divider,
            ),
          ],
        ),
      ),
    );
  }

  Widget _name(BuildContext context) {
    final first = contact.firstName.trim();
    final last = contact.lastName.trim();
    // First name regular, last name bold — mirrors a phone's contacts app.
    return Text.rich(
      TextSpan(
        children: [
          if (first.isNotEmpty)
            TextSpan(text: last.isEmpty ? first : '$first '),
          if (last.isNotEmpty)
            TextSpan(
              text: last,
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
          if (first.isEmpty && last.isEmpty)
            const TextSpan(text: 'Unnamed'),
        ],
        style: const TextStyle(color: _P.text, fontSize: 17),
      ),
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
    );
  }
}

class _Avatar extends StatelessWidget {
  final Contact contact;
  const _Avatar({required this.contact});

  @override
  Widget build(BuildContext context) {
    if (contact.hasPhoto) {
      return CircleAvatar(
        radius: 24,
        backgroundColor: const Color(0xFF333333),
        backgroundImage: MemoryImage(contact.photoThumbnail!),
      );
    }
    return Container(
      width: 48,
      height: 48,
      decoration: const BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF6366F1), Color(0xFF8B5CF6)],
        ),
      ),
      alignment: Alignment.center,
      child: Text(
        contactInitials(contact),
        style: const TextStyle(
          color: Colors.white,
          fontSize: 16,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

/// The right-edge A–Z scrubber. Tapping or dragging jumps to a section.
class _AlphabetBar extends StatelessWidget {
  final ValueChanged<String> onSelect;
  const _AlphabetBar({required this.onSelect});

  static const String _letters = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ#';

  void _handle(Offset localPosition, double height) {
    final index = (localPosition.dy / height * _letters.length)
        .floor()
        .clamp(0, _letters.length - 1);
    onSelect(_letters[index]);
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final height = constraints.maxHeight;
        return GestureDetector(
          onTapDown: (d) => _handle(d.localPosition, height),
          onVerticalDragUpdate: (d) => _handle(d.localPosition, height),
          behavior: HitTestBehavior.opaque,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 6),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                for (final l in _letters.split(''))
                  Expanded(
                    child: Center(
                      child: Text(
                        l,
                        style: const TextStyle(
                          color: _P.accent,
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}
