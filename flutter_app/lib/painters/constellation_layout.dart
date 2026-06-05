import 'dart:math' as math;
import 'dart:ui';

import 'cluster_layouts.dart';

/// A real constellation's star pattern in a normalized unit box (0..1, y-down),
/// plus the edges that trace its classic line figure.
class StarTemplate {
  final String name;
  final List<Offset> stars;
  final List<List<int>> edges;
  const StarTemplate(this.name, this.stars, this.edges);
  int get starCount => stars.length;
}

/// A small library of recognizable constellation figures, cycled across the
/// user's tag-groups. Coordinates are hand-placed approximations chosen to read
/// clearly at a glance rather than to be astronomically exact.
const List<StarTemplate> kConstellationTemplates = [
  StarTemplate(
    'Orion',
    [
      Offset(0.50, 0.06), // head
      Offset(0.30, 0.24), // left shoulder
      Offset(0.70, 0.22), // right shoulder
      Offset(0.44, 0.52), // belt L
      Offset(0.51, 0.55), // belt M
      Offset(0.58, 0.58), // belt R
      Offset(0.40, 0.90), // left foot
      Offset(0.72, 0.86), // right foot
    ],
    [
      [1, 2],
      [0, 1],
      [0, 2],
      [1, 3],
      [2, 5],
      [3, 4],
      [4, 5],
      [3, 6],
      [5, 7],
    ],
  ),
  StarTemplate(
    'Big Dipper',
    [
      Offset(0.06, 0.66),
      Offset(0.22, 0.58),
      Offset(0.38, 0.52),
      Offset(0.54, 0.50),
      Offset(0.62, 0.30),
      Offset(0.84, 0.36),
      Offset(0.80, 0.58),
      Offset(0.56, 0.62),
    ],
    [
      [0, 1],
      [1, 2],
      [2, 3],
      [3, 4],
      [4, 5],
      [5, 6],
      [6, 7],
      [7, 3],
    ],
  ),
  StarTemplate(
    'Cassiopeia',
    [
      Offset(0.08, 0.42),
      Offset(0.28, 0.64),
      Offset(0.50, 0.40),
      Offset(0.72, 0.66),
      Offset(0.92, 0.44),
    ],
    [
      [0, 1],
      [1, 2],
      [2, 3],
      [3, 4],
    ],
  ),
  StarTemplate(
    'Cygnus',
    [
      Offset(0.50, 0.06),
      Offset(0.50, 0.46),
      Offset(0.50, 0.94),
      Offset(0.16, 0.42),
      Offset(0.84, 0.42),
    ],
    [
      [0, 1],
      [1, 2],
      [3, 1],
      [1, 4],
    ],
  ),
  StarTemplate(
    'Leo',
    [
      Offset(0.16, 0.30),
      Offset(0.26, 0.16),
      Offset(0.40, 0.22),
      Offset(0.46, 0.46),
      Offset(0.72, 0.54),
      Offset(0.86, 0.40),
    ],
    [
      [0, 1],
      [1, 2],
      [2, 3],
      [3, 4],
      [4, 5],
      [5, 3],
    ],
  ),
  StarTemplate(
    'Scorpius',
    [
      Offset(0.18, 0.16),
      Offset(0.28, 0.32),
      Offset(0.40, 0.48),
      Offset(0.52, 0.60),
      Offset(0.64, 0.70),
      Offset(0.78, 0.76),
      Offset(0.86, 0.66),
    ],
    [
      [0, 1],
      [1, 2],
      [2, 3],
      [3, 4],
      [4, 5],
      [5, 6],
    ],
  ),
  StarTemplate(
    'Lyra',
    [
      Offset(0.50, 0.10),
      Offset(0.36, 0.42),
      Offset(0.64, 0.40),
      Offset(0.40, 0.74),
      Offset(0.62, 0.76),
    ],
    [
      [0, 1],
      [0, 2],
      [1, 3],
      [2, 4],
      [3, 4],
    ],
  ),
  StarTemplate(
    'Triangulum',
    [Offset(0.50, 0.14), Offset(0.18, 0.78), Offset(0.82, 0.72)],
    [
      [0, 1],
      [1, 2],
      [2, 0],
    ],
  ),
];

/// One placed tag-group, for drawing its constellation name near its center.
class ConstellationGroup {
  final String tag;
  final String constellation;
  final Offset center;
  final int index;

  /// Bounding radius of the group's nodes around [center], so labels can be
  /// placed just below the lowest node instead of inside the cluster.
  final double radius;

