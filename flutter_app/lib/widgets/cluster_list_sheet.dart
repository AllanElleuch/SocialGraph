import 'package:flutter/material.dart';

import '../painters/star_style.dart';
import '../painters/cluster_layouts.dart';
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

  /// The rendering currently used by each cluster (keyed by tag), shown as a
  /// chip on each row.
  final Map<String, ClusterLayout> effectiveLayouts;

  /// Called to change a cluster's rendering. A null layout means "Auto" (clear
  /// the override and revert to the per-run / default choice).
  final void Function(String tag, ClusterLayout? layout)? onPickLayout;

  const ClusterListSheet({
    super.key,
    required this.clusters,
    required this.onSelect,
    this.effectiveLayouts = const {},
    this.onPickLayout,
  });

  static Future<void> show(
    BuildContext context, {
    required List<ClusterSummary> clusters,
    required ValueChanged<ClusterSummary> onSelect,
    Map<String, ClusterLayout> effectiveLayouts = const {},
    void Function(String tag, ClusterLayout? layout)? onPickLayout,
  }) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => ClusterListSheet(
        clusters: clusters,
        onSelect: onSelect,
        effectiveLayouts: effectiveLayouts,
        onPickLayout: onPickLayout,
      ),
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
    return Row(
      children: [
        // Left part focuses the cluster (separate hit area from the button).
        Expanded(
          child: InkWell(
            onTap: () {
              Navigator.of(context).pop();
              onSelect(c);
            },
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 8, 12),
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
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          c.tag,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: _P.text,
                            fontSize: 15,
                            fontStyle: c.isOrphans
                                ? FontStyle.italic
                                : FontStyle.normal,
                          ),
                        ),
                        Text(
                          '${c.count} ${c.count == 1 ? 'star' : 'stars'}',
                          style:
                              const TextStyle(color: _P.muted, fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        // Distinct, obviously-tappable rendering button.
        Padding(
          padding: const EdgeInsets.only(right: 12),
          child: _renderingButton(context, c),
        ),
      ],
    );
  }

  /// A clearly-tappable, filled "Style" button showing the cluster's current
  /// rendering; tapping opens a menu to pick a different one (or "Auto").
  Widget _renderingButton(BuildContext context, ClusterSummary c) {
    final layout = effectiveLayouts[c.tag] ?? ClusterLayout.sunflower;
    final label = clusterLayoutLabel(layout);
    final button = Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
      decoration: BoxDecoration(
        color: _P.accent.withValues(alpha: onPickLayout == null ? 0.12 : 0.20),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: _P.accent.withValues(alpha: 0.6)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.auto_awesome, color: _P.accent, size: 15),
          const SizedBox(width: 6),
          Text(
            label,
            style: const TextStyle(
                color: _P.accent, fontSize: 13, fontWeight: FontWeight.w700),
          ),
          if (onPickLayout != null) ...[
            const SizedBox(width: 2),
            const Icon(Icons.arrow_drop_down, color: _P.accent, size: 18),
          ],
        ],
      ),
    );

    if (onPickLayout == null) return button;

    return PopupMenuButton<ClusterLayout?>(
      tooltip: 'Change rendering',
      color: _P.sheet,
      position: PopupMenuPosition.under,
      onSelected: (value) => onPickLayout!(c.tag, value),
      itemBuilder: (ctx) => [
        const PopupMenuItem<ClusterLayout?>(
          value: null,
          child: Text('Auto (per run)', style: TextStyle(color: _P.muted)),
        ),
        const PopupMenuDivider(),
        for (final l in ClusterLayout.values)
          if (!(c.isOrphans && l == ClusterLayout.figure))
            PopupMenuItem<ClusterLayout?>(
              value: l,
              child: Row(
                children: [
                  if (l == layout)
                    const Icon(Icons.check, color: _P.accent, size: 16)
                  else
                    const SizedBox(width: 16),
                  const SizedBox(width: 8),
                  Text(
                    clusterLayoutLabel(l),
                    style: TextStyle(
                      color: l == layout ? _P.accent : _P.text,
                      fontWeight:
                          l == layout ? FontWeight.w700 : FontWeight.normal,
                    ),
                  ),
                ],
              ),
            ),
      ],
      child: button,
    );
  }
}
