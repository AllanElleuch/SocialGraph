import 'package:cloud_firestore/cloud_firestore.dart';

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

  CollectionReference<Map<String, dynamic>> _backups(String uid) =>
      _db.collection('users').doc(uid).collection('backups');

  /// Captures [contacts] as a new snapshot and returns its document id.
  Future<String> createBackup(
    String uid,
    List<Contact> contacts, {
    String? label,
  }) async {
    try {
      final doc = await _backups(uid).add({
        'version': currentVersion,
        'createdAt': FieldValue.serverTimestamp(),
        'contactCount': contacts.length,
        if (label != null && label.trim().isNotEmpty) 'label': label.trim(),
        'contacts': contacts.map((c) => c.toJson()).toList(),
      });
      return doc.id;
    } catch (e) {
      throw CloudBackupException('Failed to create backup: $e');
    }
  }

  /// Lists the user's backups, newest first. Returns `[]` when none exist.
  Future<List<CloudBackup>> listBackups(String uid) async {
    try {
      final snapshot =
          await _backups(uid).orderBy('createdAt', descending: true).get();
      return snapshot.docs.map(_backupFromDoc).toList();
    } catch (e) {
      throw CloudBackupException('Failed to list backups: $e');
    }
  }

  /// Loads the full contact list captured in the snapshot [backupId].
  Future<List<Contact>> restoreBackup(String uid, String backupId) async {
    try {
      final snapshot = await _backups(uid).doc(backupId).get();
      if (!snapshot.exists) {
        throw const CloudBackupException('That backup no longer exists.');
      }
      return _contactsFromData(snapshot.data());
    } on CloudBackupException {
      rethrow;
    } catch (e) {
      throw CloudBackupException('Failed to restore backup: $e');
    }
  }

  /// Permanently removes the snapshot [backupId].
  Future<void> deleteBackup(String uid, String backupId) async {
    try {
      await _backups(uid).doc(backupId).delete();
    } catch (e) {
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
