import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/mock_project_repository.dart';
import '../data/project_repository.dart';
import '../models/sync_state.dart';
import '../services/health_scoring/health_score_engine.dart';
import '../services/signal_engine.dart';
import '../services/sync/connectivity_service.dart';
import '../services/sync/notification_service.dart';
import '../services/sync/sync_service.dart';
import 'dashboard_notifier.dart';
import 'settings_notifier.dart';

/// Root providers: the concrete implementations behind each interface.
///
/// This is the one place a real implementation is named. Swapping the mock for
/// Firestore is a change to one line here and nothing else — every screen reads
/// through the interface and never learns which implementation it got.
///
/// Feature-level providers (dashboard state, auth state, settings) live in
/// their own `*_notifier.dart` files alongside this one, and read these.
final projectRepositoryProvider = Provider<ProjectRepository>((ref) {
  // The prototype runs on seeded data so it works with no backend, no
  // credentials and no connection. Stage 4 replaces this line with
  // FirestoreProjectRepository and nothing above it changes.
  final repository = MockProjectRepository();
  ref.onDispose(repository.dispose);
  return repository;
});

final connectivityProvider = Provider<ConnectivityService>((ref) {
  final service = ConnectivityService();
  ref.onDispose(service.dispose);
  return service;
});

/// Wraps the repository with caching and offline fallback.
final syncServiceProvider = Provider<SyncService>((ref) {
  final service = SyncService(
    repository: ref.watch(projectRepositoryProvider),
    connectivity: ref.watch(connectivityProvider),
  );
  ref.onDispose(service.dispose);
  return service;
});

/// The live snapshot every screen renders from.
///
/// Exposed as a StreamProvider so screens get loading / error / data states
/// for free and never hold a subscription themselves.
final healthSnapshotProvider = StreamProvider<HealthSnapshot>((ref) {
  return ref.watch(syncServiceProvider).watch();
});

/// How current the data on screen is, for the offline banner.
final syncStateProvider = StreamProvider<SyncState>((ref) {
  return ref.watch(syncServiceProvider).watchSyncState();
});

/// The scoring engine, with the standard five indicators.
final scoreEngineProvider = Provider<HealthScoreEngine>(
  (ref) => HealthScoreEngine.standard(),
);

final signalEngineProvider = Provider<SignalEngine>(
  (ref) => const SignalEngine(),
);

/// Raises an alert when a project crosses into a worse state.
final notificationServiceProvider = Provider<NotificationService>((ref) {
  final service = NotificationService();
  ref.onDispose(service.dispose);
  return service;
});

// --- Feature state ---------------------------------------------------------

final dashboardProvider = NotifierProvider<DashboardNotifier, DashboardView>(
  DashboardNotifier.new,
);

final settingsProvider = NotifierProvider<SettingsNotifier, WeightsDraft>(
  SettingsNotifier.new,
);
