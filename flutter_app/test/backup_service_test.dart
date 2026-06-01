import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:social_graph/models/contact.dart';
import 'package:social_graph/services/backup_service.dart';

Contact makeContact({
  required String id,
  String firstName = '',
  String lastName = '',
  String workplace = '',
  String homeAddress = '',
  String phone = '',
  String email = '',
  String notes = '',
  List<String> tags = const [],
  String locationMet = '',
  double? lat,
  double? lng,
  DateTime? dateMet,
  List<String> connections = const [],
  DateTime? lastInteraction,
  List<InteractionEvent> interactions = const [],
  int? reminderCadenceDays,
  DateTime? updatedAt,
}) {
  return Contact(
    id: id,
    firstName: firstName,
    lastName: lastName,
    workplace: workplace,
    homeAddress: homeAddress,
    phone: phone,
    email: email,
    notes: notes,
    tags: tags,
    locationMet: locationMet,
    lat: lat,
    lng: lng,
    dateMet: dateMet ?? DateTime(2020, 1, 1),
    connections: connections,
    lastInteraction: lastInteraction,
    interactions: interactions,
    reminderCadenceDays: reminderCadenceDays,
    updatedAt: updatedAt,
  );
}

void main() {
  final service = BackupService();

  group('exportJson', () {
    test('produces wrapped document with version and exportedCount', () {
      final contacts = [
        makeContact(id: 'a', firstName: 'Ann'),
        makeContact(id: 'b', firstName: 'Bob'),
      ];

      final json = service.exportJson(contacts);
      final decoded = jsonDecode(json) as Map<String, dynamic>;

      expect(decoded['version'], 1);
      expect(decoded['exportedCount'], 2);
      expect(decoded['contacts'], hasLength(2));
    });

    test('is pretty-printed with two-space indentation', () {
      final json = service.exportJson([makeContact(id: 'a')]);
      expect(json.contains('\n  "version": 1'), isTrue);
    });
  });

  group('parseImport', () {
    test('round-trips export losslessly', () {
      final original = [
        makeContact(
          id: 'a',
          firstName: 'Ann',
          lastName: 'Apple',
          phone: '555-1234',
          email: 'ann@example.com',
          tags: const ['friend', 'work'],
          locationMet: 'Paris',
          lat: 48.85,
          lng: 2.35,
          dateMet: DateTime(2021, 5, 1),
          connections: const ['b'],
          lastInteraction: DateTime(2022, 1, 2, 3, 4, 5),
          interactions: [
            InteractionEvent(
              id: 'i1',
              date: DateTime(2022, 1, 2),
              type: InteractionType.call,
              note: 'caught up',
            ),
          ],
          reminderCadenceDays: 30,
          updatedAt: DateTime(2022, 3, 4),
        ),
      ];

      final restored = service.parseImport(service.exportJson(original));

      expect(restored, hasLength(1));
      final a = restored.first;
      final o = original.first;
      expect(a.id, o.id);
      expect(a.firstName, o.firstName);
      expect(a.lastName, o.lastName);
      expect(a.phone, o.phone);
      expect(a.email, o.email);
      expect(a.tags, o.tags);
      expect(a.locationMet, o.locationMet);
      expect(a.lat, o.lat);
      expect(a.lng, o.lng);
      expect(a.dateMet, o.dateMet);
      expect(a.connections, o.connections);
      expect(a.lastInteraction, o.lastInteraction);
      expect(a.reminderCadenceDays, o.reminderCadenceDays);
      expect(a.updatedAt, o.updatedAt);
      expect(a.interactions, hasLength(1));
      expect(a.interactions.first.id, 'i1');
      expect(a.interactions.first.type, InteractionType.call);
      expect(a.interactions.first.note, 'caught up');
    });

    test('accepts a bare JSON array of contacts', () {
      final contacts = [
        makeContact(id: 'a', firstName: 'Ann'),
        makeContact(id: 'b', firstName: 'Bob'),
      ];
      final bareArray =
          jsonEncode(contacts.map((c) => c.toJson()).toList());

      final restored = service.parseImport(bareArray);

      expect(restored.map((c) => c.id), ['a', 'b']);
    });

    test('throws FormatException on garbage input', () {
      expect(
        () => service.parseImport('this is not json {{{'),
        throwsFormatException,
      );
    });

    test('throws FormatException when object lacks a contacts array', () {
      expect(
        () => service.parseImport('{"version": 1}'),
        throwsFormatException,
      );
    });
  });

  group('importMerged', () {
    test('overlapping export merges instead of duplicating', () {
      final existing = [
        makeContact(
          id: 'a',
          firstName: 'Ann',
          lastName: 'Apple',
          email: 'ann@example.com',
        ),
        makeContact(
          id: 'b',
          firstName: 'Bob',
          lastName: 'Banana',
          email: 'bob@example.com',
        ),
      ];

      // Export "a" again (same email => duplicate of existing 'a') plus a
      // brand-new contact "c".
      final incoming = [
        makeContact(
          id: 'a2',
          firstName: 'Ann',
          lastName: 'Apple',
          email: 'ann@example.com',
          notes: 'extra note from import',
        ),
        makeContact(
          id: 'c',
          firstName: 'Carol',
          lastName: 'Cherry',
          email: 'carol@example.com',
        ),
      ];
      final json = service.exportJson(incoming);

      final result = service.importMerged(existing, json);

      // 2 existing + 2 imported = 4 raw, but 'a' and 'a2' merge => 3.
      expect(result, hasLength(3));

      // Brand-new contact 'c' is present.
      expect(result.any((c) => c.id == 'c'), isTrue);

      // The merged 'a' kept its original id and absorbed the import's note.
      final merged = result.firstWhere((c) => c.id == 'a');
      expect(merged.notes, 'extra note from import');

      // The non-primary merged-away id 'a2' is gone.
      expect(result.any((c) => c.id == 'a2'), isFalse);

      // 'b' passed through unchanged.
      expect(result.any((c) => c.id == 'b'), isTrue);
    });

    test('non-overlapping import simply appends', () {
      final existing = [
        makeContact(id: 'a', firstName: 'Ann', email: 'ann@example.com'),
      ];
      final incoming = [
        makeContact(id: 'z', firstName: 'Zed', email: 'zed@example.com'),
      ];

      final result =
          service.importMerged(existing, service.exportJson(incoming));

      expect(result.map((c) => c.id), ['a', 'z']);
    });
  });
}
