import 'dart:async';

import '../../data/local_cache.dart';
import '../../data/project_repository.dart';
import '../../models/sync_state.dart';
import 'connectivity_service.dart';

/// Keeps a readable snapshot available whether or not the network is.
///
/// Wraps a repository: live data passes through and is cached on the way, and
/// when the live stream fails or the device goes offline the cached snapshot
/// is served instead, flagged as not live.
///
/// This is why the app is usable during load-shedding, which is the thing the
/// research says existing tools get wrong.
class SyncService {
  SyncService({
    required this.repository,
    required this.connectivity,
    this.cache = const LocalCache(),
  });

  final ProjectRepository repository;
  final ConnectivityService connectivity;
  final LocalCache cache;

  final _snapshots = StreamController<HealthSnapshot>.broadcast();
  final _syncStates = StreamController<SyncState>.broadcast();

  StreamSubscription<HealthSnapshot>? _repositorySub;
  StreamSubscription<bool>? _connectivitySub;

  DateTime? _lastSyncedAt;
  bool _started = false;

  Stream<HealthSnapshot> watch() {
    if (!_started) {
      _started = true;
      _start();
    }
    return _snapshots.stream;
  }

  Stream<SyncState> watchSyncState() => _syncStates.stream;

  void _start() {
    // Serve whatever is cached immediately, so the first frame has real
    // content rather than a spinner. Live data replaces it when it arrives.
    unawaited(_emitCached());

    _repositorySub = repository.watch().listen(
      (snapshot) {
        _lastSyncedAt = snapshot.capturedAt;
        if (!_snapshots.isClosed) _snapshots.add(snapshot);
        _publishSyncState();
        unawaited(cache.save(snapshot));
      },
      onError: (Object _) {
        // A failed live stream is not an error the user needs to see if there
        // is cached data to fall back to.
        unawaited(_emitCached());
        _publishSyncState();
      },
    );

    _connectivitySub = connectivity.watch().listen((_) {
      _publishSyncState();
    });
  }

  Future<void> _emitCached() async {
    final cached = await cache.load();
    if (cached != null && !_snapshots.isClosed) {
      _snapshots.add(cached);
      _lastSyncedAt ??= cached.capturedAt;
      _publishSyncState();
    }
  }

  void _publishSyncState() {
    if (_syncStates.isClosed) return;
    _syncStates.add(
      SyncState(
        isOnline: connectivity.isOnline,
        pendingWrites: 0, // ingestion writes server-side; nothing queues here
        lastSyncedAt: _lastSyncedAt,
      ),
    );
  }

  void dispose() {
    _repositorySub?.cancel();
    _connectivitySub?.cancel();
    _snapshots.close();
    _syncStates.close();
  }
}
