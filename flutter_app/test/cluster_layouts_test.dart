import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:social_graph/painters/cluster_layouts.dart';

void main() {
  group('generateClusterOffsets', () {
    test('every layout returns exactly `count` finite offsets', () {
      for (final layout in ClusterLayout.values) {
        for (final count in [0, 1, 5, 200]) {
          final offs = generateClusterOffsets(layout, count,
              rng: math.Random(1));
          expect(offs.length, count, reason: '$layout / $count');
          for (final o in offs) {
            expect(o.dx.isFinite && o.dy.isFinite, isTrue,
                reason: '$layout produced a non-finite offset');
          }
        }
      }
    });

    test('is deterministic for a given rng seed', () {
      for (final layout in ClusterLayout.values) {
        final a = generateClusterOffsets(layout, 50, rng: math.Random(7));
        final b = generateClusterOffsets(layout, 50, rng: math.Random(7));
        expect(a, b, reason: '$layout not deterministic');
      }
    });

    test('stays roughly bounded to a spacing·√n disc', () {
      const spacing = 28.0;
      const n = 400;
      final bound = spacing * math.sqrt(n) * 2.5; // generous
      for (final layout in ClusterLayout.values) {
        final offs =
            generateClusterOffsets(layout, n, spacing: spacing, rng: math.Random(3));
        for (final o in offs) {
          expect(o.distance, lessThan(bound), reason: '$layout escaped');
        }
      }
    });
  });

  group('pickClusterLayout / labels', () {
    test('picks deterministically from a seed', () {
      expect(pickClusterLayout(5), pickClusterLayout(5));
    });

    test('every layout has a non-empty label and round-trips by name', () {
      for (final l in ClusterLayout.values) {
        expect(clusterLayoutLabel(l), isNotEmpty);
        expect(clusterLayoutFromName(l.name), l);
      }
      expect(clusterLayoutFromName('bogus'), ClusterLayout.figure);
    });
  });

  group('effectiveClusterLayout', () {
    test('an override always wins', () {
      final l = effectiveClusterLayout(
        tag: 'Work',
        isOrphans: false,
        overrides: {'Work': ClusterLayout.galaxy},
        randomize: true,
        runSeed: 42,
      );
      expect(l, ClusterLayout.galaxy);
    });

    test('defaults to the named figure when not randomizing', () {
      final l = effectiveClusterLayout(
        tag: 'Work',
        isOrphans: false,
        overrides: const {},
        randomize: false,
        runSeed: 0,
      );
      expect(l, ClusterLayout.figure);
    });

    test('orphans never resolve to figure', () {
      // Force a figure pick via override, but orphans must fall back.
      final l = effectiveClusterLayout(
        tag: 'Orphans',
        isOrphans: true,
        overrides: {'Orphans': ClusterLayout.figure},
        randomize: false,
        runSeed: 0,
      );
      expect(l, ClusterLayout.sunflower);
    });
  });
}
