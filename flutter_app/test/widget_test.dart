import 'package:flutter_test/flutter_test.dart';

import 'package:social_graph/main.dart';

void main() {
  testWidgets('App renders without crashing', (WidgetTester tester) async {
    await tester.pumpWidget(const SocialGraphApp());
    await tester.pump();

    // The header search field is present once the app has booted.
    expect(find.text('Search network...'), findsOneWidget);
  });
}
