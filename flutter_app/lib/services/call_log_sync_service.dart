import 'package:call_log/call_log.dart';
import 'package:flutter/foundation.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/contact.dart';
import 'call_log_merge.dart';

/// Reads the device call log (Android only) and folds matching calls into the
/// contact list as `call` interactions, so calls made or received outside the
/// app still appear in the timeline and stats.
///
/// iOS exposes no call-history API, so on iOS (and web/desktop) [sync] is a
/// no-op that returns the contacts unchanged. The pure matching/dedup logic
/// lives in `call_log_merge.dart`; this class only handles permissions, the
/// platform query, and remembering the last sync time.
class CallLogSyncService {
  /// SharedPreferences key holding the last successful sync time (ms epoch).
  static const _lastSyncKey = 'callLog.lastSyncMs';

  /// Re-scan a little before the last sync to catch calls whose log row landed
  /// slightly late; dedup by interaction id makes the overlap harmless.
  static const _overlap = Duration(minutes: 10);

  /// On the very first sync, look back this far rather than the whole history.
  static const _firstRunWindow = Duration(days: 90);

  /// Whether the current platform exposes a readable call log (Android only).
  /// Uses [defaultTargetPlatform] rather than `dart:io` so the file also
  /// compiles for web.
  bool get isSupported =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  /// Returns [contacts] with call-log calls merged in. Never throws; on any
  /// failure (unsupported platform, denied permission, plugin error) it logs
  /// and returns the input unchanged.
  Future<List<Contact>> sync(List<Contact> contacts) async {
    if (!isSupported) return contacts;
    try {
      if (!await _ensurePermission()) {
        debugPrint('CallLogSync: call-log permission not granted; skipping.');
        return contacts;
      }

      final prefs = await SharedPreferences.getInstance();
      final lastMs = prefs.getInt(_lastSyncKey);
      final now = DateTime.now();
      final since = lastMs != null
          ? DateTime.fromMillisecondsSinceEpoch(lastMs).subtract(_overlap)
          : now.subtract(_firstRunWindow);

      final entries = await CallLog.query(
        dateFrom: since.millisecondsSinceEpoch,
      );
      final records =
          entries.map(_toRecord).whereType<CallRecord>().toList();

      final updated = applyCallRecords(contacts, records);
      await prefs.setInt(_lastSyncKey, now.millisecondsSinceEpoch);

      final added = updated.fold<int>(0, (sum, c) => sum + c.interactions.length) -
          contacts.fold<int>(0, (sum, c) => sum + c.interactions.length);
      debugPrint('CallLogSync: scanned ${records.length} call(s), '
          'added $added new interaction(s).');
      return updated;
    } catch (e) {
      debugPrint('CallLogSync failed: $e');
      return contacts;
    }
  }

  /// Requests the call-log permission (part of the Android "phone" group).
  /// Returns true once granted.
  Future<bool> _ensurePermission() async {
    final status = await Permission.phone.status;
    if (status.isGranted) return true;
    final result = await Permission.phone.request();
    return result.isGranted;
  }

  CallRecord? _toRecord(CallLogEntry e) {
    final number = e.number;
    final ts = e.timestamp;
    if (number == null || number.isEmpty || ts == null) return null;
    final direction = switch (e.callType) {
      CallType.incoming || CallType.wifiIncoming => CallDirection.incoming,
      CallType.outgoing || CallType.wifiOutgoing => CallDirection.outgoing,
      CallType.missed || CallType.rejected => CallDirection.missed,
      _ => null,
    };
    if (direction == null) return null;
    return CallRecord(
      number: number,
      timestamp: DateTime.fromMillisecondsSinceEpoch(ts),
      direction: direction,
      durationSeconds: e.duration ?? 0,
    );
  }
}
