import '../models/contact.dart';
import 'relatives.dart';
import 'reach_out_service.dart';
import 'relationship_strength.dart';

/// Strength (0..100) at or above which a contact counts as a "strong tie".
const double kStrongTieThreshold = 66.0;

/// An immutable set of filters applied to the contact list (on top of the text
/// search). All active criteria are ANDed together; within [tags] a contact
/// matches if it has ANY of the selected tags.
class ContactFilter {
  /// Selected tag names; a contact matches if it carries any of them
  /// (case-insensitive). Empty = no tag filter.
  final Set<String> tags;

  /// Only contacts who share a last name with at least one other contact.
  final bool familyOnly;

  /// Only contacts with no tags.
  final bool untaggedOnly;

  /// Only contacts that have a photo.
  final bool withPhotoOnly;

  /// Only contacts whose reach-out is overdue.
  final bool needsAttentionOnly;

  /// Only strong ties (strength >= [kStrongTieThreshold]).
  final bool strongOnly;

  const ContactFilter({
    this.tags = const {},
    this.familyOnly = false,
    this.untaggedOnly = false,
    this.withPhotoOnly = false,
    this.needsAttentionOnly = false,
    this.strongOnly = false,
  });

  /// The empty filter (matches everything).
  static const ContactFilter none = ContactFilter();

  bool get isActive =>
      tags.isNotEmpty ||
      familyOnly ||
      untaggedOnly ||
      withPhotoOnly ||
      needsAttentionOnly ||
      strongOnly;

  /// Number of active criteria (each selected tag counts once), for a badge.
  int get activeCount =>
      tags.length +
      (familyOnly ? 1 : 0) +
      (untaggedOnly ? 1 : 0) +
      (withPhotoOnly ? 1 : 0) +
      (needsAttentionOnly ? 1 : 0) +
      (strongOnly ? 1 : 0);

  ContactFilter copyWith({
    Set<String>? tags,
    bool? familyOnly,
    bool? untaggedOnly,
    bool? withPhotoOnly,
    bool? needsAttentionOnly,
    bool? strongOnly,
  }) {
    return ContactFilter(
      tags: tags ?? this.tags,
      familyOnly: familyOnly ?? this.familyOnly,
      untaggedOnly: untaggedOnly ?? this.untaggedOnly,
      withPhotoOnly: withPhotoOnly ?? this.withPhotoOnly,
      needsAttentionOnly: needsAttentionOnly ?? this.needsAttentionOnly,
      strongOnly: strongOnly ?? this.strongOnly,
    );
  }

  /// Returns a copy with [tag] toggled in/out of the tag set. Selecting a tag
  /// also clears [untaggedOnly] (the two are contradictory).
  ContactFilter toggleTag(String tag) {
    final next = {...tags};
    if (!next.remove(tag)) next.add(tag);
    return copyWith(tags: next, untaggedOnly: next.isEmpty ? untaggedOnly : false);
  }
}

/// Ids of contacts that belong to a "family": their (normalized) last name is
/// shared by at least two contacts.
Set<String> familyContactIds(List<Contact> contacts) {
  final groups = <String, List<String>>{};
  for (final c in contacts) {
    final key = normalizedLastName(c);
    if (key.isEmpty) continue;
    groups.putIfAbsent(key, () => []).add(c.id);
  }
  final ids = <String>{};
  for (final group in groups.values) {
    if (group.length >= 2) ids.addAll(group);
  }
  return ids;
}

/// Applies [filter] to [contacts]. Returns the same list instance when the
/// filter is inactive. [now] drives the time-based criteria (reach-out,
/// strength) and is injected for deterministic testing.
List<Contact> applyContactFilter(
  List<Contact> contacts,
  ContactFilter filter, {
  required DateTime now,
}) {
  if (!filter.isActive) return contacts;

  final wantTags = filter.tags.map((t) => t.toLowerCase()).toSet();
  final familyIds =
      filter.familyOnly ? familyContactIds(contacts) : const <String>{};

  return contacts.where((c) {
    if (wantTags.isNotEmpty) {
      final has = c.tags.any((t) => wantTags.contains(t.toLowerCase()));
      if (!has) return false;
    }
    if (filter.untaggedOnly &&
        c.tags.any((t) => t.trim().isNotEmpty)) {
      return false;
    }
    if (filter.withPhotoOnly && !c.hasPhoto) return false;
    if (filter.familyOnly && !familyIds.contains(c.id)) return false;
    if (filter.needsAttentionOnly && !reachOutStatus(c, now: now).isOverdue) {
      return false;
    }
    if (filter.strongOnly && strengthScore(c, now: now) < kStrongTieThreshold) {
      return false;
    }
    return true;
  }).toList();
}
