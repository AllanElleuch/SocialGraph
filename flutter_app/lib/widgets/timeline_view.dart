import 'package:flutter/material.dart';
import '../models/contact.dart';

/// How the timeline orders contacts.
enum TimelineSortMode {
  /// Order by the date the contact was met (chronological, ascending).
  met,

  /// Order by the most recent interaction first (`lastInteraction ?? dateMet`).
  recent,
}

class TimelineView extends StatefulWidget {
  final List<Contact> contacts;
  final ValueChanged<Contact> onSelectContact;

  const TimelineView({
    super.key,
    required this.contacts,
    required this.onSelectContact,
  });

  @override
  State<TimelineView> createState() => _TimelineViewState();
}

class _TimelineViewState extends State<TimelineView>
    with SingleTickerProviderStateMixin {
  late AnimationController _animController;
  late Animation<double> _fadeIn;

  TimelineSortMode _sortMode = TimelineSortMode.met;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _fadeIn = CurvedAnimation(parent: _animController, curve: Curves.easeOut);
    _animController.forward();
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  /// The date used to order/group a contact in "Recent" mode. Null = unknown.
  DateTime? _recencyOf(Contact c) => c.lastInteraction ?? c.dateMet;

  /// Compares two nullable dates, sorting unknown (null) dates to the end.
  int _cmpNullsLast(DateTime? a, DateTime? b, {bool descending = false}) {
    if (a == null && b == null) return 0;
    if (a == null) return 1;
    if (b == null) return -1;
    return descending ? b.compareTo(a) : a.compareTo(b);
  }

  List<Contact> get _sorted {
    final list = [...widget.contacts];
    switch (_sortMode) {
      case TimelineSortMode.met:
        list.sort((a, b) => _cmpNullsLast(a.dateMet, b.dateMet));
        break;
      case TimelineSortMode.recent:
        // Most-recent interaction first (descending); unknowns last.
        list.sort(
            (a, b) => _cmpNullsLast(_recencyOf(a), _recencyOf(b), descending: true));
        break;
    }
    return list;
  }

  /// The date this contact is positioned/grouped by under the active mode.
  /// Null when the contact has no known date (e.g. an undated import).
  DateTime? _orderingDate(Contact c) =>
      _sortMode == TimelineSortMode.recent ? _recencyOf(c) : c.dateMet;

  @override
  Widget build(BuildContext context) {
    if (widget.contacts.isEmpty) {
      return Column(
        children: [
          _buildModeToggle(),
          const Expanded(
            child: Center(
              child: Text('No contacts',
                  style: TextStyle(color: Color(0xFF94a3b8))),
            ),
          ),
        ],
      );
    }

    final sorted = _sorted;

    // Color range spans the known ordering dates so the magma gradient stays
    // meaningful regardless of the active sort mode.
    final dated = sorted.map(_orderingDate).whereType<DateTime>().toList();
    var earliest = dated.isEmpty ? DateTime.now() : dated.first;
    var latest = earliest;
    for (final d in dated) {
      if (d.isBefore(earliest)) earliest = d;
      if (d.isAfter(latest)) latest = d;
    }

    // Group contacts by year-month of their ordering date (or an "Unknown"
    // bucket for undated contacts), preserving the sorted order of first
    // appearance. Because unknowns sort last, the Unknown group lands last.
    final groups = <String, List<Contact>>{};
    for (final c in sorted) {
      final d = _orderingDate(c);
      final key = d != null ? _monthYearKey(d) : 'Unknown';
      groups.putIfAbsent(key, () => []).add(c);
    }
    final groupKeys = groups.keys.toList();

    return Column(
      children: [
        _buildModeToggle(),
        Expanded(
          child: FadeTransition(
            opacity: _fadeIn,
            child: Padding(
              padding: const EdgeInsets.only(top: 100, bottom: 100),
              child: ListView.builder(
                padding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
                itemCount: groupKeys.length,
                itemBuilder: (context, index) {
                  final key = groupKeys[index];
                  final contacts = groups[key]!;
                  return _buildMonthGroup(key, contacts, earliest, latest);
                },
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildModeToggle() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      child: Align(
        alignment: Alignment.centerRight,
        child: Container(
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            color: const Color(0xFF111111),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: const Color(0xFF1e1b4b)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildModeButton('Met', TimelineSortMode.met),
              const SizedBox(width: 4),
              _buildModeButton('Recent', TimelineSortMode.recent),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildModeButton(String label, TimelineSortMode mode) {
    final selected = _sortMode == mode;
    return Semantics(
      button: true,
      selected: selected,
      label: 'Sort by $label',
      child: GestureDetector(
        onTap: () {
          if (_sortMode != mode) {
            setState(() => _sortMode = mode);
          }
        },
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
          decoration: BoxDecoration(
            color: selected ? const Color(0xFF6366f1) : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            label,
            style: TextStyle(
              color: selected ? Colors.white : const Color(0xFF6b7280),
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ),
    );
  }

  String _monthYearKey(DateTime dt) {
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    return '${months[dt.month - 1]} ${dt.year}';
  }

  Widget _buildMonthGroup(
    String label,
    List<Contact> contacts,
    DateTime earliest,
    DateTime latest,
  ) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 32),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Date label
          SizedBox(
            width: 100,
            child: Text(
              label,
              style: const TextStyle(
                color: Color(0xFF6b7280),
                fontSize: 13,
                fontWeight: FontWeight.w600,
                letterSpacing: 1,
              ),
            ),
          ),
          // Timeline line + dot
          Column(
            children: [
              Container(
                width: 12,
                height: 12,
                decoration: BoxDecoration(
                  color: const Color(0xFF6366f1),
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF6366f1).withValues(alpha: 0.4),
                      blurRadius: 8,
                    ),
                  ],
                ),
              ),
              Container(
                width: 2,
                height: contacts.length * 72.0 + 8,
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [Color(0xFF6366f1), Color(0xFF1e1b4b)],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(width: 24),
          // Contact cards
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: contacts
                  .map((c) => _buildContactTile(c, earliest, latest))
                  .toList(),
            ),
          ),
        ],
      ),
    );
  }

  Color _timeColor(DateTime date, DateTime earliest, DateTime latest) {
    final range = latest.difference(earliest).inMilliseconds;
    if (range == 0) return const Color(0xFF6366f1);
    final t =
        date.difference(earliest).inMilliseconds / range;
    // Magma-inspired gradient
    if (t < 0.25) {
      return Color.lerp(
          const Color(0xFF51127C), const Color(0xFFB63679), t / 0.25)!;
    } else if (t < 0.5) {
      return Color.lerp(const Color(0xFFB63679), const Color(0xFFFB8761),
          (t - 0.25) / 0.25)!;
    } else if (t < 0.75) {
      return Color.lerp(const Color(0xFFFB8761), const Color(0xFFFCA636),
          (t - 0.5) / 0.25)!;
    }
    return Color.lerp(const Color(0xFFFCA636), const Color(0xFFFCFDBF),
        (t - 0.75) / 0.25)!;
  }

  String _relativeDate(DateTime date) {
    final now = DateTime.now();
    final diff = now.difference(date);
    if (diff.inDays < 1) return 'Today';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    if (diff.inDays < 30) return '${(diff.inDays / 7).floor()}w ago';
    if (diff.inDays < 365) return '${(diff.inDays / 30).floor()}mo ago';
    return '${(diff.inDays / 365).floor()}y ago';
  }

  Widget _buildContactTile(
      Contact contact, DateTime earliest, DateTime latest) {
    final orderingDate = _orderingDate(contact);
    final color = orderingDate != null
        ? _timeColor(orderingDate, earliest, latest)
        : const Color(0xFF6b7280);
    final interactionCount = contact.interactions.length;

    return GestureDetector(
      onTap: () => widget.onSelectContact(contact),
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: const Color(0xFF111111),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: color.withValues(alpha: 0.3),
          ),
        ),
        child: Row(
          children: [
            // Avatar — the contact's photo when available, otherwise a colored
            // circle with their initial.
            _buildAvatar(contact, color),
            const SizedBox(width: 12),
            // Name + tags
            Expanded(
              flex: 2,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    contact.displayName,
                    style: const TextStyle(
                      color: Color(0xFFe2e8f0),
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (contact.tags.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: Text(
                        contact.tags.join(' / '),
                        style: const TextStyle(
                          color: Color(0xFF6b7280),
                          fontSize: 11,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  // Location met
                  if (contact.locationMet.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.place_outlined,
                              size: 12, color: Color(0xFF6b7280)),
                          const SizedBox(width: 4),
                          Flexible(
                            child: Text(
                              contact.locationMet,
                              style: const TextStyle(
                                color: Color(0xFF6b7280),
                                fontSize: 11,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ),
                  // Interaction count badge
                  if (interactionCount > 0)
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: _buildInteractionBadge(interactionCount, color),
                    ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            // Date (reflects the active ordering: dateMet or last interaction)
            Text(
              orderingDate != null ? _relativeDate(orderingDate) : 'Unknown',
              style: TextStyle(
                color: color,
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// The leading avatar for a timeline tile. Shows [Contact.photoThumbnail]
  /// when the contact has a photo (matching the detail card), and falls back to
  /// a colored circle bearing the contact's initial otherwise.
  Widget _buildAvatar(Contact contact, Color color) {
    if (contact.hasPhoto) {
      return CircleAvatar(
        radius: 20,
        backgroundColor: color.withValues(alpha: 0.15),
        backgroundImage: MemoryImage(contact.photoThumbnail!),
      );
    }
    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        shape: BoxShape.circle,
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Center(
        child: Text(
          // Use the first grapheme cluster, not displayName[0]: indexing by
          // UTF-16 code unit splits a leading emoji/non-BMP character into a
          // lone surrogate, which crashes text layout ("not well-formed
          // UTF-16").
          contact.displayName.isNotEmpty
              ? contact.displayName.characters.first.toUpperCase()
              : '?',
          style: TextStyle(
            color: color,
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }

  Widget _buildInteractionBadge(int count, Color color) {
    final label = '$count ${count == 1 ? 'interaction' : 'interactions'}';
    return Semantics(
      label: label,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: color.withValues(alpha: 0.3)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.history, size: 11, color: color),
            const SizedBox(width: 4),
            // Flexible + ellipsis so the badge shrinks rather than overflowing
            // when the tile's name column is narrow.
            Flexible(
              child: Text(
                label,
                maxLines: 1,
                softWrap: false,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: color,
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
