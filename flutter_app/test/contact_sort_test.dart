import 'package:flutter_test/flutter_test.dart';
import 'package:social_graph/models/contact.dart';
import 'package:social_graph/services/contact_sort.dart';

Contact c({String first = '', String last = ''}) => Contact(
      id: '$first.$last',
      firstName: first,
      lastName: last,
      tags: const [],
      locationMet: '',
      connections: const [],
    );

void main() {
  group('contactSectionLetter', () {
    test('files under the last name when present, else first name', () {
      expect(contactSectionLetter(c(first: 'Jasmin', last: 'Abdel-Rehim')), 'A');
      expect(contactSectionLetter(c(first: 'Aaron')), 'A');
    });

    test('folds accents to the base letter', () {
      expect(contactSectionLetter(c(first: 'Élise')), 'E');
      expect(contactSectionLetter(c(first: 'Ömer')), 'O');
    });

    test('non-letters bucket under #', () {
      expect(contactSectionLetter(c(first: '1stBank')), '#');
      expect(contactSectionLetter(c()), '#');
    });
  });

  group('sortedForContactList', () {
    test('orders by last name then first name', () {
      final list = [
        c(first: 'Solène', last: 'Accro'),
        c(first: 'Anna', last: 'Accro'),
        c(first: 'Jasmin', last: 'Abdel-Rehim'),
        c(first: 'Aaron'),
      ];
      final sorted = sortedForContactList(list);
      expect(
        sorted.map((x) => '${x.firstName} ${x.lastName}'.trim()),
        ['Aaron', 'Jasmin Abdel-Rehim', 'Anna Accro', 'Solène Accro'],
      );
    });

    test('does not mutate the input', () {
      final list = [c(first: 'B'), c(first: 'A')];
      sortedForContactList(list);
      expect(list.map((x) => x.firstName), ['B', 'A']);
    });
  });

  group('contactInitials', () {
    test('first + last initial, uppercased', () {
      expect(contactInitials(c(first: 'Anna', last: 'Accro')), 'AA');
      expect(contactInitials(c(first: 'aaron')), 'A');
      expect(contactInitials(c()), '?');
    });
  });
}
