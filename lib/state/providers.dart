import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/assistant_repository.dart';
import '../data/auth_repository.dart';
import '../data/claude_assistant_repository.dart';
import '../data/firebase_auth_repository.dart';
import '../data/firestore_project_repository.dart';
import '../data/project_repository.dart';
import '../models/sync_state.dart';
import '../services/health_scoring/health_score_engine.dart';
import '../services/signal_engine.dart';
import '../services/sync/connectivity_service.dart';
import '../services/sync/notification_service.dart';
import '../services/sync/sync_service.dart';
import 'assistant_notifier.dart';
import 'auth_notifier.dart';
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
/// Firebase Auth, behind the AuthRepository interface.
final authRepositoryProvider = Provider<AuthRepository>(
  (ref) => FirebaseAuthRepository(),
);

final authNotifierProvider = NotifierProvider<AuthNotifier, AuthState>(
  AuthNotifier.new,
);

/// Live project data, scoped to the signed-in user's organisation.
///
/// Watches auth, so signing out tears the repository down and signing in as
/// someone from a different organisation builds a new one pointed at their
/// data. Nothing above this ever learns which implementation it got.
///
/// To go back to seeded data — for a demo with no connection, or for tests —
/// override this provider with MockProjectRepository. That is the only change
/// needed; every screen reads through the interface.
final projectRepositoryProvider = Provider<ProjectRepository>((ref) {
  final auth = ref.watch(authNotifierProvider);
  final orgId = auth is SignedIn ? auth.user.orgId : '';

  final repository = FirestoreProjectRepository(orgId: orgId);
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

/// The assistant, behind its interface.
///
/// Calls Claude directly with the user's own key today. When a backend exists,
/// this line points at an implementation that posts to it instead, and nothing
/// above the interface changes.
final assistantRepositoryProvider = Provider<AssistantRepository>((ref) {
  final repository = ClaudeAssistantRepository();
  ref.onDispose(repository.dispose);
  return repository;
});

// --- Feature state ---------------------------------------------------------

final assistantProvider = NotifierProvider<AssistantNotifier, AssistantState>(
  AssistantNotifier.new,
);

final dashboardProvider = NotifierProvider<DashboardNotifier, DashboardView>(
  DashboardNotifier.new,
);

final settingsProvider = NotifierProvider<SettingsNotifier, WeightsDraft>(
  SettingsNotifier.new,
);
