import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:social_graph/widgets/settings_view.dart';

void main() {
  group('stripFrontMatter', () {
    test('removes leading YAML front matter', () {
      const src = '---\ntitle: X\nversion: 1.0.0\n---\n\n# Heading\n\nBody.';
      expect(stripFrontMatter(src), '# Heading\n\nBody.');
    });

    test('returns trimmed source when no front matter', () {
      const src = '\n# Heading\n\nBody.\n';
      expect(stripFrontMatter(src), '# Heading\n\nBody.');
    });

    test('handles CRLF line endings', () {
      const src = '---\r\ntitle: X\r\n---\r\n\r\nBody.';
      expect(stripFrontMatter(src), 'Body.');
    });
  });

  group('renderMarkdown', () {
    test('joins soft-wrapped paragraph lines into one paragraph', () {
      final widgets = renderMarkdown('First line\nsecond line.');
      // One paragraph (no blank line between), not two.
      final texts = widgets.whereType<Padding>().length;
      expect(texts, 1);
    });

    test('renders headings, paragraphs and bullets without throwing', () {
      final widgets = renderMarkdown(
        '# Title\n\n## Section\n\nA paragraph.\n\n- item one\n- item two',
      );
      expect(widgets, isNotEmpty);
    });

    test('treats indented lines as list-item continuations', () {
      final widgets = renderMarkdown(
        '- a bullet that wraps\n  onto a second line\n- next bullet',
      );
      // Two bullets, not three blocks.
      final bullets =
          widgets.where((w) => w is Padding && w.child is Row).length;
      expect(bullets, 2);
    });
  });

  testWidgets('LegalDocView renders bundled markdown', (tester) async {
    TestWidgetsFlutterBinding.ensureInitialized();
    await tester.pumpWidget(const MaterialApp(
      home: LegalDocView(
        title: 'Privacy Policy',
        assetPath: 'assets/legal/privacy-policy.md',
        onlineUrl: privacyPolicyUrl,
      ),
    ));
    await tester.pumpAndSettle();
    expect(find.text('Privacy Policy'), findsWidgets);
  });

  test('legal docs version constant is set', () {
    expect(legalDocsVersion, isNotEmpty);
  });

  group('Danger Zone', () {
    testWidgets('hidden when no destructive callbacks are provided',
        (tester) async {
      await tester.pumpWidget(const MaterialApp(home: SettingsView()));
      await tester.pumpAndSettle();
      expect(find.text('Danger Zone'), findsNothing);
      expect(find.text('Delete all contacts'), findsNothing);
      expect(find.text('Delete account'), findsNothing);
    });

    testWidgets('delete account hidden when only the contacts callback is set',
        (tester) async {
      await tester.pumpWidget(MaterialApp(
        home: SettingsView(onDeleteAllContacts: () {}),
      ));
      await tester.pumpAndSettle();
      expect(find.text('Delete all contacts'), findsOneWidget);
      expect(find.text('Delete account'), findsNothing);
    });

    testWidgets('confirming delete-all-contacts invokes the callback',
        (tester) async {
      var called = 0;
      await tester.pumpWidget(MaterialApp(
        home: SettingsView(onDeleteAllContacts: () => called++),
      ));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Delete all contacts'));
      await tester.pumpAndSettle();
      // Confirmation dialog is shown; callback not yet fired.
      expect(find.text('Delete all contacts?'), findsOneWidget);
      expect(called, 0);

      await tester.tap(find.text('Delete all'));
      await tester.pumpAndSettle();
      expect(called, 1);
    });

    testWidgets('cancelling delete-all-contacts does not invoke the callback',
        (tester) async {
      var called = 0;
      await tester.pumpWidget(MaterialApp(
        home: SettingsView(onDeleteAllContacts: () => called++),
      ));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Delete all contacts'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(called, 0);
    });

    testWidgets('confirming delete-account invokes the callback',
        (tester) async {
      var called = 0;
      // Open Settings through a route so its post-confirm pop has somewhere to
      // return to (mirrors how the app pushes it).
      await tester.pumpWidget(MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: ElevatedButton(
                onPressed: () => SettingsView.show(
                  context,
                  isSignedIn: true,
                  onDeleteAccount: () => called++,
                ),
                child: const Text('open'),
              ),
            ),
          ),
        ),
      ));
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Delete account'));
      await tester.pumpAndSettle();
      expect(find.text('Delete account?'), findsOneWidget);

      // Confirm button is disabled until the confirmation word is typed.
      await tester.tap(find.text('Delete account').last);
      await tester.pumpAndSettle();
      expect(called, 0);

      await tester.enterText(find.byType(TextField), 'DELETE');
      await tester.pumpAndSettle();
      // The dialog's confirm button shares the tile's label; the later one in
      // the tree is the dialog action.
      await tester.tap(find.text('Delete account').last);
      await tester.pumpAndSettle();
      expect(called, 1);
    });

    testWidgets('delete-account stays blocked with the wrong confirm word',
        (tester) async {
      var called = 0;
      await tester.pumpWidget(MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: ElevatedButton(
                onPressed: () => SettingsView.show(
                  context,
                  isSignedIn: true,
                  onDeleteAccount: () => called++,
                ),
                child: const Text('open'),
              ),
            ),
          ),
        ),
      ));
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Delete account'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), 'delete'); // wrong case
      await tester.pumpAndSettle();
      await tester.tap(find.text('Delete account').last);
      await tester.pumpAndSettle();
      expect(called, 0);
    });
  });
}
