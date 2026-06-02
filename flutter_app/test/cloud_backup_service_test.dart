import 'dart:typed_data';

import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:social_graph/models/contact.dart';
import 'package:social_graph/services/cloud_backup_service.dart';

Contact makeContact({
  required String id,
  String firstName = 'Test',
  Uint8List? photoThumbnail,
}) {
  return Contact(
    id: id,
    firstName: firstName,
    lastName: '',
    tags: const [],
    locationMet: '',
    connections: const [],
    photoThumbnail: photoThumbnail,
  );
}

void main() {
  late FakeFirebaseFirestore firestore;
  late CloudBackupService service;
  const uid = 'user-1';

  setUp(() {
    firestore = FakeFirebaseFirestore();
    service = CloudBackupService(firestore: firestore);
  });

  test('createBackup then restoreBackup round-trips contacts', () async {
    final contacts = [
      makeContact(id: 'a', firstName: 'Ada'),
      makeContact(id: 'b', firstName: 'Bob'),
    ];

    final id = await service.createBackup(uid, contacts);
    final restored = await service.restoreBackup(uid, id);

    expect(restored.map((c) => c.id), ['a', 'b']);
    expect(restored.map((c) => c.firstName), ['Ada', 'Bob']);
  });

  test('listBackups returns metadata newest first', () async {
    final first = await service.createBackup(uid, [makeContact(id: 'a')]);
    final second = await service.createBackup(
      uid,
      [makeContact(id: 'a'), makeContact(id: 'b')],
    );

    final backups = await service.listBackups(uid);

    expect(backups.length, 2);
    // Newest first.
    expect(backups.first.id, second);
    expect(backups.first.contactCount, 2);
    expect(backups.last.id, first);
    expect(backups.last.contactCount, 1);
  });

  test('listBackups returns empty when none exist', () async {
    expect(await service.listBackups(uid), isEmpty);
  });

  test('deleteBackup removes the snapshot', () async {
    final id = await service.createBackup(uid, [makeContact(id: 'a')]);
    await service.deleteBackup(uid, id);

    expect(await service.listBackups(uid), isEmpty);
  });

  test('restoreBackup throws a clear error for a missing snapshot', () async {
    expect(
      () => service.restoreBackup(uid, 'nope'),
      throwsA(isA<CloudBackupException>()),
    );
  });

  test('backups are scoped per user', () async {
    await service.createBackup('alice', [makeContact(id: 'a')]);

    expect(await service.listBackups('bob'), isEmpty);
    expect(await service.listBackups('alice'), hasLength(1));
  });

  test('createBackup stores an optional label', () async {
    final id = await service.createBackup(
      uid,
      [makeContact(id: 'a')],
      label: 'before cleanup',
    );
    final backups = await service.listBackups(uid);

    expect(backups.single.id, id);
    expect(backups.single.label, 'before cleanup');
  });

  test('large backup that exceeds the 1 MiB document limit round-trips',
      () async {
    // Each contact carries a ~50 KB photo, so the whole set is several MiB —
    // far past Firestore's 1 MiB per-document cap. The service must split it
    // across chunk documents instead of writing one oversized document.
    final photo = Uint8List.fromList(List.filled(50 * 1024, 7));
    final contacts = List.generate(
      120,
      (i) => makeContact(id: 'c$i', firstName: 'Name$i', photoThumbnail: photo),
    );

    final id = await service.createBackup(uid, contacts);

    final backups = await service.listBackups(uid);
    expect(backups.single.id, id);
    expect(backups.single.contactCount, 120);

    final restored = await service.restoreBackup(uid, id);
    expect(restored.map((c) => c.id), contacts.map((c) => c.id));
    expect(restored.first.photoThumbnail, isNotNull);
    expect(restored.first.photoThumbnail!.length, 50 * 1024);
  });

  test('deleteBackup removes a chunked backup and its chunks', () async {
    final photo = Uint8List.fromList(List.filled(50 * 1024, 7));
    final contacts = List.generate(
      120,
      (i) => makeContact(id: 'c$i', photoThumbnail: photo),
    );
    final id = await service.createBackup(uid, contacts);

    await service.deleteBackup(uid, id);

    expect(await service.listBackups(uid), isEmpty);
    // The chunk subcollection must be gone too, not just the parent doc.
    final chunks = await firestore
        .collection('users')
        .doc(uid)
        .collection('backups')
        .doc(id)
        .collection('chunks')
        .get();
    expect(chunks.docs, isEmpty);
  });

  test('createBackup reports progress monotonically to completion', () async {
    // A multi-chunk backup so progress advances through several steps.
    final photo = Uint8List.fromList(List.filled(50 * 1024, 7));
    final contacts = List.generate(
      120,
      (i) => makeContact(id: 'c$i', photoThumbnail: photo),
    );

    final events = <List<int>>[];
    await service.createBackup(
      uid,
      contacts,
      onProgress: (completed, total) => events.add([completed, total]),
    );

    expect(events, isNotEmpty);
    final total = events.last.last;
    // Total stays constant; completed climbs 1..total with no gaps and ends full.
    expect(events.every((e) => e[1] == total), isTrue);
    expect(
      events.map((e) => e.first).toList(),
      [for (var i = 1; i <= total; i++) i],
    );
  });

  test('restoreBackup reports progress to completion', () async {
    final photo = Uint8List.fromList(List.filled(50 * 1024, 7));
    final contacts = List.generate(
      120,
      (i) => makeContact(id: 'c$i', photoThumbnail: photo),
    );
    final id = await service.createBackup(uid, contacts);

    final events = <List<int>>[];
    final restored = await service.restoreBackup(
      uid,
      id,
      onProgress: (completed, total) => events.add([completed, total]),
    );

    expect(restored, hasLength(120));
    expect(events, isNotEmpty);
    final total = events.last.last;
    expect(
      events.map((e) => e.first).toList(),
      [for (var i = 1; i <= total; i++) i],
    );
  });

  test('restoreBackup still reads legacy inline-contacts backups', () async {
    // Simulate a backup written by the old (pre-chunking) format: contacts
    // embedded directly in the parent document.
    final ref = await firestore
        .collection('users')
        .doc(uid)
        .collection('backups')
        .add({
      'version': 1,
      'contactCount': 2,
      'contacts': [
        makeContact(id: 'a', firstName: 'Ada').toJson(),
        makeContact(id: 'b', firstName: 'Bob').toJson(),
      ],
    });

    final restored = await service.restoreBackup(uid, ref.id);
    expect(restored.map((c) => c.id), ['a', 'b']);
  });
}
