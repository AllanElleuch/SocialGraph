import 'dart:convert';

import '../models/contact.dart';
import 'contact_merge.dart';
import 'duplicate_detector.dart';

/// Pure, dependency-free backup export/import logic (RFC-004, U4.2).
///
/// This layer performs no file I/O, sharing, or platform interaction. It only
/// transforms between [Contact] lists and JSON strings, and merges overlapping
/// imports. The UI layer wires this to file pickers / share sheets separately.
class BackupService {
  /// Current backup document schema version.
  static const int currentVersion = 1;

  /// Serialize [contacts] into a pretty-printed backup document of the form:
  /// `{ "version": 1, "exportedCount": N, "contacts": [...] }`.
  String exportJson(List<Contact> contacts) {
    final document = <String, dynamic>{
      'version': currentVersion,
      'exportedCount': contacts.length,
      'contacts': contacts.map((c) => c.toJson()).toList(),
    };
    return const JsonEncoder.withIndent('  ').convert(document);
  }

  /// Parse a backup document into a [Contact] list.
  ///
  /// Tolerates either the wrapped form produced by [exportJson] or a bare JSON
  /// array of contact objects. Throws a [FormatException] with a clear message
  /// when the input is not valid JSON or has an unexpected shape.
  List<Contact> parseImport(String json) {
    final dynamic decoded;
    try {
      decoded = jsonDecode(json);
    } on FormatException catch (e) {
      throw FormatException('Backup is not valid JSON: ${e.message}');
    }

    final List<dynamic> rawContacts;
    if (decoded is List) {
      rawContacts = decoded;
    } else if (decoded is Map<String, dynamic>) {
      final contacts = decoded['contacts'];
      if (contacts is! List) {
        throw const FormatException(
          'Backup document is missing a "contacts" array.',
        );
      }
      rawContacts = contacts;
    } else {
      throw const FormatException(
        'Backup must be a JSON object or array of contacts.',
      );
    }

    try {
      return rawContacts
          .map((e) => Contact.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (e) {
      throw FormatException('Backup contains an invalid contact: $e');
    }
  }

  /// Parse [json] and merge its contacts into [existing].
  ///
  /// The imported contacts are concatenated after [existing], duplicate groups
  /// are detected across the combined set, and each group is collapsed via
  /// [mergeContacts] (the first member of a group is the primary). Contacts not
  /// in any duplicate group pass through unchanged, preserving input order.
  List<Contact> importMerged(List<Contact> existing, String json) {
    final imported = parseImport(json);
    final combined = <Contact>[...existing, ...imported];

    final groups = findDuplicateGroups(combined);
    if (groups.isEmpty) return combined;

    // Map every contact id that belongs to a duplicate group to its primary id,
    // so we can drop the non-primary members and substitute the merged result.
    final mergedByPrimaryId = <String, Contact>{};
    final mergedAwayIds = <String>{};
    for (final group in groups) {
      final primary = group.first;
      final others = group.sublist(1);
      mergedByPrimaryId[primary.id] = mergeContacts(primary, others);
      for (final other in others) {
        mergedAwayIds.add(other.id);
      }
    }

    final result = <Contact>[];
    for (final contact in combined) {
      if (mergedAwayIds.contains(contact.id)) {
        // Non-primary group member: represented by its primary, skip it.
        continue;
      }
      final merged = mergedByPrimaryId[contact.id];
      result.add(merged ?? contact);
    }
    return result;
  }
}
