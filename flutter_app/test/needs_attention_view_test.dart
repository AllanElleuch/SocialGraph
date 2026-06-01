import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:social_graph/models/contact.dart';
import 'package:social_graph/services/reach_out_service.dart';
import 'package:social_graph/services/relationship_strength.dart';
import 'package:social_graph/widgets/needs_attention_view.dart';

/// Fixed reference "now" so every computation is deterministic.
final DateTime kNow = DateTime(2026, 6, 1);

/// Builds a contact whose default cadence is 90 days (no special tags), with a
/// [lastInteraction] [daysAgo] before [kNow]. Optional [tags]/[connections]/
/// [interactionCount] let a test tune the strength score.
Contact makeContact({
  required String id,
  required String firstName,
  required int daysAgo,
  List<String> tags = const [],
  List<String> connections = const [],
  int interactionCount = 0,
}) {
  final last = kNow.subtract(Duration(days: daysAgo));
  return Contact(
    id: id,
    firstName: firstName,
    lastName: '',
    tags: tags,
    locationMet: 'Test',
    dateMet: kNow.subtract(const Duration(days: 1000)),
    connections: connections,
    lastInteraction: last,
    interactions: List.generate(
      interactionCount,
      (i) => InteractionEvent(
        id: '$id-$i',
        date: last,
        type: InteractionType.note,
      ),
    ),
  );
}

Future<void> pumpView(
  WidgetTester tester, {
  required List<Contact> contacts,
  required void Function(Contact) onSelect,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: NeedsAttentionView(
          contacts: contacts,
          now: kNow,
          onSelect: onSelect,
        ),
      ),
    ),
  );
}

void main() {
  group('NeedsAttentionView', () {
    test('test fixtures are actually overdue / current as assumed', () {
      // Default cadence (no tags) is 90 days. 120 days ago => overdue.
      final overdue = makeContact(id: 'x', firstName: 'X', daysAgo: 120);
      expect(reachOutStatus(overdue, now: kNow).isOverdue, isTrue);

      // 10 days ago => well within 90-day cadence => not overdue.
      final current = makeContact(id: 'y', firstName: 'Y', daysAgo: 10);
      expect(reachOutStatus(current, now: kNow).isOverdue, isFalse);
    });

    testWidgets('renders overdue contacts, most-urgent first', (tester) async {
      // Both overdue by the same number of days, but "Strong" has a high
      // strength (close tag + recent-ish + interactions + connections), so it
      // must outrank the "Weak" contact in the priority ordering.
      final strong = makeContact(
        id: 'strong',
        firstName: 'Strong',
        daysAgo: 120,
        tags: ['Friends'],
        connections: List.generate(15, (i) => 'c$i'),
        interactionCount: 30,
      );
      final weak = makeContact(
        id: 'weak',
        firstName: 'Weak',
        daysAgo: 120,
      );

      // Sanity: Friends cadence is 45 days, so "strong" is even more overdue.
      expect(reachOutStatus(strong, now: kNow).isOverdue, isTrue);
      expect(reachOutStatus(weak, now: kNow).isOverdue, isTrue);
      expect(strengthScore(strong, now: kNow),
          greaterThan(strengthScore(weak, now: kNow)));

      // Provide weak first to prove the widget reorders by urgency.
      await pumpView(tester, contacts: [weak, strong], onSelect: (_) {});

      expect(find.text('Strong'), findsOneWidget);
      expect(find.text('Weak'), findsOneWidget);

      final strongTop = tester.getTopLeft(find.text('Strong')).dy;
      final weakTop = tester.getTopLeft(find.text('Weak')).dy;
      expect(strongTop, lessThan(weakTop),
          reason: 'Most-urgent (Strong) should render above Weak');

      // Overdue labels are present.
      expect(find.textContaining('Overdue by'), findsNWidgets(2));
    });

    testWidgets('tapping a row invokes onSelect with that contact',
        (tester) async {
      final a = makeContact(id: 'a', firstName: 'Alice', daysAgo: 200);
      final b = makeContact(id: 'b', firstName: 'Bob', daysAgo: 130);

      Contact? selected;
      await pumpView(
        tester,
        contacts: [a, b],
        onSelect: (c) => selected = c,
      );

      await tester.tap(find.text('Bob'));
      await tester.pump();

      expect(selected, isNotNull);
      expect(selected!.id, 'b');
    });

    testWidgets('shows empty state when no contacts are overdue',
        (tester) async {
      final current1 = makeContact(id: 'c1', firstName: 'Carol', daysAgo: 5);
      final current2 = makeContact(id: 'c2', firstName: 'Dave', daysAgo: 20);

      await pumpView(
        tester,
        contacts: [current1, current2],
        onSelect: (_) {},
      );

      expect(find.text("You're all caught up"), findsOneWidget);
      expect(find.textContaining('Overdue by'), findsNothing);
      expect(find.text('Carol'), findsNothing);
    });
  });
}
