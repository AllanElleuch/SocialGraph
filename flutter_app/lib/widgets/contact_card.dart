import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/contact.dart';
import '../services/quick_actions_service.dart';
import '../services/relationship_strength.dart';
import '../services/reach_out_service.dart';

class ContactCard extends StatelessWidget {
  final Contact? contact;
  final VoidCallback onClose;
  final VoidCallback? onEdit;

  /// Called when the user logs an interaction (manually or via a quick action).
  /// The parent applies it (`contact.logInteraction(event)`) and persists.
  final void Function(InteractionEvent event)? onLogInteraction;

  /// Injectable for tests; defaults to the real launcher.
  final QuickActionsService quickActions;

  ContactCard({
    super.key,
    required this.contact,
    required this.onClose,
    this.onEdit,
    this.onLogInteraction,
    QuickActionsService? quickActions,
  }) : quickActions = quickActions ?? QuickActionsService();

  @override
  Widget build(BuildContext context) {
    // Responsive width: cap at 320 on wide layouts, but shrink to fit the
    // screen (minus margins) on phones so the card never overflows.
    const margin = 16.0;
    final width = math.min(320.0, MediaQuery.of(context).size.width - margin * 2);
    return AnimatedPositioned(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
      top: 16,
      // When hidden, slide fully off-screen to the right.
      right: contact != null ? margin : -(width + 24),
      bottom: 16,
      width: width,
      child: contact != null ? _buildCard(context) : const SizedBox(),
    );
  }

  /// Builds an [InteractionEvent] with a client-generated id + timestamp and
  /// forwards it to the parent.
  void _log(InteractionType type, {String note = ''}) {
    final cb = onLogInteraction;
    if (cb == null) return;
    final now = DateTime.now();
    cb(InteractionEvent(
      id: 'evt-${now.microsecondsSinceEpoch}',
      date: now,
      type: type,
      note: note,
    ));
  }

