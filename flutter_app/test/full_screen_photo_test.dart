import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:social_graph/models/contact.dart';
import 'package:social_graph/widgets/contact_card.dart';
import 'package:social_graph/widgets/full_screen_photo.dart';

/// A minimal valid 1x1 transparent PNG so MemoryImage decodes in tests.
final Uint8List kPng = base64Decode(
  'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNk'
  '+M9QDwADhgGAWjR9awAAAABJRU5ErkJggg==',
);

Contact photoContact() => Contact(
      id: 'a',
      firstName: 'Ada',
      lastName: '',
      tags: const [],
      locationMet: '',
      connections: const [],
      photoThumbnail: kPng,
    );

void main() {
  testWidgets('tapping the contact photo opens it full screen', (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: Stack(
          children: [
            ContactCard(contact: photoContact(), onClose: () {}),
          ],
        ),
      ),
    ));
    await tester.pumpAndSettle();

    expect(find.byType(FullScreenPhoto), findsNothing);

    // The header avatar is wrapped in a Hero tagged by contact id.
    await tester.tap(find.byType(Hero).first);
    await tester.pumpAndSettle();

    expect(find.byType(FullScreenPhoto), findsOneWidget);

    // Closing dismisses it.
    await tester.tap(find.byTooltip('Close'));
    await tester.pumpAndSettle();
    expect(find.byType(FullScreenPhoto), findsNothing);
  });

  testWidgets('FullScreenPhoto shows the image and a close button',
      (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: Builder(
        builder: (context) => Scaffold(
          body: Center(
            child: ElevatedButton(
              onPressed: () => FullScreenPhoto.show(context, kPng),
              child: const Text('open'),
            ),
          ),
        ),
      ),
    ));

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    expect(find.byType(Image), findsOneWidget);
    expect(find.byType(InteractiveViewer), findsOneWidget);
    expect(find.byTooltip('Close'), findsOneWidget);
  });
}
