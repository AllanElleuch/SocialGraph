import 'dart:math' as math;
import 'package:flutter/material.dart';

import '../models/graph_node.dart';

/// How contact "stars" are tinted in the constellation (mutuals) view. The user
/// chooses between these in Settings.
enum StarColorMode {
  /// Color encodes relationship temperature: hot blue-white = thriving/recent,
  /// gold = steady, cool red = fading. The emotional signal that invites you to
  /// rekindle cooling stars.
  temperature,

  /// Color encodes which constellation (connected component of mutuals) a star
  /// belongs to, so groups read as visually distinct.
  cluster,
}

/// Parses a persisted [StarColorMode] name, defaulting to [temperature].
StarColorMode starColorModeFromName(String? name) =>
    StarColorMode.values.firstWhere(
      (m) => m.name == name,
      orElse: () => StarColorMode.temperature,
    );

/// Human label for the mode (used in Settings).
String starColorModeLabel(StarColorMode mode) =>
    mode == StarColorMode.temperature ? 'Relationship' : 'Constellation';

// ── Temperature scale ──────────────────────────────────────────────────────

const List<double> _tempStops = [0.0, 0.35, 0.7, 1.0];
const List<Color> _tempColors = [
  Color(0xFFB23A48), // cool red — fading
  Color(0xFFF59E0B), // amber
  Color(0xFFFDE68A), // warm white-gold — steady
  Color(0xFF9EC5FF), // hot blue-white — thriving
];

/// Maps a 0..100 relationship [strength] to a stellar color, cool→hot. Out-of-
/// range / non-finite inputs are clamped so the result is always a valid color.
Color starTemperatureColor(double strength) {
  final s = (strength.isFinite ? strength.clamp(0.0, 100.0) : 0.0);
  final t = s / 100.0;
  for (var i = 0; i < _tempStops.length - 1; i++) {
    if (t <= _tempStops[i + 1]) {
      final span = _tempStops[i + 1] - _tempStops[i];
      final local = span == 0 ? 0.0 : (t - _tempStops[i]) / span;
      return Color.lerp(_tempColors[i], _tempColors[i + 1],
          local.clamp(0.0, 1.0))!;
    }
  }
  return _tempColors.last;
}

// ── Cluster palette ────────────────────────────────────────────────────────

/// Distinct, pleasant hues cycled across constellations.
const List<Color> kClusterPalette = [
  Color(0xFF818CF8), // indigo
  Color(0xFF34D399), // emerald
  Color(0xFFF472B6), // pink
  Color(0xFFFBBF24), // amber
  Color(0xFF22D3EE), // cyan
  Color(0xFFA78BFA), // violet
  Color(0xFFFB7185), // rose
  Color(0xFF4ADE80), // lime
  Color(0xFF60A5FA), // blue
  Color(0xFFFCD34D), // gold
];

/// Color for cluster [index], cycling the palette. Negative indices are treated
/// as 0.
Color clusterColor(int index) =>
    kClusterPalette[(index < 0 ? 0 : index) % kClusterPalette.length];

// ── Connected components (constellations) ──────────────────────────────────

/// Assigns each id a constellation index by grouping ids into connected
/// components of [links] (union-find). Ids touched by no link form singleton
/// constellations. Cluster indices are deterministic: ordered by each
/// component's smallest member id, so colors stay stable across rebuilds.
Map<String, int> assignClusters(List<String> ids, List<GraphLink> links) {
  final parent = {for (final id in ids) id: id};

  String find(String x) {
    var root = x;
    while (parent[root] != root) {
      root = parent[root]!;
    }
    // Path compression.
    var cur = x;
    while (parent[cur] != root) {
      final next = parent[cur]!;
      parent[cur] = root;
      cur = next;
    }
    return root;
  }

  void union(String a, String b) {
    final ra = find(a), rb = find(b);
    if (ra != rb) parent[ra] = rb;
  }

  for (final l in links) {
    if (parent.containsKey(l.sourceId) && parent.containsKey(l.targetId)) {
      union(l.sourceId, l.targetId);
    }
  }

  final groups = <String, List<String>>{};
  for (final id in ids) {
    groups.putIfAbsent(find(id), () => []).add(id);
  }

  String minId(List<String> g) =>
      g.reduce((a, b) => a.compareTo(b) <= 0 ? a : b);

  final ordered = groups.values.toList()
    ..sort((a, b) => minId(a).compareTo(minId(b)));

  final result = <String, int>{};
  for (var i = 0; i < ordered.length; i++) {
    for (final id in ordered[i]) {
      result[id] = i;
    }
  }
  return result;
}

// ── Twinkle ────────────────────────────────────────────────────────────────

/// A subtle brightness oscillation in `[1 - amount, 1]` for a star at [phase]
/// (radians), evaluated at [timeSeconds]. Deterministic and pure.
double twinkleBrightness(
  double timeSeconds,
  double phase, {
  double amount = 0.18,
  double speed = 1.6,
}) {
  final v = math.sin(timeSeconds * speed + phase); // -1..1
  return (1 - amount) + amount * 0.5 * (v + 1);
}

/// Stable twinkle phase (radians) derived from an id, so a star always twinkles
/// the same way without storing per-node state.
double twinklePhaseFor(String id) =>
    (id.hashCode & 0xFFFF) / 0xFFFF * 2 * math.pi;
