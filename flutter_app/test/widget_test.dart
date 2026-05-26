import 'package:flutter_test/flutter_test.dart';

import 'package:social_graph/main.dart';

void main() {
  testWidgets('App renders without crashing', (WidgetTester tester) async {
    await tester.pumpWidget(const SocialGraphApp());
    await tester.pump();

    // Verify the app title is displayed
    expect(find.text('CONTEXTUAL CONTACTS'), findsOneWidget);
  });
}
