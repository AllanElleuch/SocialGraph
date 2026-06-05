import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:social_graph/models/contact.dart';
import 'package:social_graph/widgets/contact_form.dart';

/// A valid 1x1 transparent PNG — real bytes so Image.memory can decode it.
final Uint8List _validPng = Uint8List.fromList(<int>[
  0x89,
  0x50,
  0x4E,
  0x47,
  0x0D,
  0x0A,
  0x1A,
  0x0A,
  0x00,
  0x00,
  0x00,
  0x0D,
  0x49,
  0x48,
  0x44,
  0x52,
  0x00,
  0x00,
  0x00,
  0x01,
  0x00,
  0x00,
  0x00,
  0x01,
  0x08,
  0x06,
  0x00,
  0x00,
  0x00,
  0x1F,
  0x15,
  0xC4,
  0x89,
  0x00,
  0x00,
  0x00,
  0x0A,
  0x49,
  0x44,
  0x41,
  0x54,
  0x78,
  0x9C,
  0x63,
  0x00,
  0x01,
  0x00,
  0x00,
  0x05,
  0x00,
  0x01,
  0x0D,
  0x0A,
  0x2D,
  0xB4,
  0x00,
  0x00,
  0x00,
  0x00,
  0x49,
  0x45,
  0x4E,
  0x44,
  0xAE,
  0x42,
  0x60,
  0x82,
]);

Contact _contact({Uint8List? photo}) => Contact(
  id: 'a',
  firstName: 'Ada',
  lastName: 'Lovelace',
  tags: const [],
  connections: const [],
  locationMet: '',
  photoThumbnail: photo,
);

Widget _harness({Contact? existing, required ValueChanged<Contact> onSave}) =>
    MaterialApp(
      home: Scaffold(
        body: SingleChildScrollView(
          child: ContactForm(
            existingContact: existing,
            allContacts: const [],
            onSave: onSave,
            onCancel: () {},
          ),
        ),
      ),
    );

void main() {
  testWidgets('shows "Add photo" for a new contact', (tester) async {
    await tester.pumpWidget(_harness(onSave: (_) {}));
    expect(find.text('Add photo'), findsOneWidget);
    expect(find.text('Change photo'), findsNothing);
  });

  testWidgets(
    'shows "Change photo" and the image when editing a contact with a photo',
    (tester) async {
      await tester.pumpWidget(
        _harness(
          existing: _contact(photo: _validPng),
          onSave: (_) {},
        ),
      );

      expect(find.text('Change photo'), findsOneWidget);
      expect(find.text('Add photo'), findsNothing);
      expect(find.byType(CircleAvatar), findsOneWidget);
    },
  );

  testWidgets(
    'saving preserves the existing photo (it is not dropped on edit)',
    (tester) async {
      Contact? saved;
      await tester.pumpWidget(
        _harness(
          existing: _contact(photo: _validPng),
          onSave: (c) => saved = c,
        ),
      );

      final saveButton = find.widgetWithText(ElevatedButton, 'Save');
      await tester.ensureVisible(saveButton);
      await tester.tap(saveButton);
      await tester.pump();

      expect(saved, isNotNull);
      expect(saved!.photoThumbnail, _validPng);
    },
  );
}
