import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/assistant_repository.dart';
import '../data/auth_repository.dart';
import '../data/claude_assistant_repository.dart';
import '../data/comment_repository.dart';
import '../data/firebase_auth_repository.dart';
import '../data/firestore_comment_repository.dart';
import '../data/firestore_project_plan_repository.dart';
import '../data/firestore_squad_roster_repository.dart';
import '../data/firestore_project_repository.dart';
import '../data/firestore_messaging_repository.dart';
import '../data/firestore_settings_repository.dart';
import '../data/messaging_repository.dart';
import '../data/preferences_store.dart';
import '../data/project_plan_repository.dart';
import '../data/project_repository.dart';
import '../data/settings_repository.dart';
import '../data/firestore_source_repository.dart';
import '../data/source_repository.dart';
import '../data/squad_roster_repository.dart';
import '../models/comment.dart';
import '../models/preferences.dart';
import '../models/ingestion_source.dart';
import '../models/conversation.dart';
import '../models/directory_entry.dart';
import '../models/message.dart';
import '../models/project_plan.dart';
import '../models/squad_member.dart';
import '../models/sync_state.dart';
import '../services/health_scoring/health_score_engine.dart';
import '../services/signal_engine.dart';
import '../services/sync/connectivity_service.dart';
import '../services/sync/alert_presenter.dart';
import '../services/sync/local_alert_presenter.dart';
import '../services/sync/notification_service.dart';
import '../services/sync/sync_service.dart';
import 'alert_notifier.dart';
import 'assistant_notifier.dart';
import 'auth_notifier.dart';
import 'dashboard_notifier.dart';
import 'preferences_notifier.dart';
import 'settings_notifier.dart';

/// Root providers: the concrete implementations behind each interface.
///
/// This is the one place a real implementation is named. Swapping the mock for
/// Firestore is a change to one line here and nothing else, every screen reads
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
/// To go back to seeded data, for a demo with no connection, or for tests,
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

/// Discussion on signals, scoped to the signed-in user's organisation.
///
/// Separate from [projectRepositoryProvider] on purpose: that one is read-only
/// to the app, this one is written by people. Watches auth for the same reason
/// the project repository does, and writes comments as whoever is signed in.
///
/// Override with MockCommentRepository for tests or a demo with no backend.
final commentRepositoryProvider = Provider<CommentRepository>((ref) {
  final auth = ref.watch(authNotifierProvider);

  return switch (auth) {
    SignedIn(:final user) => FirestoreCommentRepository(
      orgId: user.orgId,
      author: user,
    ),
    _ => FirestoreCommentRepository(orgId: ''),
  };
});

/// One signal's thread, oldest first.
///
/// `autoDispose` is what keeps this cheap: the Firestore listener exists only
/// while the thread screen is open, and is cancelled when it closes.
final signalCommentsProvider = StreamProvider.autoDispose
    .family<List<Comment>, String>(
      (ref, signalId) => ref.watch(commentRepositoryProvider).watch(signalId),
    );

/// Per-organisation scoring weights.
///
/// Written by people, so it checks the signed-in role before it writes and
/// relies on `firestore.rules` to make that check more than a courtesy.
///
/// Not yet read by the weights screen: [settingsProvider] still holds the
/// slider draft in memory only, so changes do not survive a restart. Pointing
/// that notifier at this repository is the remaining piece.
final settingsRepositoryProvider = Provider<SettingsRepository>((ref) {
  return FirestoreSettingsRepository(
    authRepository: ref.watch(authRepositoryProvider),
  );
});

/// The scoring engine, with the standard five indicators.
final scoreEngineProvider = Provider<HealthScoreEngine>(
  (ref) => HealthScoreEngine.standard(),
);

final signalEngineProvider = Provider<SignalEngine>(
  (ref) => const SignalEngine(),
);

/// Raises an alert when a project crosses into a worse state.
///
/// Decides *whether* to say something. [alertPresenterProvider] decides how,
/// and [alertNotifierProvider] is the wire between them and the snapshot.
final notificationServiceProvider = Provider<NotificationService>((ref) {
  final service = NotificationService();
  ref.onDispose(service.dispose);
  return service;
});

/// How an alert reaches somebody: a notification in the system tray.
///
/// Override with RecordingAlertPresenter in tests and in any build with no
/// notification plugin. Nothing breaks when it does nothing, the in-app
/// banner is driven from the alert stream rather than from here.
final alertPresenterProvider = Provider<AlertPresenter>(
  (ref) => LocalAlertPresenter(),
);

/// The most recent health alert, and the thing that keeps alerting running.
///
/// Watched by the shell so it stays alive for the life of the signed-in
/// session: nothing feeds the notification service unless this exists.
final alertNotifierProvider = NotifierProvider<AlertNotifier, HealthAlert?>(
  AlertNotifier.new,
);

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

