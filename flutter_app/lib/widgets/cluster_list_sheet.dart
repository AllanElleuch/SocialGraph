import 'package:flutter/material.dart';

import '../painters/star_style.dart';
import '../services/cluster_summary.dart';

class _P {
  static const sheet = Color(0xFF111317);
  static const border = Color(0xFF2A2D34);
  static const accent = Color(0xFF818CF8);
  static const text = Color(0xFFE2E8F0);
  static const muted = Color(0xFF9CA3AF);
}

/// A bottom sheet listing the Mutuals constellations (tag-groups + Orphans)
/// with their member counts, sorted largest-first. Tapping one focuses it via
/// [onSelect].
class ClusterListSheet extends StatelessWidget {
  final List<ClusterSummary> clusters;
  final ValueChanged<ClusterSummary> onSelect;

  const ClusterListSheet({
    super.key,
    required this.clusters,
    required this.onSelect,
  });

  static Future<void> show(
    BuildContext context, {
    required List<ClusterSummary> clusters,
    required ValueChanged<ClusterSummary> onSelect,
  }) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => ClusterListSheet(clusters: clusters, onSelect: onSelect),
    );
  }

  @override
  Widget build(BuildContext context) {
    final sorted = [...clusters]..sort((a, b) => b.count.compareTo(a.count));
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
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 12, 8),
              child: Row(
                children: [
                  const Icon(Icons.bubble_chart_outlined,
                      color: _P.accent, size: 20),
                  const SizedBox(width: 10),
                  const Text(
                    'Constellations',
                    style: TextStyle(
                      color: _P.text,
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const Spacer(),
                  Text(
                    '${clusters.length}',
                    style: const TextStyle(color: _P.muted, fontSize: 14),
                  ),
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close, color: _P.muted, size: 20),
                  ),
                ],
              ),
            ),
            const Divider(color: _P.border, height: 1),
            Flexible(
              child: sorted.isEmpty
                  ? const Padding(
                      padding: EdgeInsets.all(28),
                      child: Text('No constellations yet',
                          style: TextStyle(color: _P.muted)),
                    )
                  : ListView.separated(
                      padding: const EdgeInsets.symmetric(vertical: 6),
                      itemCount: sorted.length,
                      separatorBuilder: (_, __) => const Divider(
                          color: _P.border, height: 1, indent: 52),
                      itemBuilder: (context, i) {
                        final c = sorted[i];
                        return _row(context, c);
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _row(BuildContext context, ClusterSummary c) {
    final color = clusterColor(c.colorIndex);
    return InkWell(
      onTap: () {
        Navigator.of(context).pop();
        onSelect(c);
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            Container(
              width: 12,
              height: 12,
              decoration: BoxDecoration(
                color: c.isOrphans ? _P.muted : color,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: (c.isOrphans ? _P.muted : color)
                        .withValues(alpha: 0.5),
                    blurRadius: 6,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Text(
                c.tag,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: _P.text,
                  fontSize: 15,
                  fontStyle: c.isOrphans ? FontStyle.italic : FontStyle.normal,
                ),
              ),
            ),
            Text(
              '${c.count}',
              style: const TextStyle(
                color: _P.muted,
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(width: 8),
            const Icon(Icons.chevron_right, color: _P.muted, size: 18),
          ],
        ),
      ),
    );
  }
}
