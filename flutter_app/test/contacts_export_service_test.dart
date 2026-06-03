import 'package:flutter_test/flutter_test.dart';
import 'package:social_graph/models/contact.dart';
import 'package:social_graph/services/contacts_export_service.dart';

Contact _c({
  required String id,
  String first = '',
  String last = '',
  String phone = '',
  String email = '',
  String workplace = '',
  String homeAddress = '',
}) => Contact(
  id: id,
  firstName: first,
  lastName: last,
  tags: const [],
  connections: const [],
  locationMet: '',
  phone: phone,
  email: email,
  workplace: workplace,
  homeAddress: homeAddress,
);

void main() {
  group('appContactToDevice', () {
    test('maps name, phone, email, workplace and address', () {
      final d = appContactToDevice(
        _c(
          id: 'a',
          first: 'Ada',
          last: 'Lovelace',
          phone: '+1 415 555 0100',
          email: 'ada@x.com',
          workplace: 'Analytical Engines',
          homeAddress: '1 Mayfair',
        ),
      );

      expect(d.name!.first, 'Ada');
      expect(d.name!.last, 'Lovelace');
      expect(d.phones.single.number, '+1 415 555 0100');
      expect(d.emails.single.address, 'ada@x.com');
      expect(d.organizations.single.name, 'Analytical Engines');
      expect(d.addresses.single.street, '1 Mayfair');
    });

    test('omits empty fields (no blank phone/email entries)', () {
      final d = appContactToDevice(_c(id: 'b', first: 'Bob'));
      expect(d.phones, isEmpty);
      expect(d.emails, isEmpty);
      expect(d.organizations, isEmpty);
      expect(d.addresses, isEmpty);
      expect(d.name!.first, 'Bob');
    });
  });

  group('plannedExports', () {
    test('skips contacts already on the device (by phone/email/name)', () {
      final ours = [
        _c(id: 'a', first: 'Ada', phone: '4155550100'),
        _c(id: 'b', first: 'Bob', email: 'bob@x.com'),
        _c(id: 'c', first: 'Cara'),
      ];
      final onDevice = [
        _c(id: 'd1', first: 'Ada', phone: '+1 (415) 555-0100'), // same phone
        _c(id: 'd2', first: 'Someone', email: 'BOB@x.com'), // same email
      ];

      final planned = plannedExports(ours, onDevice);
      expect(planned.map((c) => c.firstName), ['Cara']);
    });

    test('exports everything when the device address book is empty', () {
      final ours = [_c(id: 'a', first: 'Ada'), _c(id: 'b', first: 'Bob')];
      expect(plannedExports(ours, const []).length, 2);
    });

    test('collapses same-person repeats within our own list', () {
      final ours = [
        _c(id: 'a', first: 'Ada', phone: '4155550100'),
        _c(id: 'a2', first: 'Ada', phone: '415 555 0100'), // dup of a
      ];
      expect(plannedExports(ours, const []).length, 1);
    });
  });
}
