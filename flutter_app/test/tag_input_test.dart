import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:social_graph/widgets/tag_input.dart';

void main() {
  group('TagInput', () {
    late List<String> lastTags;

    Widget buildWidget({
      List<String> initialTags = const [],
      Map<String, int> tagCounts = const {},
    }) {
      lastTags = [];
      return MaterialApp(
        home: Scaffold(
          body: TagInput(
            initialTags: initialTags,
            onTagsChanged: (tags) => lastTags = tags,
            tagCounts: tagCounts,
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

    group('autocomplete', () {
      const counts = {'accro yoga': 144, 'yoga retreat': 12, 'tech': 3};

      testWidgets('suggests matching existing tags with their counts',
          (tester) async {
        await tester.pumpWidget(buildWidget(tagCounts: counts));

        await tester.enterText(find.byType(TextField), 'yoga');
        await tester.pump();

        expect(find.text('accro yoga'), findsOneWidget);
        expect(find.text('144'), findsOneWidget);
        expect(find.text('yoga retreat'), findsOneWidget);
        expect(find.text('12'), findsOneWidget);
        // Non-matching tag is not suggested.
        expect(find.text('tech'), findsNothing);
      });

      testWidgets('shows nothing when the field is empty', (tester) async {
        await tester.pumpWidget(buildWidget(tagCounts: counts));
        expect(find.text('accro yoga'), findsNothing);
      });

      testWidgets('tapping a suggestion adds it and clears the list',
          (tester) async {
        await tester.pumpWidget(buildWidget(tagCounts: counts));

        await tester.enterText(find.byType(TextField), 'accro');
        await tester.pump();
        await tester.tap(find.text('accro yoga'));
        await tester.pump();

        expect(lastTags, contains('accro yoga'));
        // The suggestion list collapsed (count badge gone), tag badge remains.
        expect(find.text('144'), findsNothing);
        expect(find.text('accro yoga'), findsOneWidget); // the added badge
      });

      testWidgets('already-added tags are not suggested again', (tester) async {
        await tester.pumpWidget(
          buildWidget(initialTags: ['accro yoga'], tagCounts: counts),
        );

        await tester.enterText(find.byType(TextField), 'yoga');
        await tester.pump();

        // 'accro yoga' appears once (the existing badge), not as a suggestion.
        expect(find.text('accro yoga'), findsOneWidget);
        expect(find.text('144'), findsNothing);
        expect(find.text('yoga retreat'), findsOneWidget);
      });
    });
  });
}
