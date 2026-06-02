import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:social_graph/models/contact.dart';
import 'package:social_graph/widgets/contact_card.dart';

Contact makeContact({required String id, String firstName = 'Test'}) {
  return Contact(
    id: id,
    firstName: firstName,
    lastName: '',
    tags: const [],
    locationMet: '',
    connections: const [],
  );
}

Future<void> pumpCard(
  WidgetTester tester, {
  required Contact? contact,
  VoidCallback? onNext,
  VoidCallback? onPrevious,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: Stack(
          children: [
            ContactCard(
              contact: contact,
              onClose: () {},
              onNext: onNext,
              onPrevious: onPrevious,
            ),
          ],
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  group('ContactCard swipe navigation', () {
    testWidgets('swiping left invokes onNext', (tester) async {
      var nextCalled = 0;
      var prevCalled = 0;
      await pumpCard(
        tester,
        contact: makeContact(id: 'a', firstName: 'Ada'),
        onNext: () => nextCalled++,
        onPrevious: () => prevCalled++,
      );

      await tester.fling(find.text('Ada'), const Offset(-300, 0), 1000);
      await tester.pumpAndSettle();

      expect(nextCalled, 1);
      expect(prevCalled, 0);
    });

    testWidgets('swiping right invokes onPrevious', (tester) async {
      var nextCalled = 0;
      var prevCalled = 0;
      await pumpCard(
        tester,
        contact: makeContact(id: 'b', firstName: 'Bob'),
        onNext: () => nextCalled++,
        onPrevious: () => prevCalled++,
      );

      await tester.fling(find.text('Bob'), const Offset(300, 0), 1000);
      await tester.pumpAndSettle();

      expect(prevCalled, 1);
      expect(nextCalled, 0);
    });

    testWidgets('swiping is a no-op when the callback is null', (tester) async {
      // At the end of the list onNext is null; the swipe must not throw.
      await pumpCard(
        tester,
        contact: makeContact(id: 'c', firstName: 'Cara'),
        onNext: null,
        onPrevious: null,
      );

      await tester.fling(find.text('Cara'), const Offset(-300, 0), 1000);
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
    });
  });
}
