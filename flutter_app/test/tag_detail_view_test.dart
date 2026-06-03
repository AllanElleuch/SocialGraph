import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:social_graph/models/contact.dart';
import 'package:social_graph/widgets/tag_detail_view.dart';

Contact c(String id, String name, List<String> tags) => Contact(
      id: id,
      firstName: name,
      lastName: '',
      tags: tags,
      locationMet: '',
      connections: const [],
    );

Future<void> pump(
  WidgetTester tester, {
  required String tag,
  required List<Contact> contacts,
  required void Function(Set<String>) onApply,
}) async {
  await tester.pumpWidget(MaterialApp(
    home: TagDetailView(tag: tag, contacts: contacts, onApply: onApply),
  ));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('preselects current members and toggles to apply a new set',
      (tester) async {
    Set<String>? applied;
    final contacts = [
      c('1', 'Ada', ['yoga']),
      c('2', 'Bob', const []),
      c('3', 'Cara', ['yoga']),
    ];

    await pump(tester, tag: 'yoga', contacts: contacts,
        onApply: (ids) => applied = ids);

    // Two members initially.
    expect(find.text('2 tagged'), findsOneWidget);

    // Add Bob, remove Cara, then Save.
    await tester.tap(find.text('Bob'));
    await tester.tap(find.text('Cara'));
    await tester.pumpAndSettle();
    expect(find.textContaining('unsaved'), findsOneWidget);

    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    expect(applied, {'1', '2'}); // Ada kept, Bob added, Cara removed
  });

  testWidgets('Done without changes does not call onApply', (tester) async {
    var calls = 0;
    await pump(
      tester,
      tag: 'yoga',
      contacts: [c('1', 'Ada', ['yoga'])],
      onApply: (_) => calls++,
    );

    expect(find.text('Done'), findsOneWidget);
    await tester.tap(find.text('Done'));
    await tester.pumpAndSettle();
    expect(calls, 0);
  });

  testWidgets('search filters the contact list', (tester) async {
    await pump(
      tester,
      tag: 'yoga',
      contacts: [
        c('1', 'Ada', const []),
        c('2', 'Bob', const []),
      ],
      onApply: (_) {},
    );

    await tester.enterText(find.byType(TextField), 'bob');
    await tester.pumpAndSettle();

    expect(find.text('Bob'), findsOneWidget);
    expect(find.text('Ada'), findsNothing);
  });
}
