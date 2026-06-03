import 'dart:math';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import '../models/contact.dart';
import '../models/graph_node.dart';
import '../services/force_simulation.dart';
import '../painters/graph_painter.dart';
import '../painters/star_style.dart';
import '../painters/starfield_painter.dart';

class GraphView extends StatefulWidget {
  final List<Contact> contacts;
  final PivotType pivot;
  final ValueChanged<Contact> onSelectContact;

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

  /// Constellation (connected-component) index per contact id, recomputed
  /// whenever the graph is (re)built.
  Map<String, int> _clusters = {};
  ForceSimulation? _simulation;
  late AnimationController _animController;

  final TransformationController _transformController =
      TransformationController();

  GraphNode? _draggedNode;
  Offset? _lastFocalPoint;

  bool _graphBuilt = false;

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

    if (widget.pivot == PivotType.mutual) {
      for (final c in widget.contacts) {
        for (final connId in c.connections) {
          if (c.id.compareTo(connId) < 0) {
            _links.add(
                GraphLink(sourceId: c.id, targetId: connId, type: 'connection'));
          }
        }
      }
    } else if (widget.pivot == PivotType.time) {
      final sorted = [...widget.contacts]
        ..sort((a, b) => (a.dateMet?.millisecondsSinceEpoch ?? 0)
            .compareTo(b.dateMet?.millisecondsSinceEpoch ?? 0));
      for (int i = 0; i < sorted.length - 1; i++) {
        _links.add(GraphLink(
            sourceId: sorted[i].id, targetId: sorted[i + 1].id, type: 'time'));
      }
    }

    _clusters = assignClusters(_nodes.map((n) => n.id).toList(), _links);

    _simulation = ForceSimulation(
      nodes: _nodes,
      links: _links,
      linkDistance: 150,
      chargeStrength: -400,
      collisionRadius: 60,
      centerX: cx,
      centerY: cy,
    );

    // A new node set (e.g. a filter change) snaps back to an overview centered
    // on the cluster; auto-fit then tracks the layout until the user interacts.
    _autoFit = true;
    _fitToNodes();
    _decodePhotos();
    _animController.repeat();
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
    final scale = min(availW / bboxW, availH / bboxH).clamp(0.1, 1.6);
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
    final node = _hitTest(event.localPosition);
    if (node != null) {
      _draggedNode = node;
      // Grabbing a node is manual control; stop auto-framing the view.
      _autoFit = false;
      node.fx = node.x;
      node.fy = node.y;
      _simulation?.setAlphaTarget(0.3);
      _lastFocalPoint = event.localPosition;
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
    if (_draggedNode != null) {
      // Check if it was a tap (not a drag)
      if (_lastFocalPoint != null) {
        final delta = (event.localPosition - _lastFocalPoint!).distance;
        if (delta < 5) {
          widget.onSelectContact(_draggedNode!.data);
        }
      }
      _draggedNode!.fx = null;
      _draggedNode!.fy = null;
      _draggedNode = null;
      _simulation?.setAlphaTarget(0);
    }
    _lastFocalPoint = null;
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
            minScale: 0.1,
            maxScale: 8.0,
            panEnabled: _draggedNode == null,
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
                viewTransform: _transformController,
                twinkle: _animController,
              ),
            ),
          ),
        ),
      ],
    );
  }
}
