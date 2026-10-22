import 'package:flutter/foundation.dart'
    show TargetPlatform, debugPrint, defaultTargetPlatform, kIsWeb;
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import '../../theme/tokens.dart';
import 'alert_presenter.dart';
import 'notification_service.dart';

/// Shows a health alert as a real notification in the system tray.
///
/// A local notification rather than a push one. The alert is produced on the
/// device from a snapshot the app has already read, so there is nothing for a
/// server to send — and this project is on Firebase's free plan, which has no
/// Cloud Functions to send one from. The honest consequence is that alerts are
/// raised while the app is running; it is not a background service.
///
/// The channel is created once, at a low-enough importance that it appears in
/// the tray and in a heads-up banner but does not take over the screen. An
/// early warning system that interrupts gets muted, and a muted warning system
/// is worse than none — the same reasoning that makes
/// [NotificationService] fire on a transition rather than on a state.
class LocalAlertPresenter implements AlertPresenter {
  LocalAlertPresenter({FlutterLocalNotificationsPlugin? plugin})
    : _plugin = plugin ?? FlutterLocalNotificationsPlugin();

  final FlutterLocalNotificationsPlugin _plugin;

  static const _channelId = 'project_health';
  static const _channelName = 'Project health';
  static const _channelDescription =
      'Tells you when a project moves into or out of a failing state.';

  bool _initialised = false;
  bool _permitted = false;

  /// Notification ids have to be 32-bit integers, and a project id is a
  /// string. Reusing the same id per project means a second alert about one
  /// project replaces the first rather than stacking, which is what somebody
  /// scrolling a tray actually wants.
  static int _idFor(String projectId) => projectId.hashCode & 0x7FFFFFFF;

  Future<void> _initialise() async {
    if (_initialised) return;
    _initialised = true;

    const android = AndroidInitializationSettings('@drawable/ic_notification');
    const darwin = DarwinInitializationSettings(
      // Asked for separately in ensurePermitted, for the same reason Android
      // is: not at launch, and not before anybody knows what it is for.
      requestAlertPermission: false,
      requestBadgePermission: false,
      requestSoundPermission: false,
    );

    await _plugin.initialize(
      settings: const InitializationSettings(android: android, iOS: darwin),
    );
  }

  @override
  Future<bool> ensurePermitted() async {
    // Notifications are a platform feature the web build does not have, and
    // asking there would throw rather than return false.
    if (kIsWeb) return false;

    try {
      await _initialise();

      if (defaultTargetPlatform == TargetPlatform.android) {
        final android = _plugin
            .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin
            >();

        // Android 13 and later. Older versions return null here, which is a
        // grant rather than a refusal: the permission did not exist, so it
        // did not need granting.
        _permitted = await android?.requestNotificationsPermission() ?? true;
        return _permitted;
      }

      if (defaultTargetPlatform == TargetPlatform.iOS) {
        final ios = _plugin
            .resolvePlatformSpecificImplementation<
              IOSFlutterLocalNotificationsPlugin
            >();

        _permitted =
            await ios?.requestPermissions(
              alert: true,
              badge: true,
              sound: true,
            ) ??
            false;
        return _permitted;
      }

      _permitted = false;
      return false;
    } catch (error) {
      // Being unable to notify must never break the app. A team that cannot
      // be alerted still has the dashboard, which is the actual product.
      debugPrint('Could not set notifications up: $error');
      _permitted = false;
      return false;
    }
  }

  @override
  Future<void> show(HealthAlert alert) async {
    if (!_permitted) return;

    try {
      await _initialise();

      final details = NotificationDetails(
        android: AndroidNotificationDetails(
          _channelId,
          _channelName,
          channelDescription: _channelDescription,
          importance: Importance.high,
          priority: Priority.high,
          // Recovery is good news and should not read as a warning. The
          // colour comes from Tokens rather than a hex literal here, so the
          // tray matches the app — this is the one file under services/ that
          // imports the theme, and it does so because it is a presenter.
          color: alert.isWorsening ? Tokens.ember : null,
          styleInformation: BigTextStyleInformation(_body(alert)),
          ticker: alert.title,
        ),
        iOS: const DarwinNotificationDetails(),
      );

      await _plugin.show(
        id: _idFor(alert.projectId),
        title: alert.title,
        body: _body(alert),
        notificationDetails: details,
      );
    } catch (error) {
      debugPrint('Could not show the alert: $error');
    }
  }

  /// Says what changed and what it means, because a title alone tells somebody
  /// that something happened without telling them whether to care.
  String _body(HealthAlert alert) {
    final direction = alert.isWorsening ? 'Down from' : 'Up from';
    final advice = alert.isWorsening
        ? 'Open PRAHM to see which indicator moved.'
        : 'Whatever the team changed is working.';

    return '$direction ${alert.from.label.toLowerCase()}. $advice';
  }
}
