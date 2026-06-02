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
}
