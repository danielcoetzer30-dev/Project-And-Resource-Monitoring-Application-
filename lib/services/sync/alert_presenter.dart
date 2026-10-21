import 'notification_service.dart';

/// Puts a [HealthAlert] in front of somebody.
///
/// Separate from [NotificationService], which decides *whether* an alert is
/// worth raising and knows nothing about Android, iOS or Flutter. This decides
/// *how* one is shown. Keeping the two apart is what lets the decision logic
/// stay pure Dart and be tested without a device, and it is the same seam the
/// repositories use.
abstract interface class AlertPresenter {
  /// Asks for whatever the platform requires before a notification can be
  /// shown, returning whether it may now show one.
  ///
  /// Called when somebody turns alerts on rather than at launch. A permission
  /// prompt that appears before anybody knows what it is for gets refused, and
  /// on Android a refusal is remembered.
  Future<bool> ensurePermitted();

  /// Shows [alert]. Does nothing if permission was refused.
  Future<void> show(HealthAlert alert);
}

/// An [AlertPresenter] that records instead of showing.
///
/// Used by the tests and by any build with no notification plugin available,
/// such as the web target. Nothing is lost by it doing nothing: the in-app
/// banner is driven from the alert stream, not from here.
class RecordingAlertPresenter implements AlertPresenter {
  RecordingAlertPresenter({this.permitted = true});

  /// What [ensurePermitted] answers, so a test can exercise the refusal path.
  final bool permitted;

  final shown = <HealthAlert>[];
  var permissionAsked = false;

  @override
  Future<bool> ensurePermitted() async {
    permissionAsked = true;
    return permitted;
  }

  @override
  Future<void> show(HealthAlert alert) async {
    if (!permitted) return;
    shown.add(alert);
  }
}