  /// The rendering this group was laid out with (for display / picking).
  final ClusterLayout layout;

  const ConstellationGroup({
    required this.tag,
    required this.constellation,
    required this.center,
    required this.index,
    this.radius = 0,
    this.layout = ClusterLayout.figure,
  });
}

/// Shortest distance from [p] to the line segment [a]–[b]. Used to hit-test a
/// tap against a graph edge (a line linking two nodes).
double distanceToSegment(Offset p, Offset a, Offset b) {
  final dx = b.dx - a.dx;
  final dy = b.dy - a.dy;
  final lengthSquared = dx * dx + dy * dy;
  if (lengthSquared == 0) return (p - a).distance; // a == b
  var t = ((p.dx - a.dx) * dx + (p.dy - a.dy) * dy) / lengthSquared;
  t = t.clamp(0.0, 1.0);
  final projection = Offset(a.dx + t * dx, a.dy + t * dy);
  return (p - projection).distance;
}

/// The tag of the constellation label nearest [contentPoint] (in graph/content
/// coordinates) at the current [scale], or null when none is within the hit
/// radius. The label is drawn `150/scale` below each group's center (see
/// `GraphPainter`), and the hit radius (`180/scale`) scales with zoom so the
/// touch target stays roughly constant on screen. The closest label wins.
String? constellationTagAt(
  Offset contentPoint,
  double scale,
  List<ConstellationGroup> labels,
) {
  if (scale <= 0) return null;
  final radius = 180 / scale;
  String? best;
  var bestDistance = double.infinity;
  for (final g in labels) {
    // Match the painter: the label sits below the cluster (center + radius).
    final labelCenter = Offset(
      g.center.dx,
      g.center.dy + g.radius + 28 / scale,
    );
    final distance = (contentPoint - labelCenter).distance;
    if (distance < radius && distance < bestDistance) {
      bestDistance = distance;
      best = g.tag;
    }
  }
  return best;
}

/// The computed sky: where each contact sits, the figure lines to draw, the
/// group index per contact (for coloring / illumination), and the placed groups
/// (for labels).
class ConstellationSky {
  final Map<String, Offset> positions;
  final List<({String a, String b})> lines;
  final Map<String, int> groupIndex;
  final List<ConstellationGroup> groups;
  const ConstellationSky({
    required this.positions,
    required this.lines,
    required this.groupIndex,
    required this.groups,
  });
}

/// The relationship label for a line between two contacts: the tags they have
/// in common, joined by " · " (e.g. "Work · Gym"). Matching is case-insensitive
/// but preserves [a]'s original casing and order, and de-duplicates. Returns ''
/// when they share no tags.
String sharedRelationLabel(List<String> a, List<String> b) {
  if (a.isEmpty || b.isEmpty) return '';
  final other = b.map((t) => t.toLowerCase()).toSet();
  final seen = <String>{};
  final shared = <String>[];
  for (final t in a) {
    final key = t.toLowerCase();
    if (other.contains(key) && seen.add(key)) shared.add(t);
  }
  return shared.join(' · ');
}

/// Fixed size of a group's core "figure" box, independent of how many nodes it
/// has — so small groups always read as a recognizable constellation.
const double _figureScale = 220.0;

/// Tag groups with at most this many members are laid out on an even ring
/// instead of being snapped to a star template. Some templates place their
/// first few stars close together (e.g. a constellation's head + shoulder, or
/// Orion's belt), so a tiny tag like a 2-person "family" would land on two
/// near-touching stars and visually overlap. A ring guarantees they don't.
const int _ringThreshold = 4;

/// Minimum center-to-center distance (content px) between a small group's nodes.
/// Node discs reach ~20px plus a soft glow, so 72px leaves a clear gap.
const double _minNodeSeparation = 72.0;

/// Floor on the ring radius so even a 2-node group sits at a comfortable size.
const double _ringRadiusFloor = 40.0;

/// Target spacing between overflow (satellite) nodes in a large group; their
/// even golden-angle spread keeps even a 1500-node cluster legible.
const double _nodeSpacing = 28.0;

/// Empty margin added around the largest group when sizing the grid cells, so
/// neighbouring constellations never overlap however lopsided the tags are.
const double _cellMargin = 160.0;

/// Cap on lines drawn from a group's core to its satellites — a big group shows
/// a few connectors instead of a dense hairball of 1000+ lines.
const int _maxSatelliteLines = 28;

/// Golden-angle (radians) for phyllotaxis ("sunflower") point spreads.
final double _goldenAngle = math.pi * (3 - math.sqrt(5));

