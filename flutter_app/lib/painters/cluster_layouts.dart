import 'dart:math' as math;
import 'dart:ui';

/// Algorithms for arranging a constellation's N stars around its center. The
/// active one can be chosen per-run per-group (see [pickClusterLayout]) so the
/// sky's shapes change between launches. Each generator returns exactly [count]
/// offsets relative to the group center; all are O(n) (or O(n log n)) and stay
/// bounded to roughly a `spacing·√count` disc so big groups (≈1500 orphans)
/// never blow up or overlap their neighbours.
enum ClusterLayout {
  figure, // the named constellation pattern (Orion, …) + spiral overflow
  sunflower, // golden-angle phyllotaxis disc (even, gap-free)
  rings, // concentric circles
  hexDisc, // hexagonal close-packing
  jitterGrid, // square lattice + jitter
  rotatedGrid, // square lattice rotated by a random angle
  archimedean, // single Archimedean spiral arm
  galaxy, // 2–4 swirling spiral arms
  randomDisc, // uniform random scatter in a disc
  randomWalk, // a wandering star-trail (bounded)
  nebula, // a few sub-clusters → lumpy cloud
}

/// Human label for a layout (shown in the Constellations view).
String clusterLayoutLabel(ClusterLayout l) {
  switch (l) {
    case ClusterLayout.figure:
      return 'Figure';
    case ClusterLayout.sunflower:
      return 'Sunflower';
    case ClusterLayout.rings:
      return 'Rings';
    case ClusterLayout.hexDisc:
      return 'Hex';
    case ClusterLayout.jitterGrid:
      return 'Grid';
    case ClusterLayout.rotatedGrid:
      return 'Tilted grid';
    case ClusterLayout.archimedean:
      return 'Spiral';
    case ClusterLayout.galaxy:
      return 'Galaxy';
    case ClusterLayout.randomDisc:
      return 'Scatter';
    case ClusterLayout.randomWalk:
      return 'Trail';
    case ClusterLayout.nebula:
      return 'Nebula';
  }
}

/// Parses a persisted layout name back to the enum (defaults to [figure]).
ClusterLayout clusterLayoutFromName(String? name) => ClusterLayout.values
    .firstWhere((l) => l.name == name, orElse: () => ClusterLayout.figure);

/// Deterministically pick a layout from a seed (combine a per-run seed with the
/// group's tag hash before calling, so each group differs and each run differs).
ClusterLayout pickClusterLayout(int seed) =>
    ClusterLayout.values[(seed & 0x7fffffff) % ClusterLayout.values.length];

/// The layout a cluster should actually render with:
///  1. a user [overrides] choice wins;
///  2. else, when [randomize] is on, a per-run random pick (seed = runSeed ⊕
///     tag), which may include the named [ClusterLayout.figure];
///  3. else the named [ClusterLayout.figure] (the stable default).
/// Orphans have no named figure, so a `figure` result becomes [sunflower].
ClusterLayout effectiveClusterLayout({
  required String tag,
  required bool isOrphans,
  required Map<String, ClusterLayout> overrides,
  required bool randomize,
  required int runSeed,
}) {
  var layout = overrides[tag] ??
      (randomize
          ? pickClusterLayout(runSeed ^ tag.hashCode)
          : ClusterLayout.figure);
  if (isOrphans && layout == ClusterLayout.figure) {
    layout = ClusterLayout.sunflower;
  }
  return layout;
}

const double kDefaultNodeSpacing = 28.0;
final double _golden = math.pi * (3 - math.sqrt(5));

/// Generates [count] center-relative offsets for [layout]. [rng] supplies the
/// randomness for the stochastic layouts (seed it for determinism within a run).
List<Offset> generateClusterOffsets(
  ClusterLayout layout,
  int count, {
  double spacing = kDefaultNodeSpacing,
  required math.Random rng,
}) {
  if (count <= 0) return const [];
  switch (layout) {
    case ClusterLayout.figure:
      // The figure is laid out from constellation templates, not here; fall
      // back to an even disc if ever generated generically.
      return _sunflower(count, spacing);
    case ClusterLayout.sunflower:
      return _sunflower(count, spacing);
    case ClusterLayout.rings:
      return _rings(count, spacing);
    case ClusterLayout.hexDisc:
      return _lattice(count, spacing, hex: true, rng: rng);
    case ClusterLayout.jitterGrid:
      return _lattice(count, spacing, hex: false, rng: rng, jitter: true);
    case ClusterLayout.rotatedGrid:
      return _lattice(count, spacing,
          hex: false, rng: rng, rotation: rng.nextDouble() * math.pi);
    case ClusterLayout.archimedean:
      return _archimedean(count, spacing);
    case ClusterLayout.galaxy:
      return _galaxy(count, spacing, rng);
    case ClusterLayout.randomDisc:
      return _randomDisc(count, spacing, rng);
    case ClusterLayout.randomWalk:
      return _randomWalk(count, spacing, rng);
    case ClusterLayout.nebula:
      return _nebula(count, spacing, rng);
  }
}

