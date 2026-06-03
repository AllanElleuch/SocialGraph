import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:social_graph/stats/level.dart';
import 'package:social_graph/stats/level_requirements.dart';
import 'package:social_graph/widgets/level_roadmap.dart';

LevelStats _gated(int xp, {int contacts = 1, int interactions = 0}) =>
    LevelStats.gated(
      xp: xp,
      requirements: buildLevelRequirements(
        LevelMetrics(
          contacts: contacts,
          interactions: interactions,
          connections: 0,
          distinctPlaces: 0,
          reconnects: 0,
          strongRelationships: 0,
        ),
      ),
    );

Widget _wrap(Widget child) => MaterialApp(home: Scaffold(body: child));

void _tall(WidgetTester tester) {
  tester.view.physicalSize = const Size(1200, 4000);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

void main() {
  testWidgets('shows the ladder, the marker, and both gates per level', (
    tester,
  ) async {
    _tall(tester);
    // 3 contacts meets L2's hard requirement; XP 100 reaches level 2.
    await tester.pumpWidget(
      _wrap(LevelRoadmap(level: _gated(100, contacts: 3))),
    );

    expect(find.text('Your journey'), findsOneWidget);
    expect(find.text('Newcomer'), findsOneWidget); // first rung
    expect(find.text('Networking Legend'), findsWidgets); // apex rung
    expect(find.textContaining('You are here'), findsOneWidget);
    // Both gates are shown: XP thresholds and hard requirements.
    expect(find.textContaining('XP'), findsWidgets);
    expect(find.text('Add 3 contacts'), findsOneWidget); // L2 (met)
    expect(find.textContaining('Grow to 10 contacts'), findsWidgets); // L4 req
  });

  testWidgets('a locked level shows its unmet requirement progress', (
    tester,
  ) async {
    _tall(tester);
    // Plenty of XP but only 1 contact: L2 requirement (3 contacts) is unmet.
    await tester.pumpWidget(
      _wrap(LevelRoadmap(level: _gated(5000, contacts: 1))),
    );
    expect(find.textContaining('Add 3 contacts · 1 / 3'), findsOneWidget);
  });

  testWidgets('shows a prestige banner past the apex', (tester) async {
    _tall(tester);
    // 5500 XP -> level 11 -> Networking Legend II, prestige 1.
    await tester.pumpWidget(
      _wrap(LevelRoadmap(level: LevelStats.fromXp(5500))),
    );

    expect(find.textContaining('Apex reached'), findsOneWidget);
    expect(find.textContaining('Networking Legend II'), findsWidgets);
  });
}
