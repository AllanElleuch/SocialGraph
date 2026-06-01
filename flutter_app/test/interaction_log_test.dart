import 'package:flutter_test/flutter_test.dart';
import 'package:social_graph/models/contact.dart';
import 'package:social_graph/services/interaction_log.dart';

Contact _baseContact({DateTime? lastInteraction}) {
  return Contact(
    id: 'c1',
    firstName: 'Ada',
    lastName: 'Lovelace',
    tags: const [],
    locationMet: 'London',
    dateMet: DateTime.utc(2020, 1, 1),
    connections: const [],
    lastInteraction: lastInteraction,
  );
}

void main() {
  group('InteractionLog', () {
    test('logging updates lastInteraction to the event date when newer', () {
      final contact = _baseContact(lastInteraction: DateTime.utc(2024, 1, 1));
      final eventDate = DateTime.utc(2024, 6, 1);

      final updated = contact.logInteractionNow(
        InteractionType.call,
        id: 'e1',
        now: eventDate,
        note: 'caught up',
      );

      expect(updated.lastInteraction, eventDate);
      expect(updated.interactions.length, 1);
      expect(updated.interactions.first.id, 'e1');
      // Original contact is unchanged (immutability).
      expect(contact.interactions, isEmpty);
      expect(contact.lastInteraction, DateTime.utc(2024, 1, 1));
    });

    test('sets lastInteraction when starting from null', () {
      final contact = _baseContact();
      final eventDate = DateTime.utc(2024, 6, 1);

      final updated = contact.logInteractionNow(
        InteractionType.text,
        id: 'e1',
        now: eventDate,
      );

      expect(updated.lastInteraction, eventDate);
    });

    test('events stored newest-first after multiple logs', () {
      var contact = _baseContact();

      // Log out of order: middle, oldest, newest.
      contact = contact.logInteractionNow(
        InteractionType.call,
        id: 'mid',
        now: DateTime.utc(2024, 3, 1),
      );
      contact = contact.logInteractionNow(
        InteractionType.email,
        id: 'old',
        now: DateTime.utc(2024, 1, 1),
      );
      contact = contact.logInteractionNow(
        InteractionType.meeting,
        id: 'new',
        now: DateTime.utc(2024, 12, 1),
      );

      final ids = contact.interactions.map((e) => e.id).toList();
      expect(ids, ['new', 'mid', 'old']);

      final dates = contact.interactions.map((e) => e.date).toList();
      for (var i = 0; i < dates.length - 1; i++) {
        expect(dates[i].isAfter(dates[i + 1]), isTrue);
      }

      // lastInteraction tracks the newest event.
      expect(contact.lastInteraction, DateTime.utc(2024, 12, 1));
    });

    test('logging an older event does not regress lastInteraction', () {
      final contact = _baseContact(lastInteraction: DateTime.utc(2024, 6, 1));
      final olderDate = DateTime.utc(2023, 1, 1);

      final updated = contact.logInteractionNow(
        InteractionType.note,
        id: 'older',
        now: olderDate,
      );

      // lastInteraction stays at the newer pre-existing value.
      expect(updated.lastInteraction, DateTime.utc(2024, 6, 1));
      // But the event is still recorded.
      expect(updated.interactions.map((e) => e.id), contains('older'));
      expect(updated.interactions.first.id, 'older');
    });

    test('logInteraction appends an explicit event immutably', () {
      final contact = _baseContact();
      final event = InteractionEvent(
        id: 'x1',
        date: DateTime.utc(2025, 1, 1),
        type: InteractionType.call,
      );

      final updated = contact.logInteraction(event);

      expect(updated.interactions.single.id, 'x1');
      expect(updated.lastInteraction, DateTime.utc(2025, 1, 1));
      expect(contact.interactions, isEmpty);
    });
  });
}
