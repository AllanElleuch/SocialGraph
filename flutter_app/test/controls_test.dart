import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:social_graph/models/contact.dart';
import 'package:social_graph/widgets/controls.dart';

Widget _harness(double width, PivotType pivot) => MaterialApp(
  home: Scaffold(
    body: SizedBox(
      width: width,
      height: 800,
      child: Stack(
        children: [
          Controls(
            pivot: pivot,
            onPivotChanged: (_) {},
            onAddContact: () {},
            onOpenSettings: () {},
          ),
        ],
      ),
    ),
  ),
);

void main() {
  // The bar carries 5 pivots + settings + add; the active pivot shows a label.
  // It must fit (no RenderFlex overflow) on small screens for every active
  // pivot — including the longest label, "Contacts".
  // Even a tiny 280px screen must not overflow — the bar scrolls instead.
  for (final width in [375.0, 360.0, 280.0]) {
    for (final pivot in PivotType.values) {
      testWidgets('controls bar does not overflow at ${width}px ($pivot)', (
        tester,
      ) async {
        await tester.pumpWidget(_harness(width, pivot));
        expect(tester.takeException(), isNull);
      });
    }
  }

  testWidgets('bar scrolls horizontally when it cannot fit', (tester) async {
    await tester.pumpWidget(_harness(280, PivotType.contacts));
    expect(find.byType(SingleChildScrollView), findsOneWidget);
    // All five pivots are laid out (off-screen ones are reachable by scrolling).
    expect(find.byType(GestureDetector), findsWidgets);
    expect(tester.takeException(), isNull);
  });
}
