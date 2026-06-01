import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:social_graph/models/contact.dart';
import 'package:social_graph/services/contact_repository.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Contact buildContact({String id = '1'}) {
    return Contact(
      id: id,
      firstName: 'Alice',
      lastName: 'Johnson',
      workplace: 'Stripe',
      homeAddress: '123 Market St, San Francisco, CA',
      phone: '+15551234567',
      email: 'alice@example.com',
      notes: 'Met at a conference.',
      tags: const ['Tech', 'Design'],
      locationMet: 'San Francisco',
      lat: 37.7749,
      lng: -122.4194,
      dateMet: DateTime.parse('2023-05-15T10:00:00.000Z'),
      connections: const ['2', '3'],
      lastInteraction: DateTime.parse('2024-01-10T15:00:00.000Z'),
      interactions: [
        InteractionEvent(
          id: 'i1',
          date: DateTime.parse('2024-01-10T15:00:00.000Z'),
          type: InteractionType.meeting,
          note: 'Coffee catch-up',
        ),
      ],
      reminderCadenceDays: 30,
      updatedAt: DateTime.parse('2024-02-01T09:30:00.000Z'),
    );
  }

  void expectContactEquals(Contact actual, Contact expected) {
    expect(actual.toJson(), expected.toJson());
  }

  group('ContactRepository', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
    });

    test('save then load round-trips a contact list losslessly', () async {
      final repo = ContactRepository();
      final original = [
        buildContact(id: '1'),
        buildContact(id: '2').copyWith(
          firstName: 'Bob',
          lastName: 'Lee',
          tags: const [],
          interactions: const [],
          reminderCadenceDays: null,
        ),
      ];

      await repo.save(original);
      final loaded = await repo.load();

      expect(loaded.length, original.length);
      for (var i = 0; i < original.length; i++) {
        expectContactEquals(loaded[i], original[i]);
      }
    });

    test('load on empty returns []', () async {
      final repo = ContactRepository();
      final loaded = await repo.load();
      expect(loaded, isEmpty);
    });

    test('corrupt stored value returns [] without throwing', () async {
      SharedPreferences.setMockInitialValues({
        ContactRepository.storageKey: 'this-is-not-valid-json{{{',
      });
      final repo = ContactRepository();

      final loaded = await repo.load();
      expect(loaded, isEmpty);
    });

    test('stored JSON of wrong shape (not a list) returns []', () async {
      SharedPreferences.setMockInitialValues({
        ContactRepository.storageKey: '{"unexpected": "object"}',
      });
      final repo = ContactRepository();
      final loaded = await repo.load();
      expect(loaded, isEmpty);
    });

    test('clear removes the cached list', () async {
      final repo = ContactRepository();
      await repo.save([buildContact()]);
      expect(await repo.load(), isNotEmpty);

      await repo.clear();
      expect(await repo.load(), isEmpty);
    });

    test('accepts an injected SharedPreferences instance', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final repo = ContactRepository(prefs: prefs);

      await repo.save([buildContact(id: '42')]);
      final loaded = await repo.load();

      expect(loaded.single.id, '42');
    });
  });
}