int _seed(String s) => s.hashCode & 0x7fffffff;

/// Approximate radius a tag-group occupies: the figure half-extent for small
/// groups, growing with sqrt(node count) for large ones (matching the spiral
/// overflow layout) so cells can be sized to prevent overlap.
double _groupRadius(int nodeCount, int starCount) {
  if (nodeCount <= starCount) return _figureScale * 0.5;
  final extra = nodeCount - starCount;
  final spiralR =
      _figureScale * 0.45 + _nodeSpacing * math.sqrt(extra.toDouble());
  return math.max(_figureScale * 0.5, spiralR);
}

/// Bounding radius for a group rendered with [layout]: the figure extent for the
/// named figure, else a generous disc covering any fill layout's spread.
double _renderRadius(ClusterLayout layout, int nodeCount, int starCount) {
  if (layout == ClusterLayout.figure) return _groupRadius(nodeCount, starCount);
  return _nodeSpacing * (math.sqrt(nodeCount.toDouble()) + 1) * 1.5;
}

/// Places a small figure group ([used] ≤ [_ringThreshold] nodes) on an even
/// ring around [center] — far enough apart to never overlap — and links them in
/// a loop. A single node sits at the center.
void _placeSmallGroupRing({
  required List<String> ids,
  required int used,
  required Offset center,
  required int group,
  required Map<String, Offset> positions,
  required Map<String, int> groupIndexMap,
  required List<({String a, String b})> lines,
}) {
  if (used <= 0) return;
  if (used == 1) {
    positions[ids[0]] = center;
    groupIndexMap[ids[0]] = group;
    return;
  }
  final radius = math.max(
    _ringRadiusFloor,
    _minNodeSeparation * used / (2 * math.pi),
  );
  for (var i = 0; i < used; i++) {
    final theta = 2 * math.pi * i / used - math.pi / 2;
    positions[ids[i]] =
        center + Offset(math.cos(theta) * radius, math.sin(theta) * radius);
    groupIndexMap[ids[i]] = group;
  }
  for (var i = 0; i < used - 1; i++) {
    lines.add((a: ids[i], b: ids[i + 1]));
  }
  if (used > 2) lines.add((a: ids[used - 1], b: ids[0]));
}

