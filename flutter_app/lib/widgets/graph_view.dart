import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import '../models/contact.dart';
import '../models/graph_node.dart';
import '../services/force_simulation.dart';
import '../painters/graph_painter.dart';

class GraphView extends StatefulWidget {
  final List<Contact> contacts;
  final PivotType pivot;
  final ValueChanged<Contact> onSelectContact;

  const GraphView({
    super.key,
    required this.contacts,
    required this.pivot,
    required this.onSelectContact,
  });

  @override
  State<GraphView> createState() => _GraphViewState();
}

class _GraphViewState extends State<GraphView>
    with SingleTickerProviderStateMixin {
  late List<GraphNode> _nodes;
  late List<GraphLink> _links;
  ForceSimulation? _simulation;
  late AnimationController _animController;

  final TransformationController _transformController =
      TransformationController();

  GraphNode? _draggedNode;
  Offset? _lastFocalPoint;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 10),
    )..addListener(_onTick);

    _buildGraph();
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
        name: c.name,
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
        ..sort((a, b) => a.dateMet.compareTo(b.dateMet));
      for (int i = 0; i < sorted.length - 1; i++) {
        _links.add(GraphLink(
            sourceId: sorted[i].id, targetId: sorted[i + 1].id, type: 'time'));
      }
    }

    _simulation = ForceSimulation(
      nodes: _nodes,
      links: _links,
      linkDistance: 150,
      chargeStrength: -400,
      collisionRadius: 60,
      centerX: cx,
      centerY: cy,
    );

    _animController.repeat();
  }

  void _onTick() {
    if (_simulation != null && _simulation!.isActive) {
      _simulation!.tick();
      setState(() {});
    } else {
      // Keep ticking at reduced rate for drag interactions
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

    final times = widget.contacts.map((c) => c.dateMet.millisecondsSinceEpoch.toDouble());
    final minTime = times.reduce(min);
    final maxTime = times.reduce(max);

    return Listener(
      onPointerDown: _onPointerDown,
      onPointerMove: _onPointerMove,
      onPointerUp: _onPointerUp,
      child: InteractiveViewer(
        transformationController: _transformController,
        boundaryMargin: const EdgeInsets.all(double.infinity),
        minScale: 0.1,
        maxScale: 8.0,
        panEnabled: _draggedNode == null,
        child: CustomPaint(
          size: Size.infinite,
          painter: GraphPainter(
            nodes: _nodes,
            links: _links,
            pivot: widget.pivot,
            minTime: minTime,
            maxTime: maxTime,
          ),
        ),
      ),
    );
  }
}
