import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

import '../models/contact.dart';

/// Thrown when a cloud backup operation fails.
class CloudBackupException implements Exception {
  final String message;
  const CloudBackupException(this.message);

  @override
  String toString() => 'CloudBackupException: $message';
}

/// Metadata for a single cloud backup snapshot.
///
/// The full contact list is only loaded on restore; listings carry just the
/// lightweight summary so browsing many backups stays cheap.
class CloudBackup {
  /// Firestore document id of the backup snapshot.
  final String id;

  /// When the snapshot was created (server time). Null while the server
  /// timestamp is still resolving immediately after a write.
  final DateTime? createdAt;

  /// Number of contacts captured in the snapshot.
  final int contactCount;

  /// Optional user-supplied label (e.g. "before big cleanup").
  final String? label;

  const CloudBackup({
    required this.id,
    required this.createdAt,
    required this.contactCount,
    this.label,
  });
}

/// Stores timestamped contact snapshots in Cloud Firestore so a user can roll
/// back to an earlier state (RFC-004, U4.2 cloud variant).
///
/// Snapshots live under `users/{uid}/backups/{autoId}`, separate from the live
/// `users/{uid}` sync document, so creating or restoring a backup never races
/// with ordinary sync. No Firestore access happens at construction time.
///
/// Firestore caps a single document at 1 MiB. A snapshot of a large address
/// book (especially with embedded photo thumbnails) easily exceeds that, which
/// Firestore reports as `invalid-argument`. To stay under the cap, the contact
/// payload is split across documents in a `chunks` subcollection rather than
/// stored inline in the parent metadata document.
class CloudBackupService {
  CloudBackupService({FirebaseFirestore? firestore}) : _firestore = firestore;

  final FirebaseFirestore? _firestore;

  /// Current backup document schema version. v2 splits contacts into a `chunks`
  /// subcollection; v1 stored them inline in the parent document.
  static const int currentVersion = 2;

  /// Target maximum encoded size of the contacts payload per chunk document, in
  /// bytes. Kept well under Firestore's 1 MiB hard limit to leave headroom for
  /// field-name and array-index overhead the SDK adds on top of the JSON bytes.
  static const int _maxChunkBytes = 700 * 1024;

  FirebaseFirestore get _db => _firestore ?? FirebaseFirestore.instance;

  /// Tag prefixed to every log line so cloud-backup activity is easy to filter
  /// in the device console (e.g. `flutter logs | grep CloudBackup`).
  static const String _logTag = 'CloudBackup';

  /// Shortens a uid for logs so we never dump a full identifier to the console.
  String _shortUid(String uid) =>
      uid.length <= 6 ? uid : '${uid.substring(0, 6)}…';

  /// The Firestore path a backup operation touches, for logging. [backupId] is
  /// appended when the op targets a single snapshot. The uid is shortened so we
  /// never log a full identifier.
  String _path(String uid, [String? backupId]) {
    final base = 'users/${_shortUid(uid)}/backups';
    return backupId == null ? base : '$base/$backupId';
  }

  /// Annotates a Firestore error with a targeted hint when it is a
  /// permission-denied failure, so the console points straight at the cause:
  /// security rules that don't grant the signed-in user access to [path].
  String _explain(Object error, String path) {
    final text = error.toString();
    if (text.contains('permission-denied')) {
      return '$text\n  ↳ Firestore security rules deny access to "$path". '
          'The signed-in user can reach users/{uid} but NOT the backups '
          'subcollection — deploy firestore.rules '
          '(`firebase deploy --only firestore:rules`).';
    }
    return text;
  }

  CollectionReference<Map<String, dynamic>> _backups(String uid) =>
      _db.collection('users').doc(uid).collection('backups');

  /// Captures [contacts] as a new snapshot and returns its document id.
  ///
  /// Contacts are written to a `chunks` subcollection in size-bounded slices so
  /// no single document approaches Firestore's 1 MiB limit. The parent metadata
  /// document is written last: until it exists the backup does not appear in
  /// [listBackups], so a partial write never surfaces as a usable snapshot.
  Future<String> createBackup(
    String uid,
    List<Contact> contacts, {
    String? label,
  }) async {
    final labelSuffix =
        (label != null && label.trim().isNotEmpty) ? ' "${label.trim()}"' : '';
    final doc = _backups(uid).doc();
    final path = _path(uid, doc.id);
    final chunks = _chunkContacts(contacts);
    debugPrint('$_logTag: creating backup$labelSuffix at $path '
        '(${contacts.length} contacts in ${chunks.length} chunk(s))…');
    final stopwatch = Stopwatch()..start();
    try {
      final chunksRef = doc.collection('chunks');
      for (var i = 0; i < chunks.length; i++) {
        await chunksRef.doc(_chunkId(i)).set({'contacts': chunks[i]});
      }
      await doc.set({
        'version': currentVersion,
        'createdAt': FieldValue.serverTimestamp(),
        'contactCount': contacts.length,
        'chunkCount': chunks.length,
        if (label != null && label.trim().isNotEmpty) 'label': label.trim(),
      });
      debugPrint('$_logTag: backup created at $path '
          '(${contacts.length} contacts, ${chunks.length} chunk(s), '
          '${stopwatch.elapsedMilliseconds}ms)');
      return doc.id;
    } catch (e) {
      debugPrint('$_logTag: createBackup FAILED at $path after '
          '${stopwatch.elapsedMilliseconds}ms: ${_explain(e, path)}');
      throw CloudBackupException('Failed to create backup: $e');
    }
  }