/// Where display preferences are kept on this device.
final preferencesStoreProvider = Provider<PreferencesStore>(
  (ref) => const PreferencesStore(),
);

/// Date format, time format, density and the accessibility choices, applied
/// app-wide as they change.
///
/// On this device only, and never sent anywhere: how somebody likes their
/// dates written is not something the organisation needs to know.
final preferencesProvider = NotifierProvider<PreferencesNotifier, Preferences>(
  PreferencesNotifier.new,
);

/// The repositories and trackers ingestion reads from.
///
/// Watches auth for the same reason the comment repository does: writes are
/// made as whoever is signed in, and the role decides whether they are allowed
/// at all. Signed out scopes to an empty organisation, which reads as no
/// sources rather than as an error.
final sourceRepositoryProvider = Provider<SourceRepository>((ref) {
  final user = ref.watch(currentUserProvider);

  return FirestoreSourceRepository(orgId: user?.orgId ?? '', author: user);
});

/// Every source for the organisation, never-synced first.
final sourcesProvider = StreamProvider<List<IngestionSource>>(
  (ref) => ref.watch(sourceRepositoryProvider).watch(),
);

/// Direct messages and groups, scoped to the signed-in user's organisation.
///
/// Separate from [commentRepositoryProvider]: comments are a discussion about
/// one signal, this is people talking to people. Watches auth for the same
/// reason the others do, and sends as whoever is signed in. Nothing here is
/// part of the health snapshot, so none of it reaches the assistant.
///
/// Override with MockMessagingRepository for tests or a demo with no backend.
final messagingRepositoryProvider = Provider<MessagingRepository>((ref) {
  final auth = ref.watch(authNotifierProvider);

  return switch (auth) {
    SignedIn(:final user) => FirestoreMessagingRepository(
      orgId: user.orgId,
      user: user,
    ),
    _ => FirestoreMessagingRepository(orgId: ''),
  };
});

/// Everyone who can be messaged.
///
/// `autoDispose` keeps the listener to the time a messaging screen is open.
final directoryProvider = StreamProvider.autoDispose<List<DirectoryEntry>>(
  (ref) => ref.watch(messagingRepositoryProvider).watchDirectory(),
);

/// The conversations the signed-in person is in, most recent first.
final conversationsProvider = StreamProvider.autoDispose<List<Conversation>>(
  (ref) => ref.watch(messagingRepositoryProvider).watchConversations(),
);

/// One conversation's messages, oldest first. The Firestore listener exists
/// only while that conversation is open.
final conversationMessagesProvider = StreamProvider.autoDispose
    .family<List<Message>, String>(
      (ref, conversationId) =>
          ref.watch(messagingRepositoryProvider).watchMessages(conversationId),
    );

/// The projects a team has told the app about.
///
/// Separate from [projectRepositoryProvider] on purpose: that one reads
/// ingestion's output and cannot write, this one writes what people state.
/// A plan says what a project is; `projects/` says how it is going.
final projectPlanRepositoryProvider = Provider<ProjectPlanRepository>((ref) {
  final user = ref.watch(currentUserProvider);

  return FirestoreProjectPlanRepository(orgId: user?.orgId ?? '', author: user);
});

/// Every plan, active first then archived, each alphabetical.
final projectPlansProvider = StreamProvider<List<ProjectPlan>>(
  (ref) => ref.watch(projectPlanRepositoryProvider).watch(),
);

/// One plan, watched while its editor is open.
final projectPlanProvider = StreamProvider.autoDispose
    .family<ProjectPlan?, String>(
      (ref, projectId) =>
          ref.watch(projectPlanRepositoryProvider).watchOne(projectId),
    );

/// Who is on which squad.
///
/// Separate from [projectRepositoryProvider] for the same reason the plan
/// repository is: a squad document is ingestion's output and unwritable, and a
/// placement is something a manager states. Watches auth so moves are made as
/// whoever is signed in, and the rank check decides whether they are allowed
/// at all.
final squadRosterRepositoryProvider = Provider<SquadRosterRepository>((ref) {
  final user = ref.watch(currentUserProvider);

  return FirestoreSquadRosterRepository(orgId: user?.orgId ?? '', author: user);
});

/// Every placement in the organisation.
final squadPlacementsProvider =
    StreamProvider.autoDispose<List<SquadPlacement>>(
      (ref) => ref.watch(squadRosterRepositoryProvider).watch(),
    );

/// The roster as a screen needs it: each squad's members by name, plus the
/// people on no squad.
///
/// Joined rather than stored. The names come from the directory, so a name
/// corrected there is corrected here without a second write, and the roster
/// collection stays one field wide.
final squadRosterProvider = Provider.autoDispose<SquadRoster>((ref) {
  final directory =
      ref.watch(directoryProvider).value ?? const <DirectoryEntry>[];
  final placements =
      ref.watch(squadPlacementsProvider).value ?? const <SquadPlacement>[];

  return SquadRoster.from(directory: directory, placements: placements);
});
