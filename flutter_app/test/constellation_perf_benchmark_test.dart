import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:social_graph/models/contact.dart';
import 'package:social_graph/models/graph_node.dart';
import 'package:social_graph/painters/constellation_layout.dart';
import 'package:social_graph/painters/graph_painter.dart';
import 'package:social_graph/services/tag_rules.dart';

/// Lightweight benchmarks for the constellation pipeline at the user's scale
/// (~1500 contacts, mostly "Imported"-only → the loose region). These are not
/// strict assertions of wall-clock speed (which varies by machine) but they
/// (a) print timings so regressions are visible, and (b) guard against gross
/// blow-ups with generous ceilings.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const size = Size(420, 900);
  final now = DateTime(2026, 6, 3);

  List<Contact> makeContacts(int total, int tagged) {
    return [
      for (var i = 0; i < total; i++)
        Contact(
          id: 'c$i',
          firstName: 'Name$i',
          lastName: i % 7 == 0 ? 'Shared' : 'L$i',
          // First `tagged` get a real tag; the rest are Imported-only (loose).
          tags: i < tagged ? const ['Work'] : const ['Imported'],
          locationMet: '',
          connections: const [],
        ),
    ];
  }

  ({Object sky, List<GraphNode> nodes, List<GraphLink> links, Map<String, int> clusters})
      buildGraph(List<Contact> contacts) {
    final items = contacts
        .map((c) => (id: c.id, tag: primaryLinkingTag(c.tags)))
        .toList();
    final sky = computeConstellationSky(items);
    final nodes = [
      for (final c in contacts)
        GraphNode(
          id: c.id,
          name: c.displayName,
          data: c,
          x: (sky.positions[c.id] ?? Offset.zero).dx,
          y: (sky.positions[c.id] ?? Offset.zero).dy,
        ),
    ];
    final links = [
      for (final l in sky.lines)
        GraphLink(sourceId: l.a, targetId: l.b, type: 'connection'),
    ];
    return (sky: sky, nodes: nodes, links: links, clusters: sky.groupIndex);
  }

  double timePaint(GraphPainter painter, ValueNotifier<Matrix4> vt, double scale,
      int frames) {
    vt.value = Matrix4.diagonal3Values(scale, scale, 1.0);
    // Warm-up paint (triggers the painter's lazy strength/id caches).
    {
      final rec = ui.PictureRecorder();
      painter.paint(Canvas(rec), size);
      rec.endRecording().dispose();
    }
    final sw = Stopwatch()..start();
    for (var i = 0; i < frames; i++) {
      final rec = ui.PictureRecorder();
      painter.paint(Canvas(rec), size);
      rec.endRecording().dispose();
    }
    sw.stop();
    return sw.elapsedMicroseconds / frames / 1000.0; // ms per frame
  }

  test('computeConstellationSky scales to 1500 contacts', () {
    final contacts = makeContacts(1500, 50);
    final sw = Stopwatch()..start();
    final g = buildGraph(contacts);
    sw.stop();
    // ignore: avoid_print
    print('[bench] layout 1500 contacts: ${sw.elapsedMilliseconds} ms '
        '(${g.nodes.length} nodes, ${g.links.length} lines)');
    expect(g.nodes.length, 1500);
    expect(sw.elapsedMilliseconds, lessThan(2000));
  });

  test('paint 1500 nodes: overview vs zoomed (warm frames)', () {
    final contacts = makeContacts(1500, 50);
    final g = buildGraph(contacts);
    final vt = ValueNotifier<Matrix4>(Matrix4.identity());
    final painter = GraphPainter(
      nodes: g.nodes,
      links: g.links,
      pivot: PivotType.mutual,
      minTime: 0,
      maxTime: 0,
      clusters: g.clusters,
      viewTransform: vt,
      now: now,
    );

    final overview = timePaint(painter, vt, 0.12, 20); // all visible, tiny
    final zoomed = timePaint(painter, vt, 4.0, 20); // few visible (culled)

    // ignore: avoid_print
    print('[bench] paint/frame — overview: ${overview.toStringAsFixed(2)} ms, '
        'zoomed: ${zoomed.toStringAsFixed(2)} ms');

    // Generous ceilings: catch a gross regression without being machine-fragile.
    expect(overview, lessThan(120));
    expect(zoomed, lessThan(120));
    vt.dispose();
  });
}
