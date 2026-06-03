import '../models/contact.dart';
import 'tag_rules.dart';

/// A constellation in the Mutuals view: a tag-group (or the catch-all
/// "Orphans") with its member count and the color index used to tint it.
class ClusterSummary {
  /// The tag, or `'Orphans'` for link-less contacts.
  final String tag;
  final int count;

  /// Index into the cluster palette — matches the constellation's color in the
  /// graph (named tags sorted alphabetically, then Orphans).
  final int colorIndex;
  final bool isOrphans;

  const ClusterSummary({
    required this.tag,
    required this.count,
    required this.colorIndex,
    required this.isOrphans,
  });
}

/// Summarizes the Mutuals constellations: contacts grouped by their primary
/// linking tag (the same rule the graph uses — [primaryLinkingTag], which
/// ignores the Imported tag), with link-less contacts gathered under "Orphans".
/// Color indices match `computeConstellationSky` (alphabetical, Orphans last).
List<ClusterSummary> clusterSummaries(List<Contact> contacts) {
  final byTag = <String, int>{};
  var orphans = 0;
  for (final c in contacts) {
    final tag = primaryLinkingTag(c.tags);
    if (tag.isEmpty) {
      orphans++;
    } else {
      byTag[tag] = (byTag[tag] ?? 0) + 1;
    }
  }

  final named = byTag.keys.toList()..sort();
  final result = <ClusterSummary>[
    for (var i = 0; i < named.length; i++)
      ClusterSummary(
        tag: named[i],
        count: byTag[named[i]]!,
        colorIndex: i,
        isOrphans: false,
      ),
  ];
  if (orphans > 0) {
    result.add(ClusterSummary(
      tag: 'Orphans',
      count: orphans,
      colorIndex: named.length,
      isOrphans: true,
    ));
  }
  return result;
}
