import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:social_graph/models/contact.dart';
import 'package:social_graph/widgets/stats_view.dart';

final _now = DateTime(2026, 6, 3, 12, 0);

Contact _contact(String id, String first,
        {List<InteractionEvent> interactions = const []}) =>
    Contact(
      id: id,
      firstName: first,
      lastName: '',
      tags: const [],
      locationMet: 'Paris',
      connections: const [],
      dateMet: DateTime(2026, 5, 1),
      reminderCadenceDays: 30,
      interactions: interactions,
      lastInteraction: interactions.isEmpty ? null : interactions.first.date,
    );

Widget _wrap(Widget child) => MaterialApp(home: Scaffold(body: child));

/// Gives the test a tall viewport so the lazily-built ListView materialises
/// every card (otherwise below-the-fold sections aren't in the tree).
void _useTallSurface(WidgetTester tester) {
  tester.view.physicalSize = const Size(1200, 5000);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

void main() {
  testWidgets('empty network shows the empty state', (tester) async {
    await tester.pumpWidget(_wrap(
      StatsView(contacts: const [], now: _now, onSelectContact: (_) {}),
    ));

    expect(find.text('No stats yet'), findsOneWidget);
  });

  testWidgets('renders the dashboard sections for a populated network',
      (tester) async {
    _useTallSurface(tester);
    final contacts = [
      _contact('a', 'Ada', interactions: [
        InteractionEvent(id: '1', date: _now, type: InteractionType.call),
      ]),
      _contact('b', 'Bob'),
    ];

    await tester.pumpWidget(_wrap(
      StatsView(contacts: contacts, now: _now, onSelectContact: (_) {}),
    ));

    expect(find.text('Your network at a glance'), findsOneWidget);
    expect(find.text('Reach-out streak'), findsOneWidget);
    expect(find.text('Network health'), findsOneWidget);
    expect(find.text('Badges'), findsOneWidget);
    expect(find.text('Network growth'), findsOneWidget);
    expect(find.text('Interactions'), findsOneWidget);
  });

  testWidgets('tapping the most-contacted row selects that contact',
      (tester) async {
    _useTallSurface(tester);
    Contact? selected;
    final contacts = [
      _contact('a', 'Ada', interactions: [
        InteractionEvent(id: '1', date: _now, type: InteractionType.call),
        InteractionEvent(
            id: '2',
            date: _now.subtract(const Duration(days: 1)),
            type: InteractionType.text),
      ]),
    ];

    await tester.pumpWidget(_wrap(
      StatsView(
        contacts: contacts,
        now: _now,
        onSelectContact: (c) => selected = c,
      ),
    ));

    final row = find.textContaining('Most contacted');
    expect(row, findsOneWidget);
    await tester.tap(row);
    await tester.pump();

    expect(selected?.id, 'a');
  });
}
