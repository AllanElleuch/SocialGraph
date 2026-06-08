import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

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
///
/// While the finger is down, the touched letter (and its neighbours) magnify
/// into a "loupe", the active letter brightens, and a zooming bubble pops out
/// to the left showing the current letter — giving live feedback that tracks
/// smoothly as the finger slides across letters, with a haptic tick on each
/// new letter.
class _AlphabetBar extends StatefulWidget {
  final ValueChanged<String> onSelect;
  const _AlphabetBar({required this.onSelect});

  @override
  State<_AlphabetBar> createState() => _AlphabetBarState();
}

class _AlphabetBarState extends State<_AlphabetBar>
    with SingleTickerProviderStateMixin {
  static const String _letters = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ#';
  static const double _barWidth = 28;
  static const double _bubbleSize = 64;

  // The letter currently under the finger, or null when idle.
  int? _activeIndex;
  // Drives how much the loupe magnification and bubble are "in": 0 idle, 1 held.
  late final AnimationController _intensity;

  @override
  void initState() {
    super.initState();
    _intensity = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 180),
      reverseDuration: const Duration(milliseconds: 260),
    )..addStatusListener((status) {
        // Once fully faded out, drop the active letter so nothing lingers.
        if (status == AnimationStatus.dismissed && mounted) {
          setState(() => _activeIndex = null);
        }
      });
  }

  @override
  void dispose() {
    _intensity.dispose();
    super.dispose();
  }

  void _select(Offset localPosition, double height) {
    final index = (localPosition.dy / height * _letters.length)
        .floor()
        .clamp(0, _letters.length - 1);
    if (index != _activeIndex) {
      HapticFeedback.selectionClick();
      setState(() => _activeIndex = index);
      widget.onSelect(_letters[index]);
    }
  }

  void _start(Offset localPosition, double height) {
    _intensity.forward();
    _select(localPosition, height);
  }

  void _end() => _intensity.reverse();

  // How big letter [i] is scaled, easing in/out with the held intensity [t].
  double _scaleFor(int i, double t) {
    final active = _activeIndex;
    if (active == null) return 1.0;
    final d = (i - active).abs();
    final double mag = switch (d) {
      0 => 2.0,
      1 => 1.55,
      2 => 1.2,
      _ => 1.0,
    };
    return 1.0 + (mag - 1.0) * t;
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final height = constraints.maxHeight;
        final slot = height / _letters.length;
        return GestureDetector(
          onTapDown: (d) => _start(d.localPosition, height),
          onTapUp: (_) => _end(),
          onTapCancel: _end,
          onVerticalDragStart: (d) => _start(d.localPosition, height),
          onVerticalDragUpdate: (d) => _select(d.localPosition, height),
          onVerticalDragEnd: (_) => _end(),
          onVerticalDragCancel: _end,
          behavior: HitTestBehavior.opaque,
          child: AnimatedBuilder(
            animation: _intensity,
            builder: (context, _) {
              final t = Curves.easeOut.transform(_intensity.value);
              return Stack(
                clipBehavior: Clip.none,
                children: [
                  SizedBox(
                    width: _barWidth,
                    height: height,
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        for (var i = 0; i < _letters.length; i++)
                          Expanded(
                            child: Center(
                              child: Transform.scale(
                                scale: _scaleFor(i, t),
                                child: Text(
                                  _letters[i],
                                  style: TextStyle(
                                    color: Color.lerp(
                                      _P.accent,
                                      Colors.white,
                                      i == _activeIndex ? t : 0,
                                    ),
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                  if (_activeIndex != null) _bubble(slot, t),
                ],
              );
            },
          ),
        );
      },
    );
  }

  // The big zooming preview that pops out to the left of the active letter.
  Widget _bubble(double slot, double t) {
    final centerY = (_activeIndex! + 0.5) * slot;
    return Positioned(
      right: _barWidth + 6,
      top: centerY - _bubbleSize / 2,
      child: Opacity(
        opacity: t,
        child: Transform.scale(
          scale: 0.6 + 0.4 * t,
          child: Container(
            width: _bubbleSize,
            height: _bubbleSize,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color(0xFF6366F1), Color(0xFF8B5CF6)],
              ),
              boxShadow: [
                BoxShadow(
                  color: _P.accent.withValues(alpha: 0.5),
                  blurRadius: 24,
                  spreadRadius: 2,
                ),
              ],
            ),
            alignment: Alignment.center,
            child: Text(
              _letters[_activeIndex!],
              style: const TextStyle(
                color: Colors.white,
                fontSize: 30,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
