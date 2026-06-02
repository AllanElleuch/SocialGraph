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
class CloudBackupService {
  CloudBackupService({FirebaseFirestore? firestore}) : _firestore = firestore;

  final FirebaseFirestore? _firestore;

  /// Current backup document schema version.
  static const int currentVersion = 1;

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
  Future<String> createBackup(
    String uid,
    List<Contact> contacts, {
    String? label,
  }) async {
    final labelSuffix =
        (label != null && label.trim().isNotEmpty) ? ' "${label.trim()}"' : '';
    debugPrint('$_logTag: creating backup$labelSuffix for ${_shortUid(uid)} '
        '(${contacts.length} contacts)…');
    final stopwatch = Stopwatch()..start();
    try {
      final doc = await _backups(uid).add({
        'version': currentVersion,
        'createdAt': FieldValue.serverTimestamp(),
        'contactCount': contacts.length,
        if (label != null && label.trim().isNotEmpty) 'label': label.trim(),
        'contacts': contacts.map((c) => c.toJson()).toList(),
      });
      debugPrint('$_logTag: backup created id=${doc.id} '
          '(${contacts.length} contacts, ${stopwatch.elapsedMilliseconds}ms)');
      return doc.id;
    } catch (e) {
      debugPrint('$_logTag: createBackup FAILED after '
          '${stopwatch.elapsedMilliseconds}ms: $e');
      throw CloudBackupException('Failed to create backup: $e');
    }
  }

  /// Lists the user's backups, newest first. Returns `[]` when none exist.
  Future<List<CloudBackup>> listBackups(String uid) async {
    debugPrint('$_logTag: listing backups for ${_shortUid(uid)}…');
    final stopwatch = Stopwatch()..start();
    try {
      final snapshot =
          await _backups(uid).orderBy('createdAt', descending: true).get();
      final backups = snapshot.docs.map(_backupFromDoc).toList();
      debugPrint('$_logTag: listed ${backups.length} backup(s) '
          '(${stopwatch.elapsedMilliseconds}ms)');
      return backups;
    } catch (e) {
      debugPrint('$_logTag: listBackups FAILED after '
          '${stopwatch.elapsedMilliseconds}ms: $e');
      throw CloudBackupException('Failed to list backups: $e');
    }
  }

  /// Loads the full contact list captured in the snapshot [backupId].
  Future<List<Contact>> restoreBackup(String uid, String backupId) async {
    debugPrint('$_logTag: restoring backup id=$backupId '
        'for ${_shortUid(uid)}…');
    final stopwatch = Stopwatch()..start();
    try {
      final snapshot = await _backups(uid).doc(backupId).get();
      if (!snapshot.exists) {
        debugPrint('$_logTag: restore failed — backup id=$backupId not found');
        throw const CloudBackupException('That backup no longer exists.');
      }
      final contacts = _contactsFromData(snapshot.data());
      debugPrint('$_logTag: restored ${contacts.length} contacts from '
          'id=$backupId (${stopwatch.elapsedMilliseconds}ms)');
      return contacts;
    } on CloudBackupException {
      rethrow;
    } catch (e) {
      debugPrint('$_logTag: restoreBackup FAILED after '
          '${stopwatch.elapsedMilliseconds}ms: $e');
      throw CloudBackupException('Failed to restore backup: $e');
    }
  }

  /// Permanently removes the snapshot [backupId].
  Future<void> deleteBackup(String uid, String backupId) async {
    debugPrint('$_logTag: deleting backup id=$backupId for ${_shortUid(uid)}…');
    try {
      await _backups(uid).doc(backupId).delete();
      debugPrint('$_logTag: deleted backup id=$backupId');
    } catch (e) {
      debugPrint('$_logTag: deleteBackup FAILED for id=$backupId: $e');
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
