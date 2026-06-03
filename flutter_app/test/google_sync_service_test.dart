import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/testing.dart';
import 'package:http/http.dart' as http;
import 'package:social_graph/models/contact.dart';
import 'package:social_graph/services/google_sync_service.dart';

class _FakeTokens implements GoogleTokenProvider {
  final String? token;
  _FakeTokens(this.token);
  @override
  Future<String?> accessToken() async => token;
}

Contact _c(String id, String email) => Contact(
  id: id,
  firstName: id,
  lastName: '',
  tags: const [],
  locationMet: '',
  connections: const [],
  email: email,
);

final _now = DateTime(2026, 6, 3, 12, 0);

void main() {
  test(
    'GoogleCalendarSync fetches, parses and merges a past meeting',
    () async {
      final body = jsonEncode({
        'items': [
          {
            'id': 'e1',
            'summary': 'Coffee',
            'start': {'dateTime': '2026-06-01T09:00:00Z'},
            'end': {'dateTime': '2026-06-01T10:00:00Z'},
            'attendees': [
              {'email': 'ada@x.com'},
              {'email': 'me@x.com', 'self': true},
            ],
          },
        ],
      });
      final client = MockClient((req) async {
        expect(req.headers['Authorization'], 'Bearer tok');
        return http.Response(body, 200);
      });

      final svc = GoogleCalendarSyncService(
        _FakeTokens('tok'),
        httpClient: client,
      );
      final out = await svc.sync(
        [_c('a', 'ada@x.com')],
        selfEmails: {'me@x.com'},
        now: _now,
      );

      expect(out.first.interactions, hasLength(1));
      expect(out.first.interactions.first.type, InteractionType.meeting);
    },
  );

  test('no token short-circuits and returns contacts unchanged', () async {
    final svc = GoogleCalendarSyncService(_FakeTokens(null));
    final contacts = [_c('a', 'ada@x.com')];
    final out = await svc.sync(contacts, now: _now);
    expect(identical(out, contacts), isTrue);
  });

  test(
    'GmailSync lists, fetches metadata and merges an inbound email',
    () async {
      final client = MockClient((req) async {
        if (req.url.path.endsWith('/messages')) {
          return http.Response(
            jsonEncode({
              'messages': [
                {'id': 'm1'},
              ],
            }),
            200,
          );
        }
        return http.Response(
          jsonEncode({
            'id': 'm1',
            'internalDate': '${DateTime(2026, 6, 1).millisecondsSinceEpoch}',
            'payload': {
              'headers': [
                {'name': 'From', 'value': 'Ada <ada@x.com>'},
                {'name': 'To', 'value': 'me@x.com'},
                {'name': 'Subject', 'value': 'Hi'},
              ],
            },
          }),
          200,
        );
      });

      final svc = GmailSyncService(_FakeTokens('tok'), httpClient: client);
      final out = await svc.sync(
        [_c('a', 'ada@x.com')],
        selfEmails: {'me@x.com'},
      );

      expect(out.first.interactions, hasLength(1));
      expect(out.first.interactions.first.type, InteractionType.email);
    },
  );
}
