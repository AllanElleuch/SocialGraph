import 'dart:typed_data';

import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:social_graph/models/contact.dart';
import 'package:social_graph/services/cloud_sync_service.dart';

Contact makeContact({
  required String id,
  String firstName = 'Test',
  DateTime? updatedAt,
  Uint8List? photoThumbnail,
}) {
  return Contact(
    id: id,
    firstName: firstName,
    lastName: '',
    tags: const [],
    locationMet: '',
    connections: const [],
    updatedAt: updatedAt,
    photoThumbnail: photoThumbnail,
  );
}

void main() {
  group('reconcileByUpdatedAt', () {
    test('remote-newer wins when id exists in both', () {
      final local = [
        makeContact(
          id: 'a',
          firstName: 'OldLocal',
          updatedAt: DateTime(2026, 1, 1),
        ),
      ];
      final remote = [
        makeContact(
          id: 'a',
          firstName: 'NewRemote',
          updatedAt: DateTime(2026, 2, 1),
        ),
      ];

      final result = reconcileByUpdatedAt(local, remote);

      expect(result, hasLength(1));
      expect(result.single.firstName, 'NewRemote');
    });

    test('local-newer wins when id exists in both', () {
      final local = [
        makeContact(
          id: 'a',
          firstName: 'NewLocal',
          updatedAt: DateTime(2026, 3, 1),
        ),
      ];
      final remote = [
        makeContact(
          id: 'a',
          firstName: 'OldRemote',
          updatedAt: DateTime(2026, 1, 1),
        ),
      ];

      final result = reconcileByUpdatedAt(local, remote);

      expect(result, hasLength(1));
      expect(result.single.firstName, 'NewLocal');
    });

    test('null updatedAt loses to non-null (remote null loses)', () {
      final local = [
        makeContact(
          id: 'a',
          firstName: 'LocalWithDate',
          updatedAt: DateTime(2026, 1, 1),
        ),
      ];
      final remote = [
        makeContact(id: 'a', firstName: 'RemoteNull', updatedAt: null),
      ];

      final result = reconcileByUpdatedAt(local, remote);

      expect(result.single.firstName, 'LocalWithDate');
    });

    test('null updatedAt loses to non-null (local null loses)', () {
      final local = [
        makeContact(id: 'a', firstName: 'LocalNull', updatedAt: null),
      ];
      final remote = [
        makeContact(
          id: 'a',
          firstName: 'RemoteWithDate',
          updatedAt: DateTime(2026, 1, 1),
        ),
      ];

      final result = reconcileByUpdatedAt(local, remote);

      expect(result.single.firstName, 'RemoteWithDate');
    });

    test('id only in remote is included', () {
      final local = <Contact>[];
      final remote = [makeContact(id: 'r', firstName: 'RemoteOnly')];

      final result = reconcileByUpdatedAt(local, remote);

      expect(result, hasLength(1));
      expect(result.single.id, 'r');
    });

    test('id only in local is included', () {
      final local = [makeContact(id: 'l', firstName: 'LocalOnly')];
      final remote = <Contact>[];

      final result = reconcileByUpdatedAt(local, remote);

      expect(result, hasLength(1));
      expect(result.single.id, 'l');
    });

    test('both-null keeps local', () {
      final local = [
        makeContact(id: 'a', firstName: 'LocalNull', updatedAt: null),
      ];
      final remote = [
        makeContact(id: 'a', firstName: 'RemoteNull', updatedAt: null),
      ];

      final result = reconcileByUpdatedAt(local, remote);

      expect(result.single.firstName, 'LocalNull');
    });

    test('output is sorted by id', () {
      final local = [
        makeContact(id: 'c'),
        makeContact(id: 'a'),
      ];
      final remote = [
        makeContact(id: 'b'),
        makeContact(id: 'd'),
      ];

      final result = reconcileByUpdatedAt(local, remote);

      expect(result.map((c) => c.id).toList(), ['a', 'b', 'c', 'd']);
    });
  });

  group('push/pull chunking', () {
    test('round-trips a large list that exceeds the 1 MiB document limit',
        () async {
      final firestore = FakeFirebaseFirestore();
      final service = CloudSyncService(firestore: firestore);
      // ~50 KB photo each × 120 = several MiB, far past one document's cap.
      final photo = Uint8List.fromList(List.filled(50 * 1024, 7));
      final contacts = List.generate(
        120,
        (i) => makeContact(id: 'c$i', photoThumbnail: photo),
      );

      await service.push('user-1', contacts);
      final pulled = await service.pull('user-1');

      expect(pulled.map((c) => c.id).toSet(),
          contacts.map((c) => c.id).toSet());
      expect(pulled.every((c) => c.hasPhoto), isTrue);
    });

    test('pushing fewer contacts cleans up stale chunks', () async {
      final firestore = FakeFirebaseFirestore();
      final service = CloudSyncService(firestore: firestore);
      final photo = Uint8List.fromList(List.filled(50 * 1024, 7));
      final many = List.generate(
        120,
        (i) => makeContact(id: 'c$i', photoThumbnail: photo),
      );

      await service.push('user-1', many); // many chunks
      await service.push('user-1', [makeContact(id: 'only')]); // one chunk

      expect(await service.pull('user-1'), hasLength(1));
      final chunks = await firestore
          .collection('users')
          .doc('user-1')
          .collection('contactChunks')
          .get();
      expect(chunks.docs, hasLength(1));
    });

    test('pull reads legacy inline-contacts documents', () async {
      final firestore = FakeFirebaseFirestore();
      final service = CloudSyncService(firestore: firestore);
      // Simulate a pre-chunking write: contacts inline on the parent doc.
      await firestore.collection('users').doc('user-1').set({
        'contacts': [
          makeContact(id: 'a').toJson(),
          makeContact(id: 'b').toJson(),
        ],
      });

      final pulled = await service.pull('user-1');
      expect(pulled.map((c) => c.id), ['a', 'b']);
    });

    test('a later push migrates a legacy inline document to chunks', () async {
      final firestore = FakeFirebaseFirestore();
      final service = CloudSyncService(firestore: firestore);
      await firestore.collection('users').doc('user-1').set({
        'contacts': [makeContact(id: 'legacy').toJson()],
      });

      await service.push('user-1', [makeContact(id: 'fresh')]);

      // The oversized inline field is gone; pull comes from chunks.
      final doc = await firestore.collection('users').doc('user-1').get();
      expect(doc.data()!.containsKey('contacts'), isFalse);
      expect(await service.pull('user-1'), hasLength(1));
      expect((await service.pull('user-1')).single.id, 'fresh');
    });
  });

  group('deleteUserData', () {
    test('removes the user document so a later pull is empty', () async {
      final firestore = FakeFirebaseFirestore();
      final service = CloudSyncService(firestore: firestore);
      await service.push('user-1', [makeContact(id: 'a')]);
      expect(await service.pull('user-1'), hasLength(1));

      await service.deleteUserData('user-1');

      expect(await service.pull('user-1'), isEmpty);
      final doc =
          await firestore.collection('users').doc('user-1').get();
      expect(doc.exists, isFalse);
    });

    test('only deletes the targeted user', () async {
      final firestore = FakeFirebaseFirestore();
      final service = CloudSyncService(firestore: firestore);
      await service.push('alice', [makeContact(id: 'a')]);
      await service.push('bob', [makeContact(id: 'b')]);

      await service.deleteUserData('alice');

      expect(await service.pull('alice'), isEmpty);
      expect(await service.pull('bob'), hasLength(1));
    });
  });
}
