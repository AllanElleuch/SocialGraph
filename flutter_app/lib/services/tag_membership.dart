import '../models/contact.dart';

/// Returns [contacts] with [tag] present on exactly the contacts whose ids are
/// in [memberIds] — adding it where missing and removing it where present but
/// no longer a member. Only [tag] is touched; all other tags are preserved.
///
/// Changed contacts get [now] (default: real time) as their `updatedAt` so the
/// edit syncs; unchanged contacts keep their identity, so callers can diff by
/// `identical`. A blank [tag] is a no-op.
List<Contact> applyTagMembership(
  List<Contact> contacts,
  String tag,
  Set<String> memberIds, {
  DateTime? now,
}) {
  final trimmed = tag.trim();
  if (trimmed.isEmpty) return contacts;
  final stamp = now ?? DateTime.now();
  return [
    for (final c in contacts)
      _withTag(c, trimmed, memberIds.contains(c.id), stamp),
  ];
}

/// Whether [contact] carries [tag] (compared trimmed).
bool hasTag(Contact contact, String tag) {
  final trimmed = tag.trim();
  return contact.tags.any((t) => t.trim() == trimmed);
}

Contact _withTag(Contact c, String tag, bool shouldHave, DateTime now) {
  final has = hasTag(c, tag);
  if (has == shouldHave) return c;
  final tags = shouldHave
      ? [...c.tags, tag]
      : c.tags.where((t) => t.trim() != tag).toList();
  return c.copyWith(tags: tags, updatedAt: now);
}