/// Lays out [items] (each an `(id, tag)`) as a stable, recognizable night sky:
/// every distinct non-empty tag becomes a constellation (snapped onto a real
/// star pattern), groups are spread across a grid of sky cells, and untagged
/// contacts are gathered into a "loose stars" band below. Deterministic: the
/// same input always yields the same sky (no wall-clock / unseeded randomness).
ConstellationSky computeConstellationSky(
  List<({String id, String tag})> items, {
  int runSeed = 0,
  bool randomizeLayouts = false,
  Map<String, ClusterLayout> layoutOverrides = const {},
}) {
  final byTag = <String, List<String>>{};
  for (final it in items) {
    byTag.putIfAbsent(it.tag, () => []).add(it.id);
  }
  for (final ids in byTag.values) {
    ids.sort();
  }

  final namedTags = byTag.keys.where((t) => t.isNotEmpty).toList()..sort();
  final cols = namedTags.isEmpty ? 1 : math.sqrt(namedTags.length).ceil();

  // Resolve each group's rendering up front (override → per-run random →
  // figure), so cell sizing and node placement agree.
  final layouts = [
    for (final tag in namedTags)
      effectiveClusterLayout(
        tag: tag,
        isOrphans: false,
        overrides: layoutOverrides,
        randomize: randomizeLayouts,
        runSeed: runSeed,
      ),
  ];

  // Size every grid cell to the largest group so groups never overlap.
  var maxRadius = _figureScale * 0.5;
  for (var gi = 0; gi < namedTags.length; gi++) {
    final starCount =
        kConstellationTemplates[gi % kConstellationTemplates.length].starCount;
    final r = _renderRadius(
      layouts[gi],
      byTag[namedTags[gi]]!.length,
      starCount,
    );
    if (r > maxRadius) maxRadius = r;
  }
  final cellSize = 2 * maxRadius + _cellMargin;

  final positions = <String, Offset>{};
  final lines = <({String a, String b})>[];
  final groupIndex = <String, int>{};
  final groups = <ConstellationGroup>[];

  for (var gi = 0; gi < namedTags.length; gi++) {
    final tag = namedTags[gi];
    final ids = byTag[tag]!;
    final tmpl = kConstellationTemplates[gi % kConstellationTemplates.length];
    final layout = layouts[gi];
    final rng = math.Random(_seed(tag) ^ runSeed);

    final col = gi % cols;
    final row = gi ~/ cols;
    final jitter = _figureScale * 0.12;
    final jx = (rng.nextDouble() - 0.5) * jitter;
    final jy = (rng.nextDouble() - 0.5) * jitter;
    final center = Offset(
      col * cellSize + cellSize / 2 + jx,
      row * cellSize + cellSize / 2 + jy,
    );

    groups.add(
      ConstellationGroup(
        tag: tag,
        constellation: tmpl.name,
        center: center,
        index: gi,
        radius: _renderRadius(layout, ids.length, tmpl.starCount),
        layout: layout,
      ),
    );

    if (layout == ClusterLayout.figure) {
      // Named figure core (Orion, …) + phyllotaxis overflow (stable default).
      const figureScale = _figureScale;
      final used = math.min(ids.length, tmpl.starCount);
      if (used <= _ringThreshold) {
        // Small tag: an even ring guarantees the nodes never overlap, however
        // close the template's first stars happen to sit.
        _placeSmallGroupRing(
          ids: ids,
          used: used,
          center: center,
          group: gi,
          positions: positions,
          groupIndexMap: groupIndex,
          lines: lines,
        );
      } else {
        for (var i = 0; i < used; i++) {
          final s = tmpl.stars[i];
          positions[ids[i]] =
              center +
              Offset((s.dx - 0.5) * figureScale, (s.dy - 0.5) * figureScale);
          groupIndex[ids[i]] = gi;
        }
        for (final e in tmpl.edges) {
          if (e[0] < used && e[1] < used) {
            lines.add((a: ids[e[0]], b: ids[e[1]]));
          }
        }
      }
      final extra = ids.length - used;
      for (var k = 0; k < extra; k++) {
        final id = ids[used + k];
        final theta = k * _goldenAngle;
        final r = figureScale * 0.45 + _nodeSpacing * math.sqrt(k + 1.0);
        positions[id] =
            center + Offset(math.cos(theta) * r, math.sin(theta) * r);
        groupIndex[id] = gi;
        if (k < _maxSatelliteLines && used > 0) {
          lines.add((a: ids[k % used], b: id));
        }
      }
    } else {
      // A chosen/random fill layout applied to the whole group.
      final offsets = generateClusterOffsets(
        layout,
        ids.length,
        spacing: _nodeSpacing,
        rng: rng,
      );
      for (var k = 0; k < ids.length; k++) {
        positions[ids[k]] = center + offsets[k];
        groupIndex[ids[k]] = gi;
      }
      // A capped set of connectors so the group reads as one constellation
      // (and shared-tag edge labels still appear).
      final connectors = math.min(_maxSatelliteLines, ids.length - 1);
      for (var k = 1; k <= connectors; k++) {
        lines.add((a: ids[0], b: ids[k]));
      }
    }
  }

  // Contacts with no linking tag → the "Orphans" constellation, with its own
  // (override / per-run random / sunflower) rendering.
  final loose = byTag[''] ?? const [];
  if (loose.isNotEmpty) {
    final orphanIndex = namedTags.length;
    final orphanLayout = effectiveClusterLayout(
      tag: 'Orphans',
      isOrphans: true,
      overrides: layoutOverrides,
      randomize: randomizeLayouts,
      runSeed: runSeed,
    );
    final rows = namedTags.isEmpty ? 0 : (namedTags.length / cols).ceil();
    final bandTop = rows * cellSize + (rows == 0 ? 0.0 : 80.0);
    final orphanRadius = _renderRadius(orphanLayout, loose.length, 0);
    final orphanCenter = Offset(
      math.max(orphanRadius, cols * cellSize / 2),
      bandTop + orphanRadius,
    );
    final offsets = generateClusterOffsets(
      orphanLayout,
      loose.length,
      spacing: _nodeSpacing,
      rng: math.Random(_seed('Orphans') ^ runSeed),
    );
    for (var i = 0; i < loose.length; i++) {
      positions[loose[i]] = orphanCenter + offsets[i];
      groupIndex[loose[i]] = orphanIndex;
    }
    groups.add(
      ConstellationGroup(
        tag: 'Orphans',
        constellation: 'Orphans',
        center: orphanCenter,
        index: orphanIndex,
        radius: orphanRadius,
        layout: orphanLayout,
      ),
    );
  }

  return ConstellationSky(
    positions: positions,
    lines: lines,
    groupIndex: groupIndex,
    groups: groups,
  );
}