  /// Splits [contacts] into slices whose encoded JSON stays under
  /// [_maxChunkBytes]. A single contact larger than the budget still gets its
  /// own (over-budget) chunk rather than being dropped.
  List<List<Map<String, dynamic>>> _chunkContacts(List<Contact> contacts) {
    final chunks = <List<Map<String, dynamic>>>[];
    var current = <Map<String, dynamic>>[];
    var currentBytes = 0;
    for (final contact in contacts) {
      final json = contact.toJson();
      final bytes = utf8.encode(jsonEncode(json)).length;
      if (current.isNotEmpty && currentBytes + bytes > _maxChunkBytes) {
        chunks.add(current);
        current = <Map<String, dynamic>>[];
        currentBytes = 0;
      }
      current.add(json);
      currentBytes += bytes;
    }
    if (current.isNotEmpty) chunks.add(current);
    return chunks;
  }

  /// Zero-padded chunk document id so lexical ordering matches write order.
  String _chunkId(int index) => index.toString().padLeft(6, '0');

  /// Lists the user's backups, newest first. Returns `[]` when none exist.
  Future<List<CloudBackup>> listBackups(String uid) async {
    final path = _path(uid);
    debugPrint('$_logTag: listing backups at $path…');
    final stopwatch = Stopwatch()..start();
    try {
      final snapshot =
          await _backups(uid).orderBy('createdAt', descending: true).get();
      final backups = snapshot.docs.map(_backupFromDoc).toList();
      debugPrint('$_logTag: listed ${backups.length} backup(s) from $path '
          '(${stopwatch.elapsedMilliseconds}ms)');
      return backups;
    } catch (e) {
      debugPrint('$_logTag: listBackups FAILED at $path after '
          '${stopwatch.elapsedMilliseconds}ms: ${_explain(e, path)}');
      throw CloudBackupException('Failed to list backups: $e');
    }
  }

  /// Loads the full contact list captured in the snapshot [backupId].
  Future<List<Contact>> restoreBackup(String uid, String backupId) async {
    final path = _path(uid, backupId);
    debugPrint('$_logTag: restoring backup at $path…');
    final stopwatch = Stopwatch()..start();
    try {
      final doc = _backups(uid).doc(backupId);
      final snapshot = await doc.get();
      if (!snapshot.exists) {
        debugPrint('$_logTag: restore failed — no document at $path');
        throw const CloudBackupException('That backup no longer exists.');
      }
      // Legacy (v1) backups stored contacts inline; v2+ stores them in chunks.
      final data = snapshot.data();
      final contacts = data != null && data['contacts'] is List
          ? _contactsFromData(data)
          : await _contactsFromChunks(doc);
      debugPrint('$_logTag: restored ${contacts.length} contacts from '
          '$path (${stopwatch.elapsedMilliseconds}ms)');
      return contacts;
    } on CloudBackupException {
      rethrow;
    } catch (e) {
      debugPrint('$_logTag: restoreBackup FAILED at $path after '
          '${stopwatch.elapsedMilliseconds}ms: ${_explain(e, path)}');
      throw CloudBackupException('Failed to restore backup: $e');
    }
  }

  /// Permanently removes the snapshot [backupId], including its `chunks`
  /// subcollection (deleting a document does not cascade to subcollections in
  /// Firestore, so chunks must be removed explicitly to avoid orphans).
  Future<void> deleteBackup(String uid, String backupId) async {
    final path = _path(uid, backupId);
    debugPrint('$_logTag: deleting backup at $path…');
    try {
      final doc = _backups(uid).doc(backupId);
      final chunks = await doc.collection('chunks').get();
      for (final chunk in chunks.docs) {
        await chunk.reference.delete();
      }
      await doc.delete();
      debugPrint('$_logTag: deleted backup at $path '
          '(${chunks.docs.length} chunk(s))');
    } catch (e) {
      debugPrint('$_logTag: deleteBackup FAILED at $path: ${_explain(e, path)}');
      throw CloudBackupException('Failed to delete backup: $e');
    }
  }

  CloudBackup _backupFromDoc(
    QueryDocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final data = doc.data();
    final created = data['createdAt'];
    return CloudBackup(
      id: doc.id,
      createdAt: created is Timestamp ? created.toDate() : null,
      contactCount: (data['contactCount'] as num?)?.toInt() ?? 0,
      label: data['label'] as String?,
    );
  }

  /// Reads and concatenates the contacts stored across a backup's `chunks`
  /// subcollection, ordered by chunk document id (which encodes write order).
  Future<List<Contact>> _contactsFromChunks(
    DocumentReference<Map<String, dynamic>> doc,
  ) async {
    final snapshot =
        await doc.collection('chunks').orderBy(FieldPath.documentId).get();
    return snapshot.docs
        .expand((chunk) => _contactsFromData(chunk.data()))
        .toList();
  }

  List<Contact> _contactsFromData(Map<String, dynamic>? data) {
    if (data == null) return [];
    final raw = data['contacts'];
    if (raw is! List) return [];
    return raw
        .whereType<Map>()
        .map((e) => Contact.fromJson(Map<String, dynamic>.from(e)))
        .toList();
  }
}
