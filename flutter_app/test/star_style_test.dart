import 'package:flutter_test/flutter_test.dart';
import 'package:social_graph/models/graph_node.dart';
import 'package:social_graph/painters/star_style.dart';

void main() {
  group('starTemperatureColor', () {
    test('cool (low strength) is redder than hot (high strength)', () {
      final cool = starTemperatureColor(0);
      final hot = starTemperatureColor(100);
      // Cool end leans red; hot end leans blue.
      expect(cool.r, greaterThan(cool.b));
      expect(hot.b, greaterThan(hot.r));
    });

    test('clamps out-of-range and non-finite input', () {
      expect(starTemperatureColor(-10), starTemperatureColor(0));
      expect(starTemperatureColor(999), starTemperatureColor(100));
      expect(starTemperatureColor(double.nan), starTemperatureColor(0));
    });
  });

  group('clusterColor', () {
    test('cycles the palette and handles negatives', () {
      expect(clusterColor(0), kClusterPalette[0]);
      expect(clusterColor(kClusterPalette.length), kClusterPalette[0]);
      expect(clusterColor(-5), kClusterPalette[0]);
    });
  });

  group('starColorModeFromName', () {
    test('round-trips and defaults to temperature', () {
      expect(starColorModeFromName('cluster'), StarColorMode.cluster);
      expect(starColorModeFromName('temperature'), StarColorMode.temperature);
      expect(starColorModeFromName(null), StarColorMode.temperature);
      expect(starColorModeFromName('bogus'), StarColorMode.temperature);
    });
  });

  group('assignClusters', () {
    GraphLink link(String a, String b) =>
        GraphLink(sourceId: a, targetId: b, type: 'connection');

    test('groups connected components and isolates singletons', () {
      final ids = ['a', 'b', 'c', 'd', 'e'];
      // a-b-c connected; d-e connected; (no singletons here)
      final links = [link('a', 'b'), link('b', 'c'), link('d', 'e')];

      final clusters = assignClusters(ids, links);

      // a,b,c share a cluster; d,e share another; the two differ.
      expect(clusters['a'], clusters['b']);
      expect(clusters['b'], clusters['c']);
      expect(clusters['d'], clusters['e']);
      expect(clusters['a'], isNot(clusters['d']));
    });

    test('a node with no links is its own constellation', () {
      final clusters = assignClusters(['a', 'b', 'solo'], [link('a', 'b')]);
      expect(clusters['solo'], isNot(clusters['a']));
    });

    test('cluster indices are deterministic (ordered by smallest member)', () {
      final clusters = assignClusters(
        ['z', 'a', 'm'],
        const <GraphLink>[], // all singletons
      );
      // Ordered by id: a=0, m=1, z=2.
      expect(clusters['a'], 0);
      expect(clusters['m'], 1);
      expect(clusters['z'], 2);
    });
  });

  group('twinkleBrightness', () {
    test('stays within [1 - amount, 1]', () {
      for (var t = 0.0; t < 10; t += 0.25) {
        final v = twinkleBrightness(t, 1.3, amount: 0.18);
        expect(v, inInclusiveRange(1 - 0.18 - 1e-9, 1 + 1e-9));
      }
    });

    test('is seamless across the 0..2π animation loop', () {
      // Painter feeds value*2π; at the loop boundary the result must match.
      const phase = 0.7;
      final start = twinkleBrightness(0, phase, speed: 1.0);
      final end = twinkleBrightness(2 * 3.141592653589793, phase, speed: 1.0);
      expect((start - end).abs(), lessThan(1e-6));
    });
  });
}
