import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:social_graph/models/contact.dart';
import 'package:social_graph/models/imported_contact.dart';

void main() {
  group('ImportedContact', () {
    final sample = ImportedContact(
      sourceId: 'dev-1',
      displayName: 'Ada Lovelace',
      first: 'Ada',
      last: 'Lovelace',
      nickname: 'Countess',
      photo: ContactPhoto(
        thumbnail: Uint8List.fromList([1, 2, 3, 4]),
        fullSize: Uint8List.fromList([5, 6, 7, 8]),
      ),
      phones: const [
        LabeledValue(value: '+1 111', label: 'mobile'),
        LabeledValue(value: '+1 222', label: 'home'),
      ],
      emails: const [LabeledValue(value: 'ada@x.io', label: 'work')],
      addresses: const [
        PostalAddress(street: '1 Analytical Way', city: 'London', label: 'home'),
      ],
      organizations: const [
        ContactOrganization(company: 'Analytical Engine', title: 'Mathematician'),
      ],
      websites: const [LabeledValue(value: 'ada.io')],
      socialMedias: const [LabeledValue(value: '@ada', label: 'x')],
      events: const [ContactEvent(month: 12, day: 10, label: 'birthday')],
      relations: const [LabeledValue(value: 'Charles', label: 'friend')],
      notes: const ['met at a conference'],
    );

    test('keeps all linked data (multiple phones, photo, events)', () {
      expect(sample.phones, hasLength(2));
      expect(sample.primaryPhone, '+1 111');
      expect(sample.bestPhoto, Uint8List.fromList([5, 6, 7, 8])); // full-size preferred
      expect(sample.birthday, isNotNull);
      expect(sample.birthday!.isBirthday, isTrue);
    });

    test('maps onto the app Contact, preserving photo + birthday', () {
      final Contact c = sample.toAppContact();
      expect(c.firstName, 'Ada');
      expect(c.lastName, 'Lovelace');
      expect(c.phone, '+1 111'); // primary
      expect(c.email, 'ada@x.io');
      expect(c.workplace, 'Analytical Engine · Mathematician');
      expect(c.homeAddress, contains('London'));
      expect(c.notes, 'met at a conference');
      expect(c.tags, contains('Imported'));
      expect(c.hasPhoto, isTrue);
      expect(c.photoThumbnail, Uint8List.fromList([1, 2, 3, 4]));
      expect(c.birthday, DateTime(1900, 12, 10)); // no year -> sentinel
    });

    test('maps recognized social profiles into Contact.socials', () {
      const imported = ImportedContact(
        sourceId: 'dev-9',
        first: 'Grace',
        socialMedias: [
          LabeledValue(value: '@grace', label: 'instagram'),
          LabeledValue(value: 'grace.snap', label: 'snapchat'),
          LabeledValue(value: '@ada', label: 'x'), // unsupported -> dropped
        ],
      );

      final c = imported.toAppContact();
      expect(c.socials, {'instagram': 'grace', 'snapchat': 'grace.snap'});
    });

    test('records import provenance (source, platform, device id, date)', () {
      final when = DateTime(2026, 6, 3, 9, 30);
      final c = sample.toAppContact(platform: 'iOS', importedAt: when);
      final origin = c.origin!;
      expect(origin.isImported, isTrue);
      expect(origin.platform, 'iOS');
      expect(origin.deviceId, 'dev-1'); // stable device id for re-import
      expect(origin.importedAt, when);
    });

    test('round-trips through JSON including photo bytes', () {
      final restored = ImportedContact.fromJson(sample.toJson());
      expect(restored.displayName, 'Ada Lovelace');
      expect(restored.phones, hasLength(2));
      expect(restored.photo?.thumbnail, Uint8List.fromList([1, 2, 3, 4]));
      expect(restored.photo?.fullSize, Uint8List.fromList([5, 6, 7, 8]));
      expect(restored.events.single.day, 10);
      expect(restored.notes, ['met at a conference']);
    });

    test('handles a bare contact with no linked data', () {
      const bare = ImportedContact(sourceId: 'dev-2', first: 'X');
      final c = bare.toAppContact();
      expect(c.phone, '');
      expect(c.hasPhoto, isFalse);
      expect(c.birthday, isNull);
    });
  });

  group('Contact photo/birthday JSON', () {
    test('photoThumbnail and birthday survive a JSON round-trip', () {
      final c = Contact(
        id: '1',
        firstName: 'Grace',
        lastName: 'Hopper',
        tags: const [],
        locationMet: '',
        connections: const [],
        photoThumbnail: Uint8List.fromList([9, 8, 7]),
        birthday: DateTime(1906, 12, 9),
      );
      final restored = Contact.fromJson(c.toJson());
      expect(restored.photoThumbnail, Uint8List.fromList([9, 8, 7]));
      expect(restored.birthday, DateTime(1906, 12, 9));
      expect(restored.hasPhoto, isTrue);
    });

    test('absent photo/birthday decode to null', () {
      final restored = Contact.fromJson({
        'id': '2',
        'firstName': 'No',
        'lastName': 'Photo',
        'tags': <String>[],
        'locationMet': '',
        'connections': <String>[],
      });
      expect(restored.photoThumbnail, isNull);
      expect(restored.birthday, isNull);
      expect(restored.hasPhoto, isFalse);
    });
  });
}
