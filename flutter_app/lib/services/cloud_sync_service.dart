import 'dart:convert';

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
/// Firestore caps a single document at 1 MiB, which a large address book
/// (especially with embedded photo thumbnails) easily exceeds — Firestore
/// reports the overflow as `invalid-argument`. To stay under the cap, contacts
/// are stored across size-bounded documents in a `contactChunks` subcollection
/// under `users/{uid}` rather than inline in the parent document. The parent
/// document holds only lightweight metadata (`contactCount`, `chunkCount`,
/// `updatedAt`). No Firestore access happens at construction time.
class CloudSyncService {
  CloudSyncService({FirebaseFirestore? firestore}) : _firestore = firestore;

  final FirebaseFirestore? _firestore;

  /// Target maximum encoded size of the contacts payload per chunk document, in
  /// bytes. Kept well under Firestore's 1 MiB hard limit to leave headroom for
  /// field-name and array-index overhead the SDK adds on top of the JSON bytes.
  static const int _maxChunkBytes = 700 * 1024;

  FirebaseFirestore get _db => _firestore ?? FirebaseFirestore.instance;

  DocumentReference<Map<String, dynamic>> _userDoc(String uid) =>
      _db.collection('users').doc(uid);

  CollectionReference<Map<String, dynamic>> _chunks(String uid) =>
      _userDoc(uid).collection('contactChunks');

  /// Zero-padded chunk document id so lexical ordering matches write order.
  String _chunkId(int index) => index.toString().padLeft(6, '0');

  List<Contact> _contactsFromData(Map<String, dynamic>? data) {
    if (data == null) return [];
    final raw = data['contacts'];
    if (raw is! List) return [];
    return raw
        .whereType<Map>()
        .map((e) => Contact.fromJson(Map<String, dynamic>.from(e)))
        .toList();
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

  /// Reads the user's contacts. Returns `[]` if nothing is stored.
  Future<List<Contact>> pull(String uid) async {
    try {
      final chunksSnap =
          await _chunks(uid).orderBy(FieldPath.documentId).get();
      if (chunksSnap.docs.isNotEmpty) {
        return chunksSnap.docs
            .expand((doc) => _contactsFromData(doc.data()))
            .toList();
      }
      // Legacy fallback: contacts stored inline on the parent document by a
      // pre-chunking version. Returns [] when the document is missing.
      final snapshot = await _userDoc(uid).get();
      if (!snapshot.exists) return [];
      return _contactsFromData(snapshot.data());
    } catch (e) {
      throw CloudSyncException('Failed to pull contacts for $uid: $e');
    }
  }

  /// Writes the user's contacts as size-bounded chunk documents, replacing any
  /// previous chunks, and updates the parent document's metadata.
  Future<void> push(String uid, List<Contact> contacts) async {
    try {
      final chunks = _chunkContacts(contacts);
      final chunksRef = _chunks(uid);

      // Write the current chunks (overwriting indices 0..n-1).
      for (var i = 0; i < chunks.length; i++) {
        await chunksRef.doc(_chunkId(i)).set({'contacts': chunks[i]});
      }
      // Drop any leftover chunks from a previously larger sync.
      final existing = await chunksRef.get();
      for (final doc in existing.docs) {
        final index = int.tryParse(doc.id);
        if (index == null || index >= chunks.length) {
          await doc.reference.delete();
        }
      }
      // Update metadata and remove any legacy inline `contacts` array so the
      // parent document never carries the old oversized payload again.
      await _userDoc(uid).set(
        {
          'contactCount': contacts.length,
          'chunkCount': chunks.length,
          'contacts': FieldValue.delete(),
          'updatedAt': FieldValue.serverTimestamp(),
        },
        SetOptions(merge: true),
      );
    } catch (e) {
      throw CloudSyncException('Failed to push contacts for $uid: $e');
    }
  }

  /// Permanently deletes the user's synced contacts: the `contactChunks`
  /// subcollection (Firestore does not cascade subcollection deletes) and the
  /// parent `users/{uid}` document.
  ///
  /// Other subcollections such as `backups` are cleared separately
  /// (see [CloudBackupService]).
  Future<void> deleteUserData(String uid) async {
    try {
      final chunks = await _chunks(uid).get();
      for (final doc in chunks.docs) {
        await doc.reference.delete();
      }
      await _userDoc(uid).delete();
      debugPrint('CloudSync: deleted user document and '
          '${chunks.docs.length} chunk(s) for $uid');
    } catch (e) {
      throw CloudSyncException('Failed to delete data for $uid: $e');
    }
  }

  /// Streams the user's contacts as the chunk documents change.
  Stream<List<Contact>> watch(String uid) {
    return _chunks(uid).orderBy(FieldPath.documentId).snapshots().map(
          (snapshot) => snapshot.docs
              .expand((doc) => _contactsFromData(doc.data()))
              .toList(),
        );
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
