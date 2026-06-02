import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:social_graph/models/contact.dart';
import 'package:social_graph/widgets/timeline_view.dart';

/// Fixed reference dates so ordering is deterministic.
final DateTime kNow = DateTime(2026, 6, 1);

/// A minimal valid 1x1 transparent PNG, so [MemoryImage] decodes cleanly in
/// widget tests.
final Uint8List kPng = base64Decode(
  'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNk'
  '+M9QDwADhgGAWjR9awAAAABJRU5ErkJggg==',
);

Contact makeContact({
  required String id,
  required String firstName,
  required DateTime dateMet,
  DateTime? lastInteraction,
  int interactionCount = 0,
  Uint8List? photoThumbnail,
}) {
  return Contact(
    id: id,
    firstName: firstName,
    lastName: '',
    tags: const [],
    locationMet: '',
    dateMet: dateMet,
    connections: const [],
    lastInteraction: lastInteraction,
    photoThumbnail: photoThumbnail,
    interactions: List.generate(
      interactionCount,
      (i) => InteractionEvent(
        id: '$id-$i',
        date: lastInteraction ?? dateMet,
        type: InteractionType.note,
      ),
    ),
  );
}

Future<void> pumpView(
  WidgetTester tester, {
  required List<Contact> contacts,
  void Function(Contact)? onSelect,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: TimelineView(
          contacts: contacts,
          onSelectContact: onSelect ?? (_) {},
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  group('TimelineView sorting', () {
    testWidgets('default mode orders by dateMet (ascending)', (tester) async {
      // Met earlier but interacted with recently.
      final old = makeContact(
        id: 'old',
        firstName: 'Olive',
        dateMet: kNow.subtract(const Duration(days: 400)),
        lastInteraction: kNow.subtract(const Duration(days: 1)),
      );
      // Met later but no recent interaction.
      final recentMet = makeContact(
        id: 'recentMet',
        firstName: 'Ned',
        dateMet: kNow.subtract(const Duration(days: 10)),
      );

      // Provide out of order to prove the widget sorts by dateMet.
      await pumpView(tester, contacts: [recentMet, old]);

      final oliveTop = tester.getTopLeft(find.text('Olive')).dy;
      final nedTop = tester.getTopLeft(find.text('Ned')).dy;
      expect(oliveTop, lessThan(nedTop),
          reason: 'Met-first ordering: earliest dateMet (Olive) on top');
    });

    testWidgets('Recent mode orders by most-recent interaction first',
        (tester) async {
      final old = makeContact(
        id: 'old',
        firstName: 'Olive',
        dateMet: kNow.subtract(const Duration(days: 400)),
        lastInteraction: kNow.subtract(const Duration(days: 1)),
      );
      final recentMet = makeContact(
        id: 'recentMet',
        firstName: 'Ned',
        dateMet: kNow.subtract(const Duration(days: 10)),
        // No lastInteraction => falls back to dateMet (10 days ago).
      );

      await pumpView(tester, contacts: [recentMet, old]);

      // In Met mode Olive (older dateMet) is on top.
      expect(tester.getTopLeft(find.text('Olive')).dy,
          lessThan(tester.getTopLeft(find.text('Ned')).dy));

      // Switch to Recent mode.
      await tester.tap(find.text('Recent'));
      await tester.pumpAndSettle();

      final oliveTop = tester.getTopLeft(find.text('Olive')).dy;
      final nedTop = tester.getTopLeft(find.text('Ned')).dy;
      expect(oliveTop, lessThan(nedTop),
          reason:
              'Recent mode: Olive interacted 1 day ago, Ned 10 days ago => '
              'Olive on top');
    });

    testWidgets('Recent mode uses lastInteraction ?? dateMet as fallback',
        (tester) async {
      // No interactions at all => sorts by dateMet under Recent mode.
      final a = makeContact(
        id: 'a',
        firstName: 'Anna',
        dateMet: kNow.subtract(const Duration(days: 5)),
      );
      final b = makeContact(
        id: 'b',
        firstName: 'Bert',
        dateMet: kNow.subtract(const Duration(days: 50)),
      );

      await pumpView(tester, contacts: [b, a]);
      await tester.tap(find.text('Recent'));
      await tester.pumpAndSettle();

      // Anna's dateMet is more recent => on top.
      expect(tester.getTopLeft(find.text('Anna')).dy,
          lessThan(tester.getTopLeft(find.text('Bert')).dy));
    });
  });

  group('TimelineView interaction badge', () {
    testWidgets('badge reflects the interaction log length', (tester) async {
      final c = makeContact(
        id: 'c',
        firstName: 'Cara',
        dateMet: kNow.subtract(const Duration(days: 20)),
        lastInteraction: kNow.subtract(const Duration(days: 2)),
        interactionCount: 3,
      );

      await pumpView(tester, contacts: [c]);

      expect(find.text('3 interactions'), findsOneWidget);
    });

    testWidgets('singular label for a single interaction', (tester) async {
      final c = makeContact(
        id: 'c',
        firstName: 'Cara',
        dateMet: kNow.subtract(const Duration(days: 20)),
        lastInteraction: kNow.subtract(const Duration(days: 2)),
        interactionCount: 1,
      );

      await pumpView(tester, contacts: [c]);

      expect(find.text('1 interaction'), findsOneWidget);
    });

    testWidgets('no badge when there are no interactions', (tester) async {
      final c = makeContact(
        id: 'c',
        firstName: 'Cara',
        dateMet: kNow.subtract(const Duration(days: 20)),
      );

      await pumpView(tester, contacts: [c]);

      expect(find.textContaining('interaction'), findsNothing);
    });
  });

  group('TimelineView avatar', () {
    testWidgets('shows the contact photo when one is present', (tester) async {
      final c = makeContact(
        id: 'c',
        firstName: 'Cara',
        dateMet: kNow.subtract(const Duration(days: 20)),
        photoThumbnail: kPng,
      );

      await pumpView(tester, contacts: [c]);

      final avatar = tester.widget<CircleAvatar>(find.byType(CircleAvatar));
      expect(avatar.backgroundImage, isA<MemoryImage>());
      // The initial-letter fallback is not used when a photo exists.
      expect(find.text('C'), findsNothing);
    });

    testWidgets('falls back to the initial when there is no photo',
        (tester) async {
      final c = makeContact(
        id: 'c',
        firstName: 'Cara',
        dateMet: kNow.subtract(const Duration(days: 20)),
      );

      await pumpView(tester, contacts: [c]);

      expect(find.byType(CircleAvatar), findsNothing);
      expect(find.text('C'), findsOneWidget);
    });
  });

  group('TimelineView tap', () {
    testWidgets('tapping a tile invokes onSelectContact', (tester) async {
      final c = makeContact(
        id: 'c',
        firstName: 'Cara',
        dateMet: kNow.subtract(const Duration(days: 20)),
      );

      Contact? selected;
      await pumpView(tester, contacts: [c], onSelect: (x) => selected = x);

      await tester.tap(find.text('Cara'));
      await tester.pump();

      expect(selected?.id, 'c');
    });
  });
}
