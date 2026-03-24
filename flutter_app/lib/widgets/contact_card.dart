import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/contact.dart';

class ContactCard extends StatelessWidget {
  final Contact? contact;
  final VoidCallback onClose;

  const ContactCard({
    super.key,
    required this.contact,
    required this.onClose,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedPositioned(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
      top: 16,
      right: contact != null ? 16 : -340,
      bottom: 16,
      width: 320,
      child: contact != null ? _buildCard() : const SizedBox(),
    );
  }

  Widget _buildCard() {
    final c = contact!;
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
                Expanded(
                  child: Text(
                    c.name,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      height: 1.2,
                    ),
                  ),
                ),
                InkWell(
                  onTap: onClose,
                  borderRadius: BorderRadius.circular(20),
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: const Icon(Icons.close,
                        color: Color(0xFF9ca3af), size: 20),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),

            // Location
            _infoRow(
              Icons.location_on_outlined,
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(c.locationMet,
                      style:
                          const TextStyle(color: Color(0xFF9ca3af), fontSize: 14)),
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
                'Met on ${DateFormat.yMMMd().format(c.dateMet)}',
                style: const TextStyle(color: Color(0xFF9ca3af), fontSize: 14),
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

            // Last Interaction
            if (c.lastInteraction != null) ...[
              const SizedBox(height: 24),
              Container(
                padding: const EdgeInsets.only(top: 16),
                decoration: const BoxDecoration(
                  border: Border(
                      top: BorderSide(color: Color(0xFF333333), width: 1)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'LAST INTERACTION',
                      style: TextStyle(
                        color: Color(0xFF4b5563),
                        fontSize: 10,
                        letterSpacing: 3,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      DateFormat.yMMMd().add_jm().format(c.lastInteraction!),
                      style: const TextStyle(
                          color: Color(0xFF9ca3af), fontSize: 12),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

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
