import '../models/contact.dart';

/// Normalized last name used to group relatives: trimmed and lowercased.
/// Empty when the contact has no last name.
String normalizedLastName(Contact contact) => contact.lastName.trim().toLowerCase();

/// Contacts (excluding [contact]) that share its non-empty last name, sorted by
/// display name. Returns `[]` when the contact has no last name.
List<Contact> relativesOf(Contact contact, Iterable<Contact> all) {
  final key = normalizedLastName(contact);
  if (key.isEmpty) return const [];
  return all
      .where((c) => c.id != contact.id && normalizedLastName(c) == key)
      .toList()
    ..sort((a, b) =>
        a.displayName.toLowerCase().compareTo(b.displayName.toLowerCase()));
}

/// Undirected id pairs linking contacts that share a last name, for drawing
/// graph edges. Each surname group is connected as a chain (sorted by id) so a
/// group of N yields N-1 edges rather than N² — enough to make the family one
/// connected component without cluttering large groups.
List<({String a, String b})> sameLastNameLinks(List<Contact> contacts) {
  final groups = <String, List<String>>{};
  for (final c in contacts) {
    final key = normalizedLastName(c);
    if (key.isEmpty) continue;
    groups.putIfAbsent(key, () => []).add(c.id);
  }
  final links = <({String a, String b})>[];
  for (final ids in groups.values) {
    if (ids.length < 2) continue;
    ids.sort();
    for (var i = 0; i < ids.length - 1; i++) {
      links.add((a: ids[i], b: ids[i + 1]));
    }
  }
  return links;
}

/// Returns [all] with [saved] and its same-last-name peers cross-linked as
/// mutual connections. Additive only — existing connections are never removed,
/// and contacts in other surname groups are returned unchanged. Touched
/// contacts get a fresh [Contact.updatedAt] (defaulting to [now]) so the new
/// links sync. Immutability is preserved (new instances for changed contacts).
List<Contact> linkRelativesOf(
  Contact saved,
  List<Contact> all, {
  DateTime? now,
}) {
  final key = normalizedLastName(saved);
  if (key.isEmpty) return all;
  final groupIds =
      all.where((c) => normalizedLastName(c) == key).map((c) => c.id).toSet();
  if (groupIds.length < 2) return all;

  final stamp = now ?? DateTime.now();
  return [
    for (final c in all)
      if (groupIds.contains(c.id))
        _withConnections(c, groupIds.where((id) => id != c.id), stamp)
      else
        c,
  ];
}

/// Cross-links every same-last-name group in [all] as mutual connections in a
/// single pass — the retroactive counterpart to [linkRelativesOf]. Additive
/// only; contacts in singleton surname groups (or with no last name) are
/// returned unchanged (same instance), so callers can detect what changed by
/// identity. Changed contacts get a fresh [Contact.updatedAt] for sync.
List<Contact> linkAllRelatives(List<Contact> all, {DateTime? now}) {
  final groups = <String, List<Contact>>{};
  for (final c in all) {
    final key = normalizedLastName(c);
    if (key.isEmpty) continue;
    groups.putIfAbsent(key, () => []).add(c);
  }

  final additions = <String, Set<String>>{};
  for (final group in groups.values) {
    if (group.length < 2) continue;
    final ids = group.map((c) => c.id).toSet();
    for (final c in group) {
      additions
          .putIfAbsent(c.id, () => <String>{})
          .addAll(ids.where((id) => id != c.id));
    }
  }

  final stamp = now ?? DateTime.now();
  return [
    for (final c in all)
      if (additions.containsKey(c.id))
        _withConnections(c, additions[c.id]!, stamp)
      else
        c,
  ];
}

/// Adds [extra] connection ids to [c] (deduped), returning the same instance
/// when nothing new is added so unchanged contacts keep their identity.
Contact _withConnections(Contact c, Iterable<String> extra, DateTime now) {
  final existing = c.connections.toSet();
  final merged = {...existing, ...extra};
  if (merged.length == existing.length) return c;
  return c.copyWith(
    connections: merged.toList()..sort(),
    updatedAt: now,
  );
}
