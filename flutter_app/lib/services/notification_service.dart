import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

/// Local notification service for stay-in-touch reminders (unit U5.4).
///
/// Wraps [FlutterLocalNotificationsPlugin] and exposes a small, resilient API:
/// every method is safe to call before [init] succeeds (it becomes a no-op),
/// and all plugin interactions are guarded so the app keeps running even when
/// notifications are unavailable or permission is denied.
class NotificationService {
  NotificationService({FlutterLocalNotificationsPlugin? plugin})
      : _plugin = plugin ?? FlutterLocalNotificationsPlugin();

  static const String _channelId = 'reach_out';
  static const String _channelName = 'Reach Out Reminders';
  static const String _channelDescription =
      'Reminders about contacts you are overdue to reach out to.';
  static const int _overdueSummaryId = 1;

  final FlutterLocalNotificationsPlugin _plugin;

  bool _initialized = false;

  /// Whether [init] has completed successfully.
  bool get isInitialized => _initialized;

  /// Initializes the plugin for iOS and Android and requests iOS permissions.
  ///
  /// Returns `true` when initialization succeeds. On any failure it logs the
  /// error and returns `false` so the app can continue without notifications.
  Future<bool> init() async {
    if (_initialized) return true;
    try {
      const iosSettings = DarwinInitializationSettings(
        requestAlertPermission: true,
        requestBadgePermission: true,
        requestSoundPermission: true,
      );
      const androidSettings =
          AndroidInitializationSettings('@mipmap/ic_launcher');
      const settings = InitializationSettings(
        android: androidSettings,
        iOS: iosSettings,
      );

      final didInit = await _plugin.initialize(settings);

      await _plugin
          .resolvePlatformSpecificImplementation<
              IOSFlutterLocalNotificationsPlugin>()
          ?.requestPermissions(alert: true, badge: true, sound: true);

      _initialized = didInit ?? false;
      return _initialized;
    } catch (e) {
      debugPrint('NotificationService.init failed: $e');
      _initialized = false;
      return false;
    }
  }

  /// Shows a single summary notification for overdue contacts.
  ///
  /// No-op when [overdueCount] is `0` (or negative), or when [init] has not
  /// succeeded. All plugin calls are guarded.
  Future<void> showOverdueSummary(int overdueCount) async {
    if (!_initialized || overdueCount <= 0) return;
    try {
      const details = NotificationDetails(
        android: AndroidNotificationDetails(
          _channelId,
          _channelName,
          channelDescription: _channelDescription,
          importance: Importance.defaultImportance,
          priority: Priority.defaultPriority,
        ),
        iOS: DarwinNotificationDetails(),
      );

      final noun = overdueCount == 1 ? 'contact' : 'contacts';
      await _plugin.show(
        _overdueSummaryId,
        'Stay in touch',
        'You have $overdueCount $noun to reach out to',
        details,
      );
    } catch (e) {
      debugPrint('NotificationService.showOverdueSummary failed: $e');
    }
  }
}