  Widget _buildCard(BuildContext context) {
    final c = contact!;
    final now = DateTime.now();
    final score = strengthScore(c, now: now);
    final status = reachOutStatus(c, now: now);

    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF1a1a1a),
        border: Border.all(color: const Color(0xFF333333)),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.5),
            blurRadius: 24,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (c.hasPhoto) ...[
                  CircleAvatar(
                    radius: 22,
                    backgroundColor: const Color(0xFF333333),
                    backgroundImage: MemoryImage(c.photoThumbnail!),
                  ),
                  const SizedBox(width: 12),
                ],
                Expanded(
                  child: Text(
                    c.displayName,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      height: 1.2,
                    ),
                  ),
                ),
                if (onEdit != null)
                  InkWell(
                    onTap: onEdit,
                    borderRadius: BorderRadius.circular(20),
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      child: const Icon(Icons.edit_outlined,
                          color: Color(0xFF9ca3af), size: 20),
                    ),
                  ),
                const SizedBox(width: 8),
                InkWell(
                  onTap: onClose,
                  borderRadius: BorderRadius.circular(20),
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    child: const Icon(Icons.close,
                        color: Color(0xFF9ca3af), size: 20),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Quick actions (only the ones we have data for)
            _buildQuickActions(c),

            const SizedBox(height: 20),

            // Strength meter
            _buildStrengthMeter(score),
            const SizedBox(height: 20),

            // Stay-in-touch status
            _buildReachOut(status),
            const SizedBox(height: 20),

            // Phone / email rows
            if (c.phone.isNotEmpty)
              _infoRow(Icons.phone_outlined, _plainText(c.phone)),
            if (c.phone.isNotEmpty) const SizedBox(height: 16),
            if (c.email.isNotEmpty)
              _infoRow(Icons.email_outlined, _plainText(c.email)),
            if (c.email.isNotEmpty) const SizedBox(height: 16),

            // Location
            _infoRow(
              Icons.location_on_outlined,
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(c.locationMet,
                      style: const TextStyle(
                          color: Color(0xFF9ca3af), fontSize: 14)),
                  if (c.lat != null && c.lng != null)
                    Text(
                      '${c.lat!.toStringAsFixed(4)}, ${c.lng!.toStringAsFixed(4)}',
                      style: const TextStyle(
                          color: Color(0xFF4b5563), fontSize: 10),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Date Met
            _infoRow(
              Icons.calendar_today_outlined,
              Text(
                c.dateMet != null
                    ? 'Met on ${DateFormat.yMMMd().format(c.dateMet!)}'
                    : 'Date met unknown — tap edit to set',
                style: TextStyle(
                  color: c.dateMet != null
                      ? const Color(0xFF9ca3af)
                      : const Color(0xFF6b7280),
                  fontSize: 14,
                ),
              ),
            ),
            const SizedBox(height: 24),

            // Birthday (e.g. imported from the device address book)
            if (c.birthday != null) ...[
              _infoRow(
                Icons.cake_outlined,
                Text(
                  // Year 1900 is the sentinel for "no year recorded".
                  c.birthday!.year == 1900
                      ? DateFormat.MMMMd().format(c.birthday!)
                      : DateFormat.yMMMMd().format(c.birthday!),
                  style: const TextStyle(color: Color(0xFF9ca3af), fontSize: 14),
                ),
              ),
              const SizedBox(height: 24),
            ],

            // Notes
            _sectionHeader(Icons.sticky_note_2_outlined, 'Notes'),
            const SizedBox(height: 8),
            Text(
              c.notes.isNotEmpty ? c.notes : 'No notes yet.',
              style: TextStyle(
                color: c.notes.isNotEmpty
                    ? const Color(0xFF9ca3af)
                    : const Color(0xFF4b5563),
                fontSize: 14,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 24),

            // Tags
            _sectionHeader(Icons.label_outline, 'Tags'),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: c.tags.map((tag) => _tagChip(tag)).toList(),
            ),
            const SizedBox(height: 24),

            // Connections
            _sectionHeader(Icons.people_outline, 'Connections'),
            const SizedBox(height: 8),
            Text(
              '${c.connections.length} mutual connections identified.',
              style: const TextStyle(color: Color(0xFF9ca3af), fontSize: 14),
            ),
            const SizedBox(height: 24),

            // Interaction log
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _sectionHeader(Icons.history, 'Interactions'),
                if (onLogInteraction != null)
                  InkWell(
                    onTap: () => _showLogSheet(context),
                    borderRadius: BorderRadius.circular(6),
                    child: const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.add, color: Color(0xFF818cf8), size: 16),
                          SizedBox(width: 4),
                          Text('Log',
                              style: TextStyle(
                                  color: Color(0xFF818cf8), fontSize: 12)),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            _buildInteractionList(c),
          ],
        ),
      ),
    );
  }

  Widget _buildQuickActions(Contact c) {
    final buttons = <Widget>[];
    if (c.phone.isNotEmpty) {
      buttons.add(_actionButton(Icons.call, 'Call', () {
        quickActions.call(c.phone);
        _log(InteractionType.call);
      }));
      buttons.add(_actionButton(Icons.message_outlined, 'Text', () {
        quickActions.sms(c.phone);
        _log(InteractionType.text);
      }));
    }
    if (c.email.isNotEmpty) {
      buttons.add(_actionButton(Icons.email_outlined, 'Email', () {
        quickActions.email(c.email);
        _log(InteractionType.email);
      }));
    }
    if (buttons.isEmpty) return const SizedBox.shrink();
    return Row(
      children: [
        for (var i = 0; i < buttons.length; i++) ...[
          if (i > 0) const SizedBox(width: 8),
          Expanded(child: buttons[i]),
        ],
      ],
    );
  }

  Widget _actionButton(IconData icon, String label, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: const Color(0xFF6366f1).withValues(alpha: 0.12),
          border:
              Border.all(color: const Color(0xFF6366f1).withValues(alpha: 0.3)),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Column(
          children: [
            Icon(icon, color: const Color(0xFF818cf8), size: 18),
            const SizedBox(height: 4),
            Text(label,
                style: const TextStyle(color: Color(0xFF818cf8), fontSize: 11)),
          ],
        ),
      ),
    );
  }

  Widget _buildStrengthMeter(double score) {
    final label = strengthLabel(score);
    final fraction = (score / 100).clamp(0.0, 1.0);
    final color = score >= 66
        ? const Color(0xFF22c55e)
        : score >= 33
            ? const Color(0xFFf59e0b)
            : const Color(0xFFef4444);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            _sectionHeader(Icons.favorite_outline, 'Relationship strength'),
            Text(label,
                style: TextStyle(
                    color: color, fontSize: 12, fontWeight: FontWeight.w600)),
          ],
        ),
        const SizedBox(height: 8),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: fraction,
            minHeight: 6,
            backgroundColor: const Color(0xFF333333),
            valueColor: AlwaysStoppedAnimation<Color>(color),
          ),
        ),
      ],
    );
  }

  Widget _buildReachOut(ReachOutStatus status) {
    final String text;
    final Color color;
    if (status.dueInDays >= kReachOutOffDueInDays) {
      text = 'Reminders off';
      color = const Color(0xFF6b7280);
    } else if (status.isOverdue) {
      text = 'Overdue by ${-status.dueInDays} days';
      color = const Color(0xFFef4444);
    } else {
      text = 'Reach out in ${status.dueInDays} days';
      color = const Color(0xFF9ca3af);
    }
    return _infoRow(
      Icons.notifications_active_outlined,
      Text(text, style: TextStyle(color: color, fontSize: 14)),
    );
  }

  Widget _buildInteractionList(Contact c) {
    if (c.interactions.isEmpty) {
      return const Text('No interactions logged yet.',
          style: TextStyle(color: Color(0xFF4b5563), fontSize: 13));
    }
    final recent = c.interactions.take(5).toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final e in recent)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(_iconFor(e.type),
                    color: const Color(0xFF6b7280), size: 14),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${_labelFor(e.type)} · ${DateFormat.yMMMd().format(e.date)}',
                        style: const TextStyle(
                            color: Color(0xFF9ca3af), fontSize: 12),
                      ),
                      if (e.note.isNotEmpty)
                        Text(e.note,
                            style: const TextStyle(
                                color: Color(0xFF6b7280), fontSize: 11)),
                    ],
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }

  Future<void> _showLogSheet(BuildContext context) async {
    final type = await showModalBottomSheet<InteractionType>(
      context: context,
      backgroundColor: const Color(0xFF1a1a1a),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final t in InteractionType.values)
              ListTile(
                leading: Icon(_iconFor(t), color: const Color(0xFF818cf8)),
                title: Text(_labelFor(t),
                    style: const TextStyle(color: Color(0xFFe2e8f0))),
                onTap: () => Navigator.of(ctx).pop(t),
              ),
          ],
        ),
      ),
    );
    if (type != null) _log(type);
  }

  IconData _iconFor(InteractionType t) {
    switch (t) {
      case InteractionType.call:
        return Icons.call;
      case InteractionType.text:
        return Icons.message_outlined;
      case InteractionType.email:
        return Icons.email_outlined;
      case InteractionType.meeting:
        return Icons.groups_outlined;
      case InteractionType.note:
        return Icons.sticky_note_2_outlined;
    }
  }

  String _labelFor(InteractionType t) {
    switch (t) {
      case InteractionType.call:
        return 'Call';
      case InteractionType.text:
        return 'Text';
      case InteractionType.email:
        return 'Email';
      case InteractionType.meeting:
        return 'Meeting';
      case InteractionType.note:
        return 'Note';
    }
  }

  Widget _plainText(String text) => Text(text,
      style: const TextStyle(color: Color(0xFF9ca3af), fontSize: 14));

  Widget _infoRow(IconData icon, Widget content) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: const Color(0xFF818cf8), size: 18),
        const SizedBox(width: 12),
        Expanded(child: content),
      ],
    );
  }

  Widget _sectionHeader(IconData icon, String title) {
    return Row(
      children: [
        Icon(icon, color: const Color(0xFF6b7280), size: 14),
        const SizedBox(width: 8),
        Text(
          title.toUpperCase(),
          style: const TextStyle(
            color: Color(0xFF6b7280),
            fontSize: 11,
            fontWeight: FontWeight.w600,
            letterSpacing: 2,
          ),
        ),
      ],
    );
  }

  Widget _tagChip(String tag) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: const Color(0xFF6366f1).withValues(alpha: 0.1),
        border:
            Border.all(color: const Color(0xFF6366f1).withValues(alpha: 0.2)),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        tag,
        style: const TextStyle(color: Color(0xFF818cf8), fontSize: 12),
      ),
    );
  }
}
