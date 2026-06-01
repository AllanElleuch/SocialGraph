import 'package:flutter_test/flutter_test.dart';
import 'package:social_graph/models/contact.dart';
import 'package:social_graph/services/contact_search.dart';

Contact _makeContact({
  String firstName = 'Ada',
  String lastName = 'Lovelace',
  String workplace = '',
  String phone = '',
  String email = '',
  String locationMet = 'London',
  List<String> tags = const [],
}) {
  return Contact(
    id: 'c1',
    firstName: firstName,
    lastName: lastName,
    workplace: workplace,
    phone: phone,
    email: email,
    tags: tags,
    locationMet: locationMet,
    dateMet: DateTime(2020, 1, 1),
    connections: const [],
  );
}

void main() {
  group('contactMatchesQuery', () {
    test('empty query matches all', () {
      final c = _makeContact();
      expect(contactMatchesQuery(c, ''), isTrue);
      expect(contactMatchesQuery(c, '   '), isTrue);
      expect(contactMatchesQuery(c, '\t\n'), isTrue);
    });

    test('matches workplace "Stripe" for query "stripe"', () {
      final c = _makeContact(workplace: 'Stripe');
      expect(contactMatchesQuery(c, 'stripe'), isTrue);
    });

    test('partial phone digits match across formatting', () {
      final c = _makeContact(phone: '(555) 123-4567');
      expect(contactMatchesQuery(c, '5551234'), isTrue);
      expect(contactMatchesQuery(c, '123'), isTrue);
      expect(contactMatchesQuery(c, '555-123'), isTrue);
    });

    test('matching is case-insensitive', () {
      final c = _makeContact(firstName: 'Ada', lastName: 'Lovelace');
      expect(contactMatchesQuery(c, 'ADA'), isTrue);
      expect(contactMatchesQuery(c, 'lOvElAcE'), isTrue);

      final tagged = _makeContact(tags: const ['Investor']);
      expect(contactMatchesQuery(tagged, 'investor'), isTrue);
    });

    test('matches email, location, and tags', () {
      final c = _makeContact(
        email: 'ada@example.com',
        locationMet: 'Berlin',
        tags: const ['friend', 'vc'],
      );
      expect(contactMatchesQuery(c, 'example.com'), isTrue);
      expect(contactMatchesQuery(c, 'berlin'), isTrue);
      expect(contactMatchesQuery(c, 'vc'), isTrue);
    });

    test('non-matching query returns false', () {
      final c = _makeContact(
        firstName: 'Ada',
        lastName: 'Lovelace',
        workplace: 'Stripe',
        phone: '5551234567',
        email: 'ada@example.com',
        locationMet: 'London',
        tags: const ['friend'],
      );
      expect(contactMatchesQuery(c, 'zzz-nonexistent'), isFalse);
      expect(contactMatchesQuery(c, '9999'), isFalse);
    });
  });
}
