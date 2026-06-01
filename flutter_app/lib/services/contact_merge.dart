import '../models/contact.dart';

/// Pure, immutable merge logic for combining duplicate contacts.

/// Pick the first non-empty trimmed string from [primaryValue] then [others].
String _preferNonEmptyString(String primaryValue, List<String> others) {
  if (primaryValue.trim().isNotEmpty) return primaryValue;
  for (final value in others) {
    if (value.trim().isNotEmpty) return value;
  }
  return primaryValue;
}

/// Pick primary's value if non-null, else the first non-null among [others].
double? _preferNonNullDouble(double? primaryValue, List<double?> others) {
  if (primaryValue != null) return primaryValue;
  for (final value in others) {
    if (value != null) return value;
  }
  return null;
}

/// Union a sequence of string lists, deduping while preserving first-seen order.
List<String> _unionDedupe(Iterable<Iterable<String>> lists) {
  final seen = <String>{};
  final result = <String>[];
  for (final list in lists) {
    for (final item in list) {
      if (seen.add(item)) result.add(item);
    }
  }
  return result;
}

/// Merge [primary] with [others] into a single contact, preserving primary.id.
///
/// Rules:
///   - tags, connections: union + dedupe; connections strip merged ids + self.
///   - interactions: concatenated and sorted newest-first by date.
///   - scalar fields: prefer primary's non-empty value, else first non-empty.
///   - dateMet: earliest among inputs.
///   - lastInteraction: latest among inputs.
///   - updatedAt: latest among inputs (null only if all null).
Contact mergeContacts(Contact primary, List<Contact> others) {
  if (others.isEmpty) return primary;

  final all = <Contact>[primary, ...others];

  // Ids being merged away (everything except primary) plus self-id.
  final removeFromConnections = <String>{primary.id};
  for (final other in others) {
    removeFromConnections.add(other.id);
  }

  // Tags: union + dedupe.
  final tags = _unionDedupe(all.map((c) => c.tags));

  // Connections: union + dedupe, then drop merged-away ids and self.
  final connections = _unionDedupe(all.map((c) => c.connections))
      .where((id) => !removeFromConnections.contains(id))
      .toList();

  // Interactions: concatenate, sort newest-first by date.
  final interactions = <InteractionEvent>[];
  for (final c in all) {
    interactions.addAll(c.interactions);
  }
  interactions.sort((a, b) => b.date.compareTo(a.date));

  // Scalar fields: prefer primary, else first non-empty among others.
  final phone = _preferNonEmptyString(
      primary.phone, others.map((c) => c.phone).toList());
  final email = _preferNonEmptyString(
      primary.email, others.map((c) => c.email).toList());
  final workplace = _preferNonEmptyString(
      primary.workplace, others.map((c) => c.workplace).toList());
  final homeAddress = _preferNonEmptyString(
      primary.homeAddress, others.map((c) => c.homeAddress).toList());
  final notes = _preferNonEmptyString(
      primary.notes, others.map((c) => c.notes).toList());
  final locationMet = _preferNonEmptyString(
      primary.locationMet, others.map((c) => c.locationMet).toList());

  final lat =
      _preferNonNullDouble(primary.lat, others.map((c) => c.lat).toList());
  final lng =
      _preferNonNullDouble(primary.lng, others.map((c) => c.lng).toList());

  // dateMet: earliest among inputs (null = unknown; a known date wins over null).
  DateTime? dateMet = primary.dateMet;
  for (final c in all) {
    final d = c.dateMet;
    if (d != null && (dateMet == null || d.isBefore(dateMet))) dateMet = d;
  }

  // lastInteraction: latest among inputs.
  DateTime? lastInteraction = primary.lastInteraction;
  for (final c in all) {
    final value = c.lastInteraction;
    if (value == null) continue;
    if (lastInteraction == null || value.isAfter(lastInteraction)) {
      lastInteraction = value;
    }
  }

  // updatedAt: latest among inputs (null if all null).
  DateTime? updatedAt = primary.updatedAt;
  for (final c in all) {
    final value = c.updatedAt;
    if (value == null) continue;
    if (updatedAt == null || value.isAfter(updatedAt)) {
      updatedAt = value;
    }
  }

  return primary.copyWith(
    phone: phone,
    email: email,
    workplace: workplace,
    homeAddress: homeAddress,
    notes: notes,
    locationMet: locationMet,
    lat: lat,
    lng: lng,
    tags: tags,
    connections: connections,
    interactions: interactions,
    dateMet: dateMet,
    lastInteraction: lastInteraction,
    updatedAt: updatedAt,
  );
}

/// Repoint every contact's connections that reference a merged-away id to
/// [survivingId]. Returns a new list with deduped, self-reference-free
/// connection lists. Contacts whose connections are unchanged are left as-is.
List<Contact> rewriteConnections(
  List<Contact> all,
  String survivingId,
  Set<String> mergedAwayIds,
) {
  if (mergedAwayIds.isEmpty) return all;

  return all.map((contact) {
    final rewritten = <String>[];
    final seen = <String>{};
    var changed = false;

    for (final connId in contact.connections) {
      var target = connId;
      if (mergedAwayIds.contains(connId)) {
        target = survivingId;
        changed = true;
      }
      // Drop self-references created by repointing.
      if (target == contact.id) {
        changed = true;
        continue;
      }
      if (seen.add(target)) {
        rewritten.add(target);
      } else {
        changed = true; // a duplicate was collapsed
      }
    }

    if (!changed) return contact;
    return contact.copyWith(connections: rewritten);
  }).toList();
}
