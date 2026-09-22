import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/mock_project_repository.dart';
import '../data/project_repository.dart';

/// Root providers: the concrete implementations behind each interface.
///
/// This is the one place a real implementation is named. Swapping the mock for
/// Firestore is a change to one line here and nothing else — every screen reads
/// through the interface and never learns which implementation it got.
///
/// Feature-level providers (dashboard state, auth state, settings) live in
/// their own `*_notifier.dart` files alongside this one, and read these.
final projectRepositoryProvider = Provider<ProjectRepository>((ref) {
  final repository = MockProjectRepository();
  ref.onDispose(repository.dispose);
  return repository;
});

/// The live snapshot every screen renders from.
///
/// Exposed as a StreamProvider so screens get loading / error / data states
/// for free and never hold a subscription themselves.
final healthSnapshotProvider = StreamProvider<HealthSnapshot>((ref) {
  return ref.watch(projectRepositoryProvider).watch();
});
