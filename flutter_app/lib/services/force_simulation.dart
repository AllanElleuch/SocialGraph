import 'dart:math';
import '../models/graph_node.dart';

class ForceSimulation {
  final List<GraphNode> nodes;
  final List<GraphLink> links;
  double alpha = 1.0;
  double alphaTarget = 0.0;
  double alphaDecay = 0.0228; // 1 - pow(0.001, 1/300)
  double alphaMin = 0.001;
  double velocityDecay = 0.6;

  // Force parameters
  double linkDistance;
  double chargeStrength;
  double collisionRadius;
  double centerX;
  double centerY;

  ForceSimulation({
    required this.nodes,
    required this.links,
    this.linkDistance = 150,
    this.chargeStrength = -400,
    this.collisionRadius = 60,
    this.centerX = 0,
    this.centerY = 0,
  });

  bool get isActive => alpha >= alphaMin;

  void tick() {
    alpha += (alphaTarget - alpha) * alphaDecay;
    if (alpha < alphaMin) {
      alpha = alphaMin;
      return;
    }

    _applyLinkForce();
    _applyChargeForce();
    _applyCenterForce();
    _applyCollisionForce();
    _updatePositions();
  }

  void _applyLinkForce() {
    final nodeMap = {for (var n in nodes) n.id: n};

    for (final link in links) {
      final source = nodeMap[link.sourceId];
      final target = nodeMap[link.targetId];
      if (source == null || target == null) continue;

      double dx = target.x - source.x;
      double dy = target.y - source.y;
      double dist = sqrt(dx * dx + dy * dy);
      if (dist == 0) dist = 0.001;

      final strength = alpha * (dist - linkDistance) / dist * 0.3;
      dx *= strength;
      dy *= strength;

      source.vx += dx;
      source.vy += dy;
      target.vx -= dx;
      target.vy -= dy;
    }
  }

  void _applyChargeForce() {
    for (int i = 0; i < nodes.length; i++) {
      for (int j = i + 1; j < nodes.length; j++) {
        double dx = nodes[j].x - nodes[i].x;
        double dy = nodes[j].y - nodes[i].y;
        double dist = sqrt(dx * dx + dy * dy);
        if (dist == 0) {
          dist = 0.001;
          dx = 0.001;
        }

        final force = alpha * chargeStrength / (dist * dist);
        final fx = dx / dist * force;
        final fy = dy / dist * force;

        nodes[i].vx -= fx;
        nodes[i].vy -= fy;
        nodes[j].vx += fx;
        nodes[j].vy += fy;
      }
    }
  }

  void _applyCenterForce() {
    double cx = 0, cy = 0;
    for (final node in nodes) {
      cx += node.x;
      cy += node.y;
    }
    cx /= nodes.length;
    cy /= nodes.length;

    final strength = alpha * 0.1;
    for (final node in nodes) {
      node.vx -= (cx - centerX) * strength;
      node.vy -= (cy - centerY) * strength;
    }
  }

  void _applyCollisionForce() {
    for (int i = 0; i < nodes.length; i++) {
      for (int j = i + 1; j < nodes.length; j++) {
        double dx = nodes[j].x - nodes[i].x;
        double dy = nodes[j].y - nodes[i].y;
        double dist = sqrt(dx * dx + dy * dy);
        if (dist == 0) dist = 0.001;

        final minDist = collisionRadius * 2;
        if (dist < minDist) {
          final force = (minDist - dist) / dist * 0.5;
          final fx = dx * force;
          final fy = dy * force;
          nodes[i].vx -= fx;
          nodes[i].vy -= fy;
          nodes[j].vx += fx;
          nodes[j].vy += fy;
        }
      }
    }
  }

  void _updatePositions() {
    for (final node in nodes) {
      if (node.fx != null) {
        node.x = node.fx!;
        node.vx = 0;
      } else {
        node.vx *= velocityDecay;
        node.x += node.vx;
      }

      if (node.fy != null) {
        node.y = node.fy!;
        node.vy = 0;
      } else {
        node.vy *= velocityDecay;
        node.y += node.vy;
      }
    }
  }

  void restart({double? newAlphaTarget}) {
    alpha = 1.0;
    alphaTarget = newAlphaTarget ?? 0.0;
  }

  void setAlphaTarget(double target) {
    alphaTarget = target;
    if (alpha < alphaMin) alpha = alphaMin + 0.01;
  }
}
