import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:social_graph/models/contact.dart';
import 'package:social_graph/services/cloud_backup_service.dart';

Contact makeContact({required String id, String firstName = 'Test'}) {
  return Contact(
    id: id,
    firstName: firstName,
    lastName: '',
    tags: const [],
    locationMet: '',
    connections: const [],
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
}
