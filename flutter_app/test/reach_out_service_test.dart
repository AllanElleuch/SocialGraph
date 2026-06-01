import 'package:flutter_test/flutter_test.dart';
import 'package:social_graph/models/contact.dart';
import 'package:social_graph/services/reach_out_service.dart';

Contact _contact({
  String id = 'c1',
  List<String> tags = const [],
  DateTime? lastInteraction,
  DateTime? dateMet,
  int? reminderCadenceDays,
}) {
  return Contact(
    id: id,
    firstName: 'Test',
    lastName: 'Contact',
    tags: tags,
    locationMet: 'Somewhere',
    dateMet: dateMet ?? DateTime(2020, 1, 1),
    connections: const [],
    lastInteraction: lastInteraction,
    reminderCadenceDays: reminderCadenceDays,
  );
}

void main() {
  final now = DateTime(2024, 1, 1, 12);

  group('reachOutStatus', () {
    test('100 days since last interaction with cadence 90 is overdue', () {
      final c = _contact(
        lastInteraction: now.subtract(const Duration(days: 100)),
        reminderCadenceDays: 90,
      );

      final status = reachOutStatus(c, now: now);

      expect(status.isOverdue, isTrue);
      // Due date was 90 days after baseline = 10 days ago → ~-10 days.
      expect(status.dueInDays, lessThan(0));
      expect(status.dueInDays, -10);
    });

    test('null cadence on a Family-tagged contact uses 30 days', () {
      // 40 days since last interaction: with a 30-day cadence this is overdue;
      // with the 90-day default it would NOT be overdue.
      final c = _contact(
        tags: const ['Family'],
        lastInteraction: now.subtract(const Duration(days: 40)),
      );

      final status = reachOutStatus(c, now: now);

      expect(status.isOverdue, isTrue);
      expect(status.dueInDays, -10);
    });

    test('null cadence on a Friends-tagged contact uses 45 days', () {
      // 40 days in: Friends cadence 45 → not yet overdue, due in ~5 days.
      final c = _contact(
        tags: const ['Friends'],
        lastInteraction: now.subtract(const Duration(days: 40)),
      );

      final status = reachOutStatus(c, now: now);

      expect(status.isOverdue, isFalse);
      expect(status.dueInDays, 5);
    });

    test('untagged contact with null cadence uses 90-day default', () {
      final c = _contact(
        lastInteraction: now.subtract(const Duration(days: 40)),
      );

      final status = reachOutStatus(c, now: now);

      expect(status.isOverdue, isFalse);
      expect(status.dueInDays, 50);
    });

    test('cadence off (0) is never overdue', () {
      final c = _contact(
        lastInteraction: now.subtract(const Duration(days: 1000)),
        reminderCadenceDays: 0,
      );

      final status = reachOutStatus(c, now: now);

      expect(status.isOverdue, isFalse);
      expect(status.dueInDays, kReachOutOffDueInDays);
      expect(status.dueInDays, greaterThan(0));
    });

    test('cadence off (negative) is never overdue', () {
      final c = _contact(
        lastInteraction: now.subtract(const Duration(days: 1000)),
        reminderCadenceDays: -5,
      );

      final status = reachOutStatus(c, now: now);

      expect(status.isOverdue, isFalse);
      expect(status.dueInDays, kReachOutOffDueInDays);
    });

    test('recently-contacted contact is not overdue', () {
      final c = _contact(
        lastInteraction: now.subtract(const Duration(days: 2)),
        reminderCadenceDays: 90,
      );

      final status = reachOutStatus(c, now: now);

      expect(status.isOverdue, isFalse);
      expect(status.dueInDays, greaterThan(0));
    });

    test('falls back to dateMet when lastInteraction is null', () {
      final c = _contact(
        dateMet: now.subtract(const Duration(days: 100)),
        reminderCadenceDays: 90,
      );

      final status = reachOutStatus(c, now: now);

      expect(status.isOverdue, isTrue);
      expect(status.dueInDays, -10);
    });
  });

  group('overdueContacts', () {
    test('returns only overdue contacts sorted most-overdue first', () {
      final notOverdue = _contact(
        id: 'fresh',
        lastInteraction: now.subtract(const Duration(days: 2)),
        reminderCadenceDays: 90,
      );
      final off = _contact(
        id: 'off',
        lastInteraction: now.subtract(const Duration(days: 1000)),
        reminderCadenceDays: 0,
      );
      final overdueSmall = _contact(
        id: 'small', // overdue by 10 days
        lastInteraction: now.subtract(const Duration(days: 100)),
        reminderCadenceDays: 90,
      );
      final overdueLarge = _contact(
        id: 'large', // overdue by 110 days
        lastInteraction: now.subtract(const Duration(days: 200)),
        reminderCadenceDays: 90,
      );

      final result = overdueContacts(
        [notOverdue, overdueSmall, off, overdueLarge],
        now: now,
      );

      expect(result.map((c) => c.id).toList(), ['large', 'small']);
    });

    test('returns empty list when nothing is overdue', () {
      final c = _contact(
        lastInteraction: now,
        reminderCadenceDays: 90,
      );

      expect(overdueContacts([c], now: now), isEmpty);
    });
  });
}
