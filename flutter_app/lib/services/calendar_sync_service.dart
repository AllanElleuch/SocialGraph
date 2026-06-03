import 'package:device_calendar/device_calendar.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/contact.dart';
import 'calendar_meeting_merge.dart';

/// Reads device calendar events (iOS/Android) and folds past meetings whose
/// attendees match a contact into the contact list as `meeting` interactions.
///
/// This is the iOS analogue of [CallLogSyncService]: iOS exposes no call
/// history, but it *does* expose the calendar via EventKit, so meetings you
/// actually attended can be auto-logged. The pure matching/dedup logic lives in
/// `calendar_meeting_merge.dart`; this class only handles permissions, the
/// plugin query, and remembering the last sync time.
class CalendarSyncService {
  static const _lastSyncKey = 'calendarSync.lastSyncMs';

  /// On the very first sync, look back this far rather than the whole history.
  static const _firstRunWindow = Duration(days: 90);

  /// Re-scan a little before the last sync to catch events edited late; dedup
  /// by deterministic interaction id makes the overlap harmless.
  static const _overlap = Duration(hours: 6);

  final DeviceCalendarPlugin _plugin;

  CalendarSyncService({DeviceCalendarPlugin? plugin})
    : _plugin = plugin ?? DeviceCalendarPlugin();

  /// device_calendar supports iOS and Android only (not web/macOS).
  bool get isSupported =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.iOS ||
          defaultTargetPlatform == TargetPlatform.android);

  /// Returns [contacts] with attended calendar meetings merged in. Never throws;
  /// on any failure (unsupported platform, denied permission, plugin error) it
  /// logs and returns the input unchanged.
  ///
  /// [selfEmails] (e.g. the signed-in user's address) are excluded from
  /// attendee matching so you never log "a meeting with yourself".
  Future<List<Contact>> sync(
    List<Contact> contacts, {
    Set<String> selfEmails = const {},
    DateTime? now,
  }) async {
    if (!isSupported) return contacts;
    try {
      if (!await _ensurePermission()) {
        debugPrint('CalendarSync: permission not granted; skipping.');
        return contacts;
      }

      final clock = now ?? DateTime.now();
      final prefs = await SharedPreferences.getInstance();
      final lastMs = prefs.getInt(_lastSyncKey);
      final since = lastMs != null
          ? DateTime.fromMillisecondsSinceEpoch(lastMs).subtract(_overlap)
          : clock.subtract(_firstRunWindow);

      final records = await _retrieveEvents(since: since, until: clock);
      final meetings = meetingsFromEvents(
        records,
        now: clock,
        selfEmails: selfEmails,
      );
      final updated = applyDetectedInteractions(contacts, meetings);

      await prefs.setInt(_lastSyncKey, clock.millisecondsSinceEpoch);
      return updated;
    } catch (e) {
      debugPrint('CalendarSync failed: $e');
      return contacts;
    }
  }

  Future<bool> _ensurePermission() async {
    final has = await _plugin.hasPermissions();
    if (has.isSuccess && has.data == true) return true;
    final req = await _plugin.requestPermissions();
    return req.isSuccess && req.data == true;
  }

  /// Queries every readable calendar over [since]..[until] and maps the plugin
  /// events onto the pure [CalendarEventRecord] shape.
  Future<List<CalendarEventRecord>> _retrieveEvents({
    required DateTime since,
    required DateTime until,
  }) async {
    final calendarsResult = await _plugin.retrieveCalendars();
    final calendars = calendarsResult.data;
    if (calendars == null) return const [];

    final params = RetrieveEventsParams(startDate: since, endDate: until);
    final records = <CalendarEventRecord>[];
    for (final cal in calendars) {
      final id = cal.id;
      if (id == null) continue;
      final result = await _plugin.retrieveEvents(id, params);
      final events = result.data;
      if (events == null) continue;
      for (final e in events) {
        final record = _toRecord(e);
        if (record != null) records.add(record);
      }
    }
    return records;
  }

  CalendarEventRecord? _toRecord(Event e) {
    final id = e.eventId;
    final start = e.start;
    final end = e.end;
    if (id == null || start == null || end == null) return null;
    final emails = <String>[
      for (final a in e.attendees ?? const <Attendee?>[])
        if (a?.emailAddress != null) a!.emailAddress!,
    ];
    return CalendarEventRecord(
      eventId: id,
      title: e.title ?? '',
      // TZDateTime is a DateTime; normalise to a plain local DateTime.
      start: DateTime.fromMillisecondsSinceEpoch(start.millisecondsSinceEpoch),
      end: DateTime.fromMillisecondsSinceEpoch(end.millisecondsSinceEpoch),
      attendeeEmails: emails,
      isAllDay: e.allDay ?? false,
    );
  }
}
