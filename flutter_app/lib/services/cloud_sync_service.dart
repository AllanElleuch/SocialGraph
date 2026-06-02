import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

import '../models/contact.dart';

/// Thrown when a Firestore operation fails during cloud sync.
class CloudSyncException implements Exception {
  final String message;
  const CloudSyncException(this.message);

  @override
  String toString() => 'CloudSyncException: $message';
}

/// Reconciles two contact lists by `id` using last-write-wins on `updatedAt`.
///
/// - Union by `id`.
/// - When an id exists in both lists, keep the one with the later `updatedAt`.
/// - A null `updatedAt` is treated as the oldest possible value and loses to
///   any non-null `updatedAt`.
/// - If both have a null `updatedAt`, the local copy is kept.
/// - The returned list is deterministically ordered by `id`.
List<Contact> reconcileByUpdatedAt(
  List<Contact> local,
  List<Contact> remote,
) {
  final merged = <String, Contact>{};

  for (final contact in local) {
    merged[contact.id] = contact;
  }

  for (final remoteContact in remote) {
    final localContact = merged[remoteContact.id];
    if (localContact == null) {
      merged[remoteContact.id] = remoteContact;
      continue;
    }
    merged[remoteContact.id] = _pickNewer(localContact, remoteContact);
  }

  final result = merged.values.toList()
    ..sort((a, b) => a.id.compareTo(b.id));
  return result;
}

/// Returns the contact with the later `updatedAt`. A null `updatedAt` is the
/// oldest possible value; ties (including both-null) keep [local].
Contact _pickNewer(Contact local, Contact remote) {
  final localTime = local.updatedAt;
  final remoteTime = remote.updatedAt;

  if (remoteTime == null) return local;
  if (localTime == null) return remote;
  return remoteTime.isAfter(localTime) ? remote : local;
}

/// Hosted sync of contacts via Cloud Firestore.
///
/// Each user's contacts live in a single document `users/{uid}` with a
/// `contacts` field holding a JSON array of [Contact.toJson] maps. No Firestore
/// access happens at construction time.
class CloudSyncService {
  CloudSyncService({FirebaseFirestore? firestore}) : _firestore = firestore;

  final FirebaseFirestore? _firestore;

  FirebaseFirestore get _db => _firestore ?? FirebaseFirestore.instance;

  DocumentReference<Map<String, dynamic>> _userDoc(String uid) =>
      _db.collection('users').doc(uid);

  List<Contact> _contactsFromData(Map<String, dynamic>? data) {
    if (data == null) return [];
    final raw = data['contacts'];
    if (raw is! List) return [];
    return raw
        .whereType<Map>()
        .map((e) => Contact.fromJson(Map<String, dynamic>.from(e)))
        .toList();
  }

  /// Reads the user's contacts. Returns `[]` if the document is missing.
  Future<List<Contact>> pull(String uid) async {
    try {
      final snapshot = await _userDoc(uid).get();
      if (!snapshot.exists) return [];
      return _contactsFromData(snapshot.data());
    } catch (e) {
      throw CloudSyncException('Failed to pull contacts for $uid: $e');
    }
  }

  /// Writes the user's contacts, merging with any existing fields.
  Future<void> push(String uid, List<Contact> contacts) async {
    try {
      await _userDoc(uid).set(
        {
          'contacts': contacts.map((c) => c.toJson()).toList(),
          'updatedAt': FieldValue.serverTimestamp(),
        },
        SetOptions(merge: true),
      );
    } catch (e) {
      throw CloudSyncException('Failed to push contacts for $uid: $e');
    }
  }

  /// Permanently deletes the user's synced contacts document `users/{uid}`.
  ///
  /// This removes the top-level sync document only; subcollections such as
  /// `backups` are not cascaded by Firestore and must be cleared separately
  /// (see [CloudBackupService.deleteAllBackups]).
  Future<void> deleteUserData(String uid) async {
    try {
      await _userDoc(uid).delete();
      debugPrint('CloudSync: deleted user document for $uid');
    } catch (e) {
      throw CloudSyncException('Failed to delete data for $uid: $e');
    }
  }

  /// Streams the user's contacts as the document changes.
  Stream<List<Contact>> watch(String uid) {
    return _userDoc(uid).snapshots().map((snapshot) {
      if (!snapshot.exists) return <Contact>[];
      return _contactsFromData(snapshot.data());
    });
  }

  /// Pulls remote contacts, reconciles them with [local] using
  /// [reconcileByUpdatedAt], pushes the result, and returns it.
  Future<List<Contact>> sync(String uid, List<Contact> local) async {
    final remote = await pull(uid);
    final reconciled = reconcileByUpdatedAt(local, remote);
    await push(uid, reconciled);
    debugPrint('CloudSync: synced ${reconciled.length} contacts for $uid');
    return reconciled;
  }
}
