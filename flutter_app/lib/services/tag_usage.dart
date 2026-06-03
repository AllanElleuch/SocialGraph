import '../models/contact.dart';

/// The tag a graph edge between two contacts represents: their first shared
/// tag, but preferring a meaningful tag over the generic [kImportedTag] system
/// tag (which most imported contacts carry and which would otherwise shadow the
/// tag the user actually clicked). Returns `''` when they share no tag.
String sharedTagForEdge(List<String> a, List<String> b) {
  final shared = a.where((t) => b.contains(t)).toList();
  if (shared.isEmpty) return '';
  return shared.firstWhere((t) => t != kImportedTag, orElse: () => shared.first);
}

/// Counts how many contacts carry each tag, keyed by the exact (trimmed) tag.
///
/// A tag repeated on a single contact is counted once for that contact, so the
/// value answers "how many contacts use this tag" (e.g. `{'accro yoga': 144}`).
Map<String, int> tagUsageCounts(Iterable<Contact> contacts) {
  final counts = <String, int>{};
  for (final contact in contacts) {
    final seen = <String>{};
    for (final raw in contact.tags) {
      final tag = raw.trim();
      if (tag.isEmpty || !seen.add(tag)) continue;
      counts[tag] = (counts[tag] ?? 0) + 1;
    }
  }
  return counts;
}
