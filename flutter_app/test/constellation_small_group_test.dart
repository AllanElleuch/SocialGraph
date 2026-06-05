import 'package:flutter_test/flutter_test.dart';
import 'package:social_graph/painters/cluster_layouts.dart';
import 'package:social_graph/painters/constellation_layout.dart';

ConstellationSky _skyFor(int n, String tag) => computeConstellationSky(
  [for (var i = 0; i < n; i++) (id: '$tag$i', tag: tag)],
  // Force the figure layout so the ring path is exercised deterministically.
  layoutOverrides: {tag: ClusterLayout.figure},
);

void main() {
  group('small tag groups never overlap', () {
    test('a 2-person tag places its nodes well apart', () {
      final sky = _skyFor(2, 'family');
      final a = sky.positions['family0']!;
      final b = sky.positions['family1']!;
      // Before the ring fix these could land ~38px apart (overlapping glows).
      expect((a - b).distance, greaterThanOrEqualTo(72.0));
    });

    test('3- and 4-person tags keep every pair separated', () {
      for (final n in [3, 4]) {
        final sky = _skyFor(n, 't$n');
        final ids = [for (var i = 0; i < n; i++) 't$n$i'];
        for (var i = 0; i < n; i++) {
          for (var j = i + 1; j < n; j++) {
            final d =
                (sky.positions[ids[i]]! - sky.positions[ids[j]]!).distance;
            expect(
              d,
              greaterThanOrEqualTo(60.0),
              reason: 'n=$n pair ($i,$j) too close: $d',
            );
          }
        }
      }
    });

    test('a single-member tag sits at its cluster center', () {
      final sky = _skyFor(1, 'solo');
      final group = sky.groups.firstWhere((g) => g.tag == 'solo');
      expect(sky.positions['solo0'], group.center);
    });

    test('a pair is still linked by a connecting line', () {
      final sky = _skyFor(2, 'duo');
      final linked = sky.lines.where(
        (l) =>
            (l.a == 'duo0' && l.b == 'duo1') ||
            (l.a == 'duo1' && l.b == 'duo0'),
      );
      expect(linked, hasLength(1));
    });
  });
}