List<Offset> _sunflower(int n, double s) => [
      for (var k = 0; k < n; k++)
        Offset.fromDirection(k * _golden, s * math.sqrt(k + 0.5)),
    ];

List<Offset> _rings(int n, double s) {
  final out = <Offset>[Offset.zero];
  var ring = 1;
  while (out.length < n) {
    final radius = ring * s;
    final cap = math.max(1, (2 * math.pi * radius / s).floor());
    final m = math.min(cap, n - out.length);
    for (var j = 0; j < m; j++) {
      out.add(Offset.fromDirection(2 * math.pi * j / m + ring * 0.4, radius));
    }
    ring++;
  }
  return out;
}

/// Square or hexagonal lattice points nearest the center (a packed disc),
/// optionally rotated and/or jittered.
List<Offset> _lattice(
  int n,
  double s, {
  required bool hex,
  required math.Random rng,
  bool jitter = false,
  double rotation = 0,
}) {
  final side = math.sqrt(n).ceil() + 2;
  final rowH = hex ? s * math.sqrt(3) / 2 : s;
  final pts = <Offset>[];
  for (var r = -side; r <= side; r++) {
    final xShift = (hex && r.isOdd) ? s / 2 : 0.0;
    for (var c = -side; c <= side; c++) {
      pts.add(Offset(c * s + xShift, r * rowH));
    }
  }
  pts.sort((a, b) => a.distanceSquared.compareTo(b.distanceSquared));
  final cosA = math.cos(rotation), sinA = math.sin(rotation);
  return [
    for (final p in pts.take(n))
      Offset(
        (rotation == 0 ? p.dx : p.dx * cosA - p.dy * sinA) +
            (jitter ? (rng.nextDouble() - 0.5) * s * 0.35 : 0),
        (rotation == 0 ? p.dy : p.dx * sinA + p.dy * cosA) +
            (jitter ? (rng.nextDouble() - 0.5) * s * 0.35 : 0),
      ),
  ];
}

List<Offset> _archimedean(int n, double s) {
  final out = <Offset>[];
  final a = s / (2 * math.pi); // arm spacing == s
  var theta = 2 * math.pi; // start out a little to avoid a crowded center
  for (var k = 0; k < n; k++) {
    final r = a * theta;
    out.add(Offset.fromDirection(theta, r));
    theta += s / math.max(r, s); // ~constant arc-length step
  }
  return out;
}

List<Offset> _galaxy(int n, double s, math.Random rng) {
  final arms = 2 + rng.nextInt(3); // 2..4 arms
  final swirl = 0.12 + rng.nextDouble() * 0.10;
  return [
    for (var k = 0; k < n; k++)
      Offset.fromDirection(
        (k % arms) * 2 * math.pi / arms +
            swirl * math.sqrt(k.toDouble()) +
            (rng.nextDouble() - 0.5) * 0.25,
        s * math.sqrt(k + 1.0),
      ),
  ];
}

List<Offset> _randomDisc(int n, double s, math.Random rng) {
  final radius = s * math.sqrt(n.toDouble());
  return [
    for (var k = 0; k < n; k++)
      Offset.fromDirection(
          rng.nextDouble() * 2 * math.pi, radius * math.sqrt(rng.nextDouble())),
  ];
}

List<Offset> _randomWalk(int n, double s, math.Random rng) {
  final maxR = s * math.sqrt(n.toDouble());
  final out = <Offset>[];
  var pos = Offset.zero;
  var heading = rng.nextDouble() * 2 * math.pi;
  for (var k = 0; k < n; k++) {
    out.add(pos);
    heading += (rng.nextDouble() - 0.5) * 0.8;
    pos += Offset.fromDirection(heading, s);
    if (pos.distance > maxR) {
      // Reflect back inside the disc so the trail stays bounded.
      pos = Offset.fromDirection(pos.direction, maxR);
      heading += math.pi / 2;
    }
  }
  return out;
}

List<Offset> _nebula(int n, double s, math.Random rng) {
  final clusters = math.max(2, (math.sqrt(n) / 2).round());
  final spread = s * math.sqrt(n.toDouble()) * 0.9;
  final centers = [
    for (var i = 0; i < clusters; i++)
      Offset.fromDirection(
          rng.nextDouble() * 2 * math.pi, spread * math.sqrt(rng.nextDouble())),
  ];
  final blob = s * math.sqrt(n / clusters) * 0.6;
  return [
    for (var k = 0; k < n; k++)
      centers[rng.nextInt(clusters)] +
          Offset.fromDirection(
              rng.nextDouble() * 2 * math.pi, blob * math.sqrt(rng.nextDouble())),
  ];
}
