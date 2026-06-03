import 'dart:math' as math;
import 'dart:ui';

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
  StarTemplate('Orion', [
    Offset(0.50, 0.06), // head
    Offset(0.30, 0.24), // left shoulder
    Offset(0.70, 0.22), // right shoulder
    Offset(0.44, 0.52), // belt L
    Offset(0.51, 0.55), // belt M
    Offset(0.58, 0.58), // belt R
    Offset(0.40, 0.90), // left foot
    Offset(0.72, 0.86), // right foot
  ], [
    [1, 2], [0, 1], [0, 2], [1, 3], [2, 5], [3, 4], [4, 5], [3, 6], [5, 7],
  ]),
  StarTemplate('Big Dipper', [
    Offset(0.06, 0.66),
    Offset(0.22, 0.58),
    Offset(0.38, 0.52),
    Offset(0.54, 0.50),
    Offset(0.62, 0.30),
    Offset(0.84, 0.36),
    Offset(0.80, 0.58),
    Offset(0.56, 0.62),
  ], [
    [0, 1], [1, 2], [2, 3], [3, 4], [4, 5], [5, 6], [6, 7], [7, 3],
  ]),
  StarTemplate('Cassiopeia', [
    Offset(0.08, 0.42),
    Offset(0.28, 0.64),
    Offset(0.50, 0.40),
    Offset(0.72, 0.66),
    Offset(0.92, 0.44),
  ], [
    [0, 1], [1, 2], [2, 3], [3, 4],
  ]),
  StarTemplate('Cygnus', [
    Offset(0.50, 0.06),
    Offset(0.50, 0.46),
    Offset(0.50, 0.94),
    Offset(0.16, 0.42),
    Offset(0.84, 0.42),
  ], [
    [0, 1], [1, 2], [3, 1], [1, 4],
  ]),
  StarTemplate('Leo', [
    Offset(0.16, 0.30),
    Offset(0.26, 0.16),
    Offset(0.40, 0.22),
    Offset(0.46, 0.46),
    Offset(0.72, 0.54),
    Offset(0.86, 0.40),
  ], [
    [0, 1], [1, 2], [2, 3], [3, 4], [4, 5], [5, 3],
  ]),
  StarTemplate('Scorpius', [
    Offset(0.18, 0.16),
    Offset(0.28, 0.32),
    Offset(0.40, 0.48),
    Offset(0.52, 0.60),
    Offset(0.64, 0.70),
    Offset(0.78, 0.76),
    Offset(0.86, 0.66),
  ], [
    [0, 1], [1, 2], [2, 3], [3, 4], [4, 5], [5, 6],
  ]),
  StarTemplate('Lyra', [
    Offset(0.50, 0.10),
    Offset(0.36, 0.42),
    Offset(0.64, 0.40),
    Offset(0.40, 0.74),
    Offset(0.62, 0.76),
  ], [
    [0, 1], [0, 2], [1, 3], [2, 4], [3, 4],
  ]),
  StarTemplate('Triangulum', [
    Offset(0.50, 0.14),
    Offset(0.18, 0.78),
    Offset(0.82, 0.72),
  ], [
    [0, 1], [1, 2], [2, 0],
  ]),
];

