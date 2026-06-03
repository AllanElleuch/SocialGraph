import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:social_graph/models/contact.dart';
import 'package:social_graph/services/quest_store.dart';
import 'package:social_graph/widgets/stats_view.dart';

final _now = DateTime(2026, 6, 3, 12, 0);
final _weekStart = DateTime(2026, 6, 1);

Contact _contact(String id, List<InteractionEvent> interactions) => Contact(
      id: id,
      firstName: 'C',
      lastName: id,
      tags: const [],
      locationMet: 'Paris',
      connections: const [],
      dateMet: _weekStart, // every contact is "new this week"
      interactions: interactions,
      lastInteraction:
          interactions.isEmpty ? null : interactions.first.date,
    );

InteractionEvent _e(String id, InteractionType type, {DateTime? at}) =>
    InteractionEvent(id: id, date: at ?? _now, type: type);

/// Rich week of activity that satisfies *every* quest in the pool, so whichever
/// three are offered this week are all ready to claim.
final _contacts = [
  _contact('a', [
    _e('a1', InteractionType.call),
    _e('a2', InteractionType.text),
    // 120 days earlier -> the call this week counts as a reconnect.
    _e('a0', InteractionType.call,
        at: _weekStart.subtract(const Duration(days: 120))),
  ]),
  _contact('b', [_e('b1', InteractionType.text), _e('b2', InteractionType.email)]),
  _contact('c', [
    _e('c1', InteractionType.meeting),
    _e('c2', InteractionType.text),
  ]),
  _contact('d', [_e('d1', InteractionType.call), _e('d2', InteractionType.email)]),
];

void _useTallSurface(WidgetTester tester) {
  tester.view.physicalSize = const Size(1200, 6000);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('weekly quests render and a claim banks XP into the ledger',
      (tester) async {
    _useTallSurface(tester);
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final store = QuestStore(prefs: prefs);

    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: StatsView(
          contacts: _contacts,
          now: _now,
          onSelectContact: (_) {},
          questStore: store,
        ),
      ),
    ));
    await tester.pumpAndSettle();

    expect(find.text('Weekly quests'), findsOneWidget);
    // All offered quests are satisfied, so each shows a claim button.
    expect(find.text('Claim reward'), findsWidgets);

    // Claim the first quest.
    await tester.tap(find.text('Claim reward').first);
    await tester.pumpAndSettle();

    // The reward is now banked in the persisted ledger.
    final ledger = await store.load();
    expect(ledger, isNotEmpty);
    expect(QuestStore.totalXp(ledger), greaterThan(0));

    // And that quest now reads as claimed.
    expect(find.text('Claimed'), findsWidgets);
  });
}
