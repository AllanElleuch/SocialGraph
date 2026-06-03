import 'package:flutter_test/flutter_test.dart';
import 'package:social_graph/models/contact.dart';
import 'package:social_graph/services/cluster_summary.dart';

Contact c(String id, List<String> tags) => Contact(
      id: id,
      firstName: id,
      lastName: '',
      tags: tags,
      locationMet: '',
      connections: const [],
    );

void main() {
  test('groups by primary linking tag with counts', () {
    final summaries = clusterSummaries([
      c('a', ['Work']),
      c('b', ['Work']),
      c('c', ['Family']),
    ]);
    final byTag = {for (final s in summaries) s.tag: s.count};
    expect(byTag, {'Work': 2, 'Family': 1});
  });

  test('color index follows alphabetical order (matches the graph)', () {
    final summaries = clusterSummaries([
      c('a', ['Zebra']),
      c('b', ['Apple']),
    ]);
    final apple = summaries.firstWhere((s) => s.tag == 'Apple');
    final zebra = summaries.firstWhere((s) => s.tag == 'Zebra');
    expect(apple.colorIndex, 0);
    expect(zebra.colorIndex, 1);
  });

  test('link-less contacts collapse into an Orphans cluster, listed last', () {
    final summaries = clusterSummaries([
      c('a', ['Work']),
      c('b', ['Imported']), // Imported is not a linking tag → orphan
      c('c', const []), // untagged → orphan
    ]);
    final orphans = summaries.firstWhere((s) => s.isOrphans);
    expect(orphans.tag, 'Orphans');
    expect(orphans.count, 2);
    expect(orphans.colorIndex, 1); // after the single named tag (Work=0)
  });

  test('no Orphans cluster when everyone is tagged', () {
    final summaries = clusterSummaries([c('a', ['Work'])]);
    expect(summaries.any((s) => s.isOrphans), isFalse);
  });
}
