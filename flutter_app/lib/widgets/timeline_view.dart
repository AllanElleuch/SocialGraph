import 'package:flutter/material.dart';
import '../models/contact.dart';

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

  List<Contact> get _sorted =>
      [...widget.contacts]..sort((a, b) => a.dateMet.compareTo(b.dateMet));

  @override
  Widget build(BuildContext context) {
    if (widget.contacts.isEmpty) {
      return const Center(
        child:
            Text('No contacts', style: TextStyle(color: Color(0xFF94a3b8))),
      );
    }

    final sorted = _sorted;
    final earliest = sorted.first.dateMet;
    final latest = sorted.last.dateMet;

    // Group contacts by year-month
    final groups = <String, List<Contact>>{};
    for (final c in sorted) {
      final key = _monthYearKey(c.dateMet);
      groups.putIfAbsent(key, () => []).add(c);
    }
    final groupKeys = groups.keys.toList();

    return FadeTransition(
      opacity: _fadeIn,
      child: Padding(
        padding: const EdgeInsets.only(top: 100, bottom: 100),
        child: ListView.builder(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
          itemCount: groupKeys.length,
          itemBuilder: (context, index) {
            final key = groupKeys[index];
            final contacts = groups[key]!;
            return _buildMonthGroup(key, contacts, earliest, latest);
          },
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
    final color = _timeColor(contact.dateMet, earliest, latest);

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
            // Avatar
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.15),
                shape: BoxShape.circle,
                border: Border.all(color: color.withValues(alpha: 0.4)),
              ),
              child: Center(
                child: Text(
                  contact.displayName.isNotEmpty
                      ? contact.displayName[0].toUpperCase()
                      : '?',
                  style: TextStyle(
                    color: color,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
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
                ],
              ),
            ),
            const SizedBox(width: 8),
            // Date
            Text(
              _relativeDate(contact.dateMet),
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
}
