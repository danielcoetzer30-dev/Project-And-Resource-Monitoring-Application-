import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../services/sync/notification_service.dart';
import 'auth_notifier.dart';
import 'providers.dart';

/// Connects the three halves of alerting: the snapshot that arrives, the
/// service that decides whether it is worth saying anything, and the presenter
/// that says it.
///
/// Nothing called [NotificationService.evaluate] before this existed, so the
/// service had been correct and unreachable since it was written. This is the
/// wire.
///
/// Its state is the most recent alert, which the shell uses to show an in-app
/// banner. That matters because a notification posted while somebody is
/// looking at the app is easy to miss — the tray is for when they are not.
class AlertNotifier extends Notifier<HealthAlert?> {
  @override
  HealthAlert? build() {
    final service = ref.watch(notificationServiceProvider);
    final presenter = ref.watch(alertPresenterProvider);

    final subscription = service.alerts.listen((alert) {
      state = alert;

      // The tray notification is the part somebody has to opt into. The
      // in-app banner is not: it is a change on a screen they are already
      // looking at, which is what the dashboard is for.
      if (ref.read(preferencesProvider).notifyOnDecline) {
        presenter.show(alert);
      }
    });
    ref.onDispose(subscription.cancel);

    // Every snapshot is offered to the service, which stays quiet unless a
    // project has actually crossed a threshold since the last one.
    ref.listen(healthSnapshotProvider, (_, next) {
      final snapshot = next.value;
      if (snapshot != null) service.evaluate(snapshot.projects);
    }, fireImmediately: true);

    // Signing out forgets the recorded states, so one person's projects never
    // raise an alert at the next person to sign in on the same device.
    ref.listen(currentUserProvider, (_, user) {
      if (user == null) {
        service.reset();
        state = null;
      }
    });

    return null;
  }

  /// Clears the banner once it has been seen.
  void dismiss() => state = null;

  /// Turns tray notifications on or off, asking for permission the first time.
  ///
  /// Returns what the preference ended up as, which is not always what was
  /// asked for: somebody who turns it on and then refuses the Android
  /// permission gets it back off, rather than a switch that claims to be on
  /// while nothing can be shown.
  Future<bool> setEnabled(bool enabled) async {
    if (!enabled) {
      await ref.read(preferencesProvider.notifier).setNotifyOnDecline(false);
      return false;
    }

    final permitted = await ref.read(alertPresenterProvider).ensurePermitted();
    await ref.read(preferencesProvider.notifier).setNotifyOnDecline(permitted);

    return permitted;
  }
}
