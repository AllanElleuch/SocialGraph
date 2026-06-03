import '../models/contact.dart';

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
