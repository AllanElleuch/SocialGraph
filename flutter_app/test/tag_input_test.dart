import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:social_graph/widgets/tag_input.dart';

void main() {
  group('TagInput', () {
    late List<String> lastTags;

    Widget buildWidget({List<String> initialTags = const []}) {
      lastTags = [];
      return MaterialApp(
        home: Scaffold(
          body: TagInput(
            initialTags: initialTags,
            onTagsChanged: (tags) => lastTags = tags,
          ),
        ),
      );
    }

    testWidgets('displays initial tags', (WidgetTester tester) async {
      await tester.pumpWidget(buildWidget(initialTags: ['Flutter', 'Dart']));

      expect(find.text('Flutter'), findsOneWidget);
      expect(find.text('Dart'), findsOneWidget);
    });

    testWidgets('entering text and pressing Enter adds a tag',
        (WidgetTester tester) async {
      await tester.pumpWidget(buildWidget());

      await tester.enterText(find.byType(TextField), 'NewTag');
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pump();

      expect(find.text('NewTag'), findsOneWidget);
      expect(lastTags, contains('NewTag'));
    });

    testWidgets('entering text with a comma adds a tag',
        (WidgetTester tester) async {
      await tester.pumpWidget(buildWidget());

      await tester.enterText(find.byType(TextField), 'Tech,');
      await tester.pump();

      expect(find.text('Tech'), findsOneWidget);
      expect(lastTags, contains('Tech'));
    });

    testWidgets('tapping X on a tag removes it',
        (WidgetTester tester) async {
      await tester.pumpWidget(buildWidget(initialTags: ['Remove']));

      expect(find.text('Remove'), findsOneWidget);

      // Tap the close icon next to the tag
      await tester.tap(find.byIcon(Icons.close));
      await tester.pump();

      expect(find.text('Remove'), findsNothing);
    });

    testWidgets('duplicate tags are not added', (WidgetTester tester) async {
      await tester.pumpWidget(buildWidget(initialTags: ['Dup']));

      await tester.enterText(find.byType(TextField), 'Dup');
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pump();

      // Should still find exactly one instance of the tag text
      expect(find.text('Dup'), findsOneWidget);
    });
  });
}
