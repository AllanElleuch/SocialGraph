import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../models/contact.dart';
import 'calendar_meeting_merge.dart';
import 'email_interaction_merge.dart';
import 'google_parsers.dart';

/// Supplies a short-lived OAuth access token for Google APIs.
///
/// Implemented by the app's sign-in layer (e.g. `google_sign_in` +
/// `authentication.accessToken`, or a server-minted token). Kept abstract so
/// the sync services below have no dependency on a particular auth plugin or on
/// native OAuth configuration — and so they're unit-testable.
abstract class GoogleTokenProvider {
  /// Returns a valid access token, or null when the user hasn't connected the
  /// relevant Google account / scope.
  Future<String?> accessToken();
}

/// Reads the user's **Google Calendar** (cloud, not the device) and folds past
/// meetings whose attendees match a contact into the list as `meeting`
/// interactions. Reuses the same pure detection/merge as the on-device calendar
/// source — only the fetch differs.
///
/// Requires the `calendar.readonly` OAuth scope (a *sensitive* scope: standard
/// Google verification, no third-party security assessment).
class GoogleCalendarSyncService {
  final GoogleTokenProvider tokens;
  final http.Client _http;

  GoogleCalendarSyncService(this.tokens, {http.Client? httpClient})
    : _http = httpClient ?? http.Client();

  Future<List<Contact>> sync(
    List<Contact> contacts, {
    Set<String> selfEmails = const {},
    DateTime? now,
    Duration lookback = const Duration(days: 90),
  }) async {
    try {
      final token = await tokens.accessToken();
      if (token == null) return contacts;

      final clock = now ?? DateTime.now();
      final uri = Uri.https(
        'www.googleapis.com',
        '/calendar/v3/calendars/primary/events',
        {
          'timeMin': clock.subtract(lookback).toUtc().toIso8601String(),
          'timeMax': clock.toUtc().toIso8601String(),
          'singleEvents': 'true',
          'orderBy': 'startTime',
          'maxResults': '250',
        },
      );
      final res = await _http.get(uri, headers: _authHeader(token));
      if (res.statusCode != 200) {
        debugPrint('GoogleCalendarSync: HTTP ${res.statusCode}');
        return contacts;
      }

      final events = parseGoogleCalendarEvents(
        jsonDecode(res.body) as Map<String, dynamic>,
      );
      final meetings = meetingsFromEvents(
        events,
        now: clock,
        selfEmails: selfEmails,
      );
      return applyDetectedInteractions(contacts, meetings);
    } catch (e) {
      debugPrint('GoogleCalendarSync failed: $e');
      return contacts;
    }
  }
}

/// Reads **Gmail** message metadata (headers only — never bodies) and folds
/// emails to/from a contact into the list as `email` interactions.
///
/// Requires a *restricted* scope (`gmail.metadata` / `gmail.readonly`): Google
/// mandates an annual third-party (CASA) security assessment to ship this
/// publicly. Gate it behind an explicit opt-in.
class GmailSyncService {
  final GoogleTokenProvider tokens;
  final http.Client _http;

  GmailSyncService(this.tokens, {http.Client? httpClient})
    : _http = httpClient ?? http.Client();

  Future<List<Contact>> sync(
    List<Contact> contacts, {
    required Set<String> selfEmails,
    int lookbackDays = 90,
    int maxMessages = 100,
  }) async {
    try {
      final token = await tokens.accessToken();
      if (token == null) return contacts;

      final listUri = Uri.https(
        'gmail.googleapis.com',
        '/gmail/v1/users/me/messages',
        {'q': 'newer_than:${lookbackDays}d', 'maxResults': '$maxMessages'},
      );
      final listRes = await _http.get(listUri, headers: _authHeader(token));
      if (listRes.statusCode != 200) {
        debugPrint('GmailSync: list HTTP ${listRes.statusCode}');
        return contacts;
      }
      final ids = [
        for (final m
            in (jsonDecode(listRes.body)['messages'] as List?) ?? const [])
          if (m is Map && m['id'] is String) m['id'] as String,
      ];

      final records = <EmailRecord>[];
      for (final id in ids) {
        final msgUri = Uri.https(
          'gmail.googleapis.com',
          '/gmail/v1/users/me/messages/$id',
          {
            'format': 'metadata',
            'metadataHeaders': ['From', 'To', 'Subject'],
          },
        );
        final res = await _http.get(msgUri, headers: _authHeader(token));
        if (res.statusCode != 200) continue;
        final rec = parseGmailMessage(
          jsonDecode(res.body) as Map<String, dynamic>,
        );
        if (rec != null) records.add(rec);
      }

      final interactions = emailInteractionsFrom(
        records,
        selfEmails: selfEmails,
      );
      return applyDetectedInteractions(contacts, interactions);
    } catch (e) {
      debugPrint('GmailSync failed: $e');
      return contacts;
    }
  }
}

Map<String, String> _authHeader(String token) => {
  'Authorization': 'Bearer $token',
};