/// One placed tag-group, for drawing its constellation name near its center.
class ConstellationGroup {
  final String tag;
  final String constellation;
  final Offset center;
  final int index;
  const ConstellationGroup({
    required this.tag,
    required this.constellation,
    required this.center,
    required this.index,
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
    final labelCenter = Offset(g.center.dx, g.center.dy + 150 / scale);
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

/// Group index assigned to all untagged ("loose") stars.
const int kLooseGroupIndex = -1;

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

const double _cellW = 460.0;
const double _cellH = 380.0;

int _seed(String s) => s.hashCode & 0x7fffffff;

/// Lays out [items] (each an `(id, tag)`) as a stable, recognizable night sky:
/// every distinct non-empty tag becomes a constellation (snapped onto a real
/// star pattern), groups are spread across a grid of sky cells, and untagged
/// contacts are gathered into a "loose stars" band below. Deterministic: the
/// same input always yields the same sky (no wall-clock / unseeded randomness).
ConstellationSky computeConstellationSky(List<({String id, String tag})> items) {
  final byTag = <String, List<String>>{};
  for (final it in items) {
    byTag.putIfAbsent(it.tag, () => []).add(it.id);
  }
  for (final ids in byTag.values) {
    ids.sort();
  }

  final namedTags = byTag.keys.where((t) => t.isNotEmpty).toList()..sort();
  final cols = namedTags.isEmpty ? 1 : math.sqrt(namedTags.length).ceil();

  final positions = <String, Offset>{};
  final lines = <({String a, String b})>[];
  final groupIndex = <String, int>{};
  final groups = <ConstellationGroup>[];

  for (var gi = 0; gi < namedTags.length; gi++) {
    final tag = namedTags[gi];
    final ids = byTag[tag]!;
    final tmpl = kConstellationTemplates[gi % kConstellationTemplates.length];
    final rng = math.Random(_seed(tag));

    final col = gi % cols;
    final row = gi ~/ cols;
    final jx = (rng.nextDouble() - 0.5) * _cellW * 0.16;
    final jy = (rng.nextDouble() - 0.5) * _cellH * 0.16;
    final center = Offset(
      col * _cellW + _cellW / 2 + jx,
      row * _cellH + _cellH / 2 + jy,
    );
    final figureScale = math.min(_cellW, _cellH) * 0.62;

    groups.add(ConstellationGroup(
      tag: tag,
      constellation: tmpl.name,
      center: center,
      index: gi,
    ));

    final used = math.min(ids.length, tmpl.starCount);
    for (var i = 0; i < used; i++) {
      final s = tmpl.stars[i];
      positions[ids[i]] = center +
          Offset((s.dx - 0.5) * figureScale, (s.dy - 0.5) * figureScale);
      groupIndex[ids[i]] = gi;
    }
    for (final e in tmpl.edges) {
      if (e[0] < used && e[1] < used) {
        lines.add((a: ids[e[0]], b: ids[e[1]]));
      }
    }

    // Overflow: extra members orbit the figure as satellite stars. Each is
    // linked to one of the figure stars so every member of a tag-group is
    // visibly connected — sharing a tag always shows a line, even when the
    // group is far larger than its star pattern.
    final extra = ids.length - used;
    if (extra > 0) {
      final spread = figureScale * 0.55 * (1 + math.sqrt(extra) / 7);
      for (var i = used; i < ids.length; i++) {
        final ang = rng.nextDouble() * 2 * math.pi;
        final r = spread * math.sqrt(rng.nextDouble());
        positions[ids[i]] =
            center + Offset(math.cos(ang) * r, math.sin(ang) * r);
        groupIndex[ids[i]] = gi;
        lines.add((a: ids[i % used], b: ids[i]));
      }
    }
  }

  // Loose (untagged) contacts: a 2D jittered grid below the constellation grid.
  // A grid (rather than a thin random band) keeps thousands of unconnected
  // stars evenly spread instead of piling on top of each other — which both
  // looks better and avoids heavy overdraw.
  final loose = byTag[''] ?? const [];
  if (loose.isNotEmpty) {
    final rows = namedTags.isEmpty ? 0 : (namedTags.length / cols).ceil();
    final bandTop = rows * _cellH + (rows == 0 ? 0.0 : 80.0);
    const cell = 74.0;
    final looseCols = math.sqrt(loose.length).ceil();
    for (var i = 0; i < loose.length; i++) {
      final id = loose[i];
      final rng = math.Random(_seed(id));
      final col = i % looseCols;
      final row = i ~/ looseCols;
      positions[id] = Offset(
        col * cell + (rng.nextDouble() - 0.5) * cell * 0.6,
        bandTop + row * cell + (rng.nextDouble() - 0.5) * cell * 0.6,
      );
      groupIndex[id] = kLooseGroupIndex;
    }
  }

  return ConstellationSky(
    positions: positions,
    lines: lines,
    groupIndex: groupIndex,
    groups: groups,
  );
}
