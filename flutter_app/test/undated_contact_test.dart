import 'package:flutter_test/flutter_test.dart';
import 'package:social_graph/models/contact.dart';
import 'package:social_graph/services/contact_merge.dart';
import 'package:social_graph/services/reach_out_service.dart';

Contact _c({
  required String id,
  String first = 'A',
  DateTime? dateMet,
  DateTime? lastInteraction,
  List<String> tags = const [],
}) {
  return Contact(
    id: id,
    firstName: first,
    lastName: 'X',
    tags: tags,
    locationMet: '',
    dateMet: dateMet,
    connections: const [],
    lastInteraction: lastInteraction,
  );
}

void main() {
  group('undated contacts (dateMet == null)', () {
    test('round-trips through JSON as null', () {
      final c = _c(id: '1');
      expect(c.dateMet, isNull);
      final back = Contact.fromJson(c.toJson());
      expect(back.dateMet, isNull);
    });

    test('reach-out is off when both dateMet and lastInteraction are unknown',
        () {
      final status = reachOutStatus(_c(id: '1', tags: ['Family']),
          now: DateTime(2026, 6, 1));
      expect(status.isOverdue, isFalse);
      expect(status.dueInDays, kReachOutOffDueInDays);
    });

    test('merge keeps a known date over an unknown one', () {
      final known = _c(id: '1', dateMet: DateTime(2020, 1, 1));
      final unknown = _c(id: '2');
      expect(mergeContacts(unknown, [known]).dateMet, DateTime(2020, 1, 1));
      expect(mergeContacts(known, [unknown]).dateMet, DateTime(2020, 1, 1));
    });

    test('merge of two unknown dates stays null', () {
      expect(mergeContacts(_c(id: '1'), [_c(id: '2')]).dateMet, isNull);
    });
  });
}
