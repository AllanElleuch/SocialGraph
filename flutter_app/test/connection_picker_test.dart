import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:social_graph/models/contact.dart';
import 'package:social_graph/widgets/connection_picker.dart';

Contact _c(String id, String first, String last) => Contact(
      id: id,
      firstName: first,
      lastName: last,
      tags: const [],
      locationMet: '',
      connections: const [],
    );

Widget _host(Widget child) => MaterialApp(
      home: Scaffold(body: Padding(padding: const EdgeInsets.all(16), child: child)),
    );

void main() {
  testWidgets('does not render a chip per candidate (only selected show)',
      (tester) async {
    final candidates =
        List.generate(500, (i) => _c('id$i', 'Person', '$i'));

    await tester.pumpWidget(_host(ConnectionPicker(
      candidates: candidates,
      initialSelectedIds: const {},
      onChanged: (_) {},
    )));

    // None of the 500 names should be painted up front — only the search field
    // and the empty-state hint.
    expect(find.text('Person 0'), findsNothing);
    expect(find.text('Person 499'), findsNothing);
    expect(find.textContaining('No connections yet'), findsOneWidget);
  });

  testWidgets('typing a name surfaces a suggestion that can be selected',
      (tester) async {
    final candidates = [
      _c('1', 'Ada', 'Lovelace'),
      _c('2', 'Alan', 'Turing'),
      _c('3', 'Grace', 'Hopper'),
    ];
    Set<String>? lastChanged;

    await tester.pumpWidget(_host(ConnectionPicker(
      candidates: candidates,
      initialSelectedIds: const {},
      onChanged: (ids) => lastChanged = ids,
    )));

    await tester.enterText(find.byType(TextField), 'grace');
    await tester.pumpAndSettle();

    // Suggestion appears in the dropdown overlay.
    expect(find.text('Grace Hopper'), findsOneWidget);

    await tester.tap(find.text('Grace Hopper'));
    await tester.pumpAndSettle();

    // Selection reported and a removable chip is shown.
    expect(lastChanged, contains('3'));
    expect(find.text('Grace Hopper'), findsOneWidget); // now the chip
  });

  testWidgets('pre-selected connections render as chips and can be removed',
      (tester) async {
    final candidates = [
      _c('1', 'Ada', 'Lovelace'),
      _c('2', 'Alan', 'Turing'),
    ];
    Set<String>? lastChanged;

    await tester.pumpWidget(_host(ConnectionPicker(
      candidates: candidates,
      initialSelectedIds: const {'1'},
      onChanged: (ids) => lastChanged = ids,
    )));

    expect(find.text('Ada Lovelace'), findsOneWidget);

    await tester.tap(find.byIcon(Icons.close));
    await tester.pump();

    expect(lastChanged, isNot(contains('1')));
    expect(find.text('Ada Lovelace'), findsNothing);
  });
}
