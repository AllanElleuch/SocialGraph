import 'dart:math';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import '../models/contact.dart';
import '../models/graph_node.dart';
import '../services/force_simulation.dart';
import '../services/relatives.dart';
import '../services/tag_rules.dart';
import '../painters/graph_painter.dart';
import '../painters/star_style.dart';
import '../painters/starfield_painter.dart';
import '../painters/constellation_layout.dart';

class GraphView extends StatefulWidget {
  final List<Contact> contacts;
  final PivotType pivot;
  final ValueChanged<Contact> onSelectContact;

  /// Called when a constellation's tag label is double-tapped (Mutuals view),
  /// to open that tag's detail / bulk-tagging screen. Null disables it.
  final void Function(String tag)? onOpenTag;

  /// How contact stars are tinted (relationship temperature vs constellation).
  final StarColorMode starColorMode;

  /// The currently-selected contact id; its constellation is illuminated while
  /// the rest of the sky dims.
  final String? selectedId;

  const GraphView({
    super.key,
    required this.contacts,
    required this.pivot,
    required this.onSelectContact,
    this.onOpenTag,
    this.starColorMode = StarColorMode.temperature,
    this.selectedId,
  });

  @override
  State<GraphView> createState() => _GraphViewState();
}

class _GraphViewState extends State<GraphView>
    with SingleTickerProviderStateMixin {
  late List<GraphNode> _nodes;
  late List<GraphLink> _links;

  /// Group index per contact id (tag-constellation in mutual view, connected
  /// component otherwise), recomputed whenever the graph is (re)built.
  Map<String, int> _clusters = {};

  /// Placed tag-groups for drawing constellation names (mutual view only).
  List<ConstellationGroup> _constellationLabels = const [];

  /// Relationship label per link (aligned with [_links]): the tags the two
  /// endpoints share, e.g. "Work · Gym". Empty string = no shared tags.
  List<String> _edgeLabels = const [];
  ForceSimulation? _simulation;
  late AnimationController _animController;

  final TransformationController _transformController =
      TransformationController();

  GraphNode? _draggedNode;

  /// The node under the most recent pointer-down, used to turn a press-release
  /// without movement into a selection (a tap) even while panning is enabled.
  GraphNode? _pressedNode;
  Offset? _lastFocalPoint;

  /// Time and position of the last tap on empty space, used to detect a
  /// double-tap on a constellation label (which opens its tag).
  DateTime? _lastEmptyTapTime;
  Offset? _lastEmptyTapPos;

  bool _graphBuilt = false;

  /// When true, the Mutuals view overlays extra edges between contacts that
  /// share a last name. Off by default; toggled via the in-view "Family links"
  /// button. Purely visual — does not change saved data.
  bool _showFamilyLinks = false;

  /// While true, the view keeps the current node set framed and centered as the
  /// layout settles (so a filter snaps to an overview of the cluster). Turns off
  /// as soon as the user pans/zooms or grabs a node, and back on when the filter
  /// changes (a fresh [_buildGraph]).
  bool _autoFit = true;

  /// Decoded contact thumbnails, keyed by contact id, drawn inside their graph
  /// node. Populated asynchronously; nodes show a colored circle until ready.
  final Map<String, ui.Image> _photos = {};

  /// Contact ids whose thumbnail decode is currently in flight, so concurrent
  /// rebuilds don't kick off duplicate decodes for the same contact.
  final Set<String> _decoding = {};

  /// Coalesces the many per-image decode completions into at most one repaint
  /// per frame instead of one [setState] per decoded photo.
  bool _repaintScheduled = false;

  @override
  void initState() {
    super.initState();
    _nodes = [];
    _links = [];
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 10),
    )..addListener(_onTick);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_graphBuilt) {
      _graphBuilt = true;
      _buildGraph();
    }
  }

  @override
  void didUpdateWidget(GraphView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.contacts != widget.contacts ||
        oldWidget.pivot != widget.pivot) {
      _buildGraph();
    }
  }

  void _buildGraph() {
    if (widget.pivot == PivotType.mutual) {
      _buildConstellationSky();
    } else {
      _buildForceGraph();
    }

    // A new node set (e.g. a filter change) snaps back to an overview centered
    // on the cluster; auto-fit then tracks the layout until the user interacts.
    _autoFit = true;
    _fitToNodes();
    _decodePhotos();
    _animController.repeat();
  }

  /// Mutual view: a stable, recognizable night sky. Each tag becomes a real
  /// constellation pattern; figure lines connect its stars; untagged contacts
  /// gather in a loose band. Positions are deterministic, so there's no force
  /// relaxation (no simulation).
  void _buildConstellationSky() {
    // The "Imported" tag is metadata only — never group people by it. A
    // contact with only that tag has no linking tag and lands in the loose band.
    final items = widget.contacts
        .map((c) => (id: c.id, tag: primaryLinkingTag(c.tags)))
        .toList();
    final sky = computeConstellationSky(items);

    _nodes = widget.contacts.map((c) {
      final p = sky.positions[c.id] ?? Offset.zero;
      return GraphNode(
          id: c.id, name: c.displayName, data: c, x: p.dx, y: p.dy);
    }).toList();
    _links = sky.lines
        .map((l) =>
            GraphLink(sourceId: l.a, targetId: l.b, type: 'connection'))
        .toList();
    _clusters = sky.groupIndex;
    _constellationLabels = sky.groups;

    // Label each line with the tags its two endpoints share (joined inline).
    final byId = {for (final c in widget.contacts) c.id: c};
    _edgeLabels = _links.map((l) {
      final a = byId[l.sourceId];
      final b = byId[l.targetId];
      if (a == null || b == null) return '';
      // Exclude the Imported tag from relationship labels.
      return sharedRelationLabel(linkingTags(a.tags), linkingTags(b.tags));
    }).toList();

    // Optional overlay: connect same-last-name contacts across the sky.
    if (_showFamilyLinks) {
      final family = sameLastNameLinks(widget.contacts);
      for (final link in family) {
        _links.add(
            GraphLink(sourceId: link.a, targetId: link.b, type: 'connection'));
      }
      _edgeLabels = [..._edgeLabels, for (final _ in family) ''];
    }

    _simulation = null;
  }

  /// Non-mutual pivots keep the force-directed layout.
  void _buildForceGraph() {
    final rng = Random();
    final size = MediaQuery.of(context).size;
    final cx = size.width / 2;
    final cy = size.height / 2;

    _nodes = widget.contacts.map((c) {
      return GraphNode(
        id: c.id,
        name: c.displayName,
        data: c,
        x: cx + (rng.nextDouble() - 0.5) * 200,
        y: cy + (rng.nextDouble() - 0.5) * 200,
      );
    }).toList();

    _links = [];
    if (widget.pivot == PivotType.time) {
      final sorted = [...widget.contacts]
        ..sort((a, b) => (a.dateMet?.millisecondsSinceEpoch ?? 0)
            .compareTo(b.dateMet?.millisecondsSinceEpoch ?? 0));
      for (int i = 0; i < sorted.length - 1; i++) {
        _links.add(GraphLink(
            sourceId: sorted[i].id, targetId: sorted[i + 1].id, type: 'time'));
      }
    }

    _clusters = assignClusters(_nodes.map((n) => n.id).toList(), _links);
    _constellationLabels = const [];
    _edgeLabels = const [];

    _simulation = ForceSimulation(
      nodes: _nodes,
      links: _links,
      linkDistance: 150,
      chargeStrength: -400,
      collisionRadius: 60,
      centerX: cx,
      centerY: cy,
    );
  }

  /// Frames all current nodes centered in the visible band (between the header
  /// and the bottom controls) at a scale that fits the whole cluster, so the
  /// user always starts from an overview they can zoom into. No-op when there
  /// are no nodes.
  void _fitToNodes() {
    if (_nodes.isEmpty || !mounted) return;
    final size = MediaQuery.of(context).size;

    var minX = _nodes.first.x, maxX = _nodes.first.x;
    var minY = _nodes.first.y, maxY = _nodes.first.y;
    for (final n in _nodes) {
      if (n.x < minX) minX = n.x;
      if (n.x > maxX) maxX = n.x;
      if (n.y < minY) minY = n.y;
      if (n.y > maxY) maxY = n.y;
    }

    // Pad the bounds so stars (and their glow) aren't flush to the edges.
    const nodePad = 48.0;
    final bboxW = (maxX - minX) + nodePad * 2;
    final bboxH = (maxY - minY) + nodePad * 2;
    final cx = (minX + maxX) / 2;
    final cy = (minY + maxY) / 2;

    // Leave room for the floating header (top) and controls/legend (bottom).
    const topInset = 120.0, bottomInset = 150.0, sideInset = 28.0;
    final availW = (size.width - sideInset * 2).clamp(50.0, double.infinity);
    final availH =
        (size.height - topInset - bottomInset).clamp(50.0, double.infinity);

    // Fit the whole cluster; clamp so a tiny set isn't zoomed in absurdly.
    final scale = min(availW / bboxW, availH / bboxH).clamp(0.02, 1.6);
    final target = Offset(size.width / 2, topInset + availH / 2);

    // M = translate(target) · scale · translate(-center): maps the cluster
    // center to the visible band's center at the fitted scale.
    _transformController.value =
        Matrix4.translationValues(target.dx, target.dy, 0) *
            Matrix4.diagonal3Values(scale, scale, 1) *
            Matrix4.translationValues(-cx, -cy, 0);
  }

  /// Decodes thumbnails for any photo contacts not already cached or in flight,
  /// and disposes cached images for contacts that have gone away.
  void _decodePhotos() {
    final liveIds = widget.contacts.map((c) => c.id).toSet();
    final stale = _photos.keys.where((id) => !liveIds.contains(id)).toList();
    for (final id in stale) {
      _photos.remove(id)?.dispose();
    }
    for (final c in widget.contacts) {
      if (!c.hasPhoto) continue;
      if (_photos.containsKey(c.id) || _decoding.contains(c.id)) continue;
      _decoding.add(c.id);
      _decodeOne(c.id, c.photoThumbnail!);
    }
  }

  Future<void> _decodeOne(String id, Uint8List bytes) async {
    try {
      final codec = await ui.instantiateImageCodec(bytes);
      final frame = await codec.getNextFrame();
      if (!mounted) {
        frame.image.dispose();
        return;
      }
      _photos[id] = frame.image;
      _scheduleRepaint();
    } catch (_) {
      // Undecodable image (corrupt/unsupported) — the node keeps its fallback
      // colored circle.
    } finally {
      _decoding.remove(id);
    }
  }

  /// Requests a single repaint on the next frame, collapsing bursts of decode
  /// completions so we don't call [setState] hundreds of times.
  void _scheduleRepaint() {
    if (_repaintScheduled || !mounted) return;
    _repaintScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _repaintScheduled = false;
      if (mounted) setState(() {});
    });
  }

  void _onTick() {
    if (_simulation != null && _simulation!.isActive) {
      _simulation!.tick();
      // Keep the cluster framed as the layout expands, until the user takes
      // over with a pan/zoom or a node drag.
      if (_autoFit) _fitToNodes();
      setState(() {});
    }
  }

  GraphNode? _hitTest(Offset localPosition) {
    // Transform the position back through the current transform
    final matrix = _transformController.value;
    final invertedMatrix = Matrix4.tryInvert(matrix);
    if (invertedMatrix == null) return null;

    final transformed = MatrixUtils.transformPoint(invertedMatrix, localPosition);

    for (final node in _nodes) {
      final dx = transformed.dx - node.x;
      final dy = transformed.dy - node.y;
      if (dx * dx + dy * dy <= 14 * 14 * 4) {
        // slightly larger hit area
        return node;
      }
    }
    return null;
  }

  void _onPointerDown(PointerDownEvent event) {
    _lastFocalPoint = event.localPosition;
    final node = _hitTest(event.localPosition);
    _pressedNode = node;
    // Node *dragging* only applies to the force-directed layout. In the fixed
    // constellation sky (no simulation) every press starts a pan; a star is
    // selected by a tap (handled in _onPointerUp), so dragging from anywhere —
    // empty space or a star — pans the view.
    if (node != null && _simulation != null) {
      _draggedNode = node;
      _autoFit = false; // grabbing a node is manual control
      node.fx = node.x;
      node.fy = node.y;
      _simulation?.setAlphaTarget(0.3);
    }
  }

  void _onPointerMove(PointerMoveEvent event) {
    if (_draggedNode != null) {
      final matrix = _transformController.value;
      final invertedMatrix = Matrix4.tryInvert(matrix);
      if (invertedMatrix == null) return;

      final transformed =
          MatrixUtils.transformPoint(invertedMatrix, event.localPosition);
      _draggedNode!.fx = transformed.dx;
      _draggedNode!.fy = transformed.dy;
      _draggedNode!.x = transformed.dx;
      _draggedNode!.y = transformed.dy;
      setState(() {});
    }
  }

  void _onPointerUp(PointerUpEvent event) {
    final start = _lastFocalPoint;
    final movedLittle =
        start == null || (event.localPosition - start).distance < 5;

    if (_draggedNode != null) {
      if (movedLittle) widget.onSelectContact(_draggedNode!.data);
      _draggedNode!.fx = null;
      _draggedNode!.fy = null;
      _draggedNode = null;
      _simulation?.setAlphaTarget(0);
    } else if (_pressedNode != null && movedLittle) {
      // A tap on a star (no pan) selects it.
      widget.onSelectContact(_pressedNode!.data);
    } else if (movedLittle) {
      // A tap on empty space — may be a double-tap on a tag label.
      _handleEmptyTap(event.localPosition);
    }
    _pressedNode = null;
    _lastFocalPoint = null;
  }

  /// Detects a double-tap on empty space and, if it lands on a constellation's
  /// tag label, opens that tag via [GraphView.onOpenTag].
  void _handleEmptyTap(Offset localPos) {
    final onOpenTag = widget.onOpenTag;
    if (onOpenTag == null || _constellationLabels.isEmpty) return;

    final now = DateTime.now();
    final prevTime = _lastEmptyTapTime;
    final prevPos = _lastEmptyTapPos;
    final isDoubleTap = prevTime != null &&
        prevPos != null &&
        now.difference(prevTime).inMilliseconds < 300 &&
        (localPos - prevPos).distance < 40;

    if (isDoubleTap) {
      _lastEmptyTapTime = null;
      _lastEmptyTapPos = null;
      // Prefer an edge under the tap (a tag linking two nodes); fall back to a
      // constellation name label.
      final tag = _edgeTagAt(localPos) ?? _tagLabelAt(localPos);
      if (tag != null && tag.isNotEmpty) onOpenTag(tag);
    } else {
      _lastEmptyTapTime = now;
      _lastEmptyTapPos = localPos;
    }
  }

  /// The shared tag of the graph edge nearest [localPos] (screen coords), or
  /// null when the tap isn't on a tag-bearing edge. An edge's tag is the first
  /// tag both its endpoints carry; family-link edges (no shared tag) are
  /// ignored. Works in content space so it's correct at any pan/zoom.
  String? _edgeTagAt(Offset localPos) {
    if (_links.isEmpty) return null;
    final matrix = _transformController.value;
    final inverted = Matrix4.tryInvert(matrix);
    if (inverted == null) return null;
    final content = MatrixUtils.transformPoint(inverted, localPos);
    final scale = matrix.getMaxScaleOnAxis();
    if (scale <= 0) return null;

    final threshold = 24 / scale; // forgiving, constant-on-screen hit width
    final posById = {for (final n in _nodes) n.id: Offset(n.x, n.y)};
    final byId = {for (final c in widget.contacts) c.id: c};

    String? best;
    var bestDistance = double.infinity;
    for (final link in _links) {
      final a = posById[link.sourceId];
      final b = posById[link.targetId];
      if (a == null || b == null) continue;
      final distance = distanceToSegment(content, a, b);
      if (distance >= threshold || distance >= bestDistance) continue;
      final ca = byId[link.sourceId];
      final cb = byId[link.targetId];
      if (ca == null || cb == null) continue;
      final shared = ca.tags.firstWhere(
        (t) => cb.tags.contains(t),
        orElse: () => '',
      );
      if (shared.isNotEmpty) {
        bestDistance = distance;
        best = shared;
      }
    }
    return best;
  }

  /// The tag of the constellation label nearest [localPos] (screen coords),
  /// or null when the tap isn't close to any label. Works in content space so
  /// it's correct at any pan/zoom.
  String? _tagLabelAt(Offset localPos) {
    final matrix = _transformController.value;
    final inverted = Matrix4.tryInvert(matrix);
    if (inverted == null) return null;
    final content = MatrixUtils.transformPoint(inverted, localPos);
    final scale = matrix.getMaxScaleOnAxis();
    return constellationTagAt(content, scale, _constellationLabels);
  }

  @override
  void dispose() {
    for (final image in _photos.values) {
      image.dispose();
    }
    _photos.clear();
    _animController.dispose();
    _transformController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.contacts.isEmpty) {
      return const Center(
        child: Text('No contacts', style: TextStyle(color: Color(0xFF94a3b8))),
      );
    }

    final times = widget.contacts
        .map((c) => c.dateMet?.millisecondsSinceEpoch.toDouble())
        .whereType<double>();
    final minTime = times.isEmpty ? 0.0 : times.reduce(min);
    final maxTime = times.isEmpty ? 0.0 : times.reduce(max);

    // Allow zooming in until a single node more than fills the screen,
    // regardless of how many nodes there are. A node's core is at most
    // `kNodeBaseRadius + kStrengthRadiusFactor` content px, so the scale that
    // makes its diameter ≈ 1.6× the screen's short side is the cap we want.
    // minScale is low enough to frame a huge sky as an overview.
    const maxNodeRadius = kNodeBaseRadius + kStrengthRadiusFactor;
    final shortestSide = MediaQuery.of(context).size.shortestSide;
    final maxScale =
        (shortestSide * 1.6 / (2 * maxNodeRadius)).clamp(8.0, 60.0);

    return Stack(
      children: [
        // Fixed deep-space backdrop (not transformed by the viewer).
        Positioned.fill(
          child: CustomPaint(
            painter: StarfieldPainter(twinkle: _animController),
          ),
        ),
        Listener(
          onPointerDown: _onPointerDown,
          onPointerMove: _onPointerMove,
          onPointerUp: _onPointerUp,
          child: InteractiveViewer(
            transformationController: _transformController,
            boundaryMargin: const EdgeInsets.all(double.infinity),
            minScale: 0.02,
            maxScale: maxScale,
            // The fixed constellation sky always pans (drag anywhere, incl.
            // empty space); only the force layout disables pan mid node-drag.
            panEnabled: _simulation == null || _draggedNode == null,
            // A real pan/zoom hands control to the user; stop auto-framing so we
            // never fight their gesture.
            onInteractionUpdate: (_) => _autoFit = false,
            child: CustomPaint(
              size: Size.infinite,
              painter: GraphPainter(
                nodes: _nodes,
                links: _links,
                pivot: widget.pivot,
                minTime: minTime,
                maxTime: maxTime,
                photos: _photos,
                clusters: _clusters,
                starColorMode: widget.starColorMode,
                selectedId: widget.selectedId,
                constellationLabels: _constellationLabels,
                edgeLabels: _edgeLabels,
                viewTransform: _transformController,
                twinkle: _animController,
              ),
            ),
          ),
        ),
        // Mutuals-only overlay toggle: draw edges between same-last-name
        // contacts. Disabled by default; tap to enable.
        if (widget.pivot == PivotType.mutual)
          Positioned(
            left: 16,
            bottom: 104,
            child: _FamilyLinksToggle(
              enabled: _showFamilyLinks,
              onTap: _toggleFamilyLinks,
            ),
          ),
      ],
    );
  }

  void _toggleFamilyLinks() {
    setState(() {
      _showFamilyLinks = !_showFamilyLinks;
      if (widget.pivot == PivotType.mutual) _buildConstellationSky();
    });
  }
}

/// A compact pill toggle for the Mutuals-view same-last-name edge overlay.
class _FamilyLinksToggle extends StatelessWidget {
  final bool enabled;
  final VoidCallback onTap;

  const _FamilyLinksToggle({required this.enabled, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: enabled
              ? const Color(0xFF4f46e5)
              : const Color(0xFF1a1a1a).withValues(alpha: 0.85),
          borderRadius: BorderRadius.circular(100),
          border: Border.all(color: const Color(0xFF333333)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.family_restroom,
                size: 16,
                color: enabled ? Colors.white : const Color(0xFF9ca3af)),
            const SizedBox(width: 6),
            Text(
              'Family links',
              style: TextStyle(
                color: enabled ? Colors.white : const Color(0xFF9ca3af),
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
