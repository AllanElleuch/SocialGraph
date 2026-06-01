import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:social_graph/models/contact.dart';
import 'package:social_graph/services/contact_merge.dart';
import 'package:social_graph/widgets/merge_review_sheet.dart';

Contact makeContact({
  required String id,
  String firstName = '',
  String lastName = '',
  String phone = '',
  String email = '',
  String workplace = '',
  List<String> tags = const [],
}) {
  return Contact(
    id: id,
    firstName: firstName,
    lastName: lastName,
    phone: phone,
    email: email,
    workplace: workplace,
    tags: tags,
    locationMet: 'Somewhere',
    dateMet: DateTime(2024, 1, 1),
    connections: const [],
  );
}

void main() {
  group('MergeReviewSheet', () {
    late List<List<Contact>> groups;
    late List<Contact> mergedReceived;
    late List<List<String>> mergedAwayReceived;

    setUp(() {
      // Group A: same phone -> grouped by displayName "Ada Lovelace".
      final a1 = makeContact(
        id: 'a1',
        firstName: 'Ada',
        lastName: 'Lovelace',
        phone: '555-0001',
        tags: ['math'],
      );
      final a2 = makeContact(
        id: 'a2',
        firstName: 'Ada',
        lastName: 'Lovelace',
        email: 'ada@calc.dev',
        tags: ['poetry'],
      );

      // Group B.
      final b1 = makeContact(
        id: 'b1',
        firstName: 'Alan',
        lastName: 'Turing',
        phone: '555-0002',
      );
      final b2 = makeContact(
        id: 'b2',
        firstName: 'Alan',
        lastName: 'Turing',
        workplace: 'Bletchley',
      );

      groups = [
        [a1, a2],
        [b1, b2],
      ];
      mergedReceived = [];
      mergedAwayReceived = [];
    });

    Widget build() {
      return MaterialApp(
        home: Scaffold(
          body: MergeReviewSheet(
            groups: groups,
            onMergeGroup: (merged, mergedAwayIds) {
              mergedReceived.add(merged);
              mergedAwayReceived.add(mergedAwayIds);
            },
          ),
        ),
      );
    }

    testWidgets('renders both groups', (tester) async {
      await tester.pumpWidget(build());

      expect(find.text('Ada Lovelace'), findsWidgets);
      expect(find.text('Alan Turing'), findsWidgets);
      expect(find.text('Merge'), findsNWidgets(2));
      expect(find.text('Dismiss'), findsNWidgets(2));
    });

    testWidgets(
        'tapping Merge invokes onMergeGroup with merged contact + ids and removes the row',
        (tester) async {
      await tester.pumpWidget(build());

      final expectedMerged = mergeContacts(groups[0].first, groups[0].sublist(1));

      // Tap the first group's Merge button.
      await tester.tap(find.text('Merge').first);
      await tester.pumpAndSettle();

      // Callback fired exactly once with correct payload.
      expect(mergedReceived.length, 1);
      expect(mergedAwayReceived, [
        ['a2'],
      ]);

      final merged = mergedReceived.single;
      expect(merged.id, expectedMerged.id);
      expect(merged.id, 'a1');
      expect(merged.phone, '555-0001');
      expect(merged.email, 'ada@calc.dev');
      expect(merged.tags, expectedMerged.tags);
      expect(merged.tags, containsAll(['math', 'poetry']));

      // The merged group's row is gone; the other remains.
      expect(find.text('Ada Lovelace'), findsNothing);
      expect(find.text('Alan Turing'), findsWidgets);
      expect(find.text('Merge'), findsOneWidget);
    });

    testWidgets('tapping Dismiss removes the row without calling onMergeGroup',
        (tester) async {
      await tester.pumpWidget(build());

      // Dismiss the second group (Alan Turing). Scroll its button into view
      // first, since the test viewport (600px tall) cuts off the lower card.
      final dismissButton = find.widgetWithText(OutlinedButton, 'Dismiss').last;
      await tester.ensureVisible(dismissButton);
      await tester.pumpAndSettle();
      await tester.tap(dismissButton);
      await tester.pumpAndSettle();

      expect(mergedReceived, isEmpty);
      expect(mergedAwayReceived, isEmpty);

      expect(find.text('Alan Turing'), findsNothing);
      expect(find.text('Ada Lovelace'), findsWidgets);
      expect(find.text('Dismiss'), findsOneWidget);
    });
  });
}
