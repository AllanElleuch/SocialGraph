import 'package:flutter_test/flutter_test.dart';
import 'package:social_graph/models/contact.dart';

void main() {
  group('Contact', () {
    test('fromJson with new firstName/lastName fields', () {
      final json = {
        'id': '1',
        'firstName': 'Alice',
        'lastName': 'Johnson',
        'tags': ['Tech'],
        'locationMet': 'SF',
        'dateMet': '2023-05-15T10:00:00Z',
        'connections': ['2'],
        'workplace': 'Stripe',
        'homeAddress': '123 Main St',
      };
      final contact = Contact.fromJson(json);
      expect(contact.firstName, 'Alice');
      expect(contact.lastName, 'Johnson');
      expect(contact.displayName, 'Alice Johnson');
      expect(contact.workplace, 'Stripe');
      expect(contact.homeAddress, '123 Main St');
    });

    test('fromJson with legacy name field', () {
      final json = {
        'id': '2',
        'name': 'Bob Smith',
        'tags': <String>[],
        'locationMet': 'NYC',
        'dateMet': '2022-11-20T09:00:00Z',
        'connections': <String>[],
      };
      final contact = Contact.fromJson(json);
      expect(contact.firstName, 'Bob');
      expect(contact.lastName, 'Smith');
      expect(contact.displayName, 'Bob Smith');
    });

    test('fromJson with single-word legacy name', () {
      final json = {
        'id': '3',
        'name': 'Madonna',
        'tags': <String>[],
        'locationMet': 'LA',
        'dateMet': '2023-01-01T00:00:00Z',
        'connections': <String>[],
      };
      final contact = Contact.fromJson(json);
      expect(contact.firstName, 'Madonna');
      expect(contact.lastName, '');
      expect(contact.displayName, 'Madonna');
    });

    test('toJson includes all new fields', () {
      final contact = Contact(
        id: '1',
        firstName: 'Test',
        lastName: 'User',
        tags: ['A'],
        locationMet: 'Here',
        dateMet: DateTime(2023, 1, 1),
        connections: [],
        workplace: 'Company',
        homeAddress: '456 Oak Ave',
      );
      final json = contact.toJson();
      expect(json['firstName'], 'Test');
      expect(json['lastName'], 'User');
      expect(json['workplace'], 'Company');
      expect(json['homeAddress'], '456 Oak Ave');
    });

    test('displayName trims correctly', () {
      final contact = Contact(
        id: '1',
        firstName: 'Alice',
        lastName: '',
        tags: [],
        locationMet: '',
        dateMet: DateTime.now(),
        connections: [],
      );
      expect(contact.displayName, 'Alice');
    });
  });
}
