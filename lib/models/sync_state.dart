import '../core/constants/app_constants.dart';

/// How current the data on screen is.
///
/// The app is built for unreliable connectivity, so "when was this true?" is
/// information the user needs, not an implementation detail.

class SyncState {
  const SyncState({
    required this.isOnline,
    required this.pendingWrites,
    required this.lastSyncedAt,
  });

  const SyncState.unknown()
    : isOnline = false,
      pendingWrites = 0,
      lastSyncedAt = null;

  final bool isOnline;
  final int pendingWrites;
  final DateTime? lastSyncedAt;

  bool get hasSynced => lastSyncedAt != null;

  bool get isStale {
    final synced = lastSyncedAt;
    if (synced == null) return true;
    return DateTime.now().difference(synced) > AppConstants.staleAfter;
  }
}
