import 'dart:async';

import 'package:flutter_test/flutter_test.dart';

import 'package:keel/core/errors/exceptions.dart';
import 'package:keel/core/errors/failure.dart';
import 'package:keel/data/local_cache.dart';
import 'package:keel/data/project_repository.dart';
import 'package:keel/models/sync_state.dart';
import 'package:keel/services/sync/connectivity_service.dart';
import 'package:keel/services/sync/sync_service.dart';

/// How current the app says its data is.
///
/// This is the promise the whole offline story rests on: the application is
/// built for a country where the power goes off, so "is this number still
/// true?" has to be answerable without being asked. It was not. The repository
/// reported every snapshot as live because the flag was hardcoded, and the
/// sync state was published to a broadcast stream that dropped it for anybody
/// who subscribed a frame later.
void main() {
  HealthSnapshot snapshot({required bool isLive, DateTime? capturedAt}) {
    return HealthSnapshot(
      projects: const [],
      squads: const [],
      signals: const [],
      grid: const GridStatus(
        stage: 0,
        nextOutageStart: null,
        nextOutageEnd: null,
        hoursLostThisWeek: 0,
      ),
      capturedAt: capturedAt ?? DateTime.now(),
      isLive: isLive,
    );
  }

  group('the banner has something to render from', () {
    test(
      'a late listener is told the current state, not left waiting',
      () async {
        // The bug this pins: the shell subscribes a frame or two after the
        // service starts, so a connectivity change announced before then went
        // to nobody and the banner stayed hidden for the whole session.
        final repository = _StubRepository();
        addTearDown(repository.dispose);

        final connectivity = _StubConnectivity(online: false);
        addTearDown(connectivity.dispose);

        final service = SyncService(
          repository: repository,
          connectivity: connectivity,
          cache: const _NoCache(),
        );
        addTearDown(service.dispose);

        // Start it and let it publish before anybody is listening.
        service.watch().listen((_) {});
        repository.emit(snapshot(isLive: true));
        await Future<void>.delayed(Duration.zero);

        // Subscribing only now.
        final state = await service.watchSyncState().first.timeout(
          const Duration(seconds: 2),
        );

        expect(state.isOnline, isFalse);
      },
    );

    test('asking how current the data is does not require asking for the '
        'data first', () async {
      final repository = _StubRepository();
      addTearDown(repository.dispose);
      final connectivity = _StubConnectivity(online: false);
      addTearDown(connectivity.dispose);

      final service = SyncService(
        repository: repository,
        connectivity: connectivity,
        cache: const _NoCache(),
      );
      addTearDown(service.dispose);

      // No call to watch() at all.
      final state = await service.watchSyncState().first.timeout(
        const Duration(seconds: 2),
      );

      expect(state.isOnline, isFalse);
    });
  });

  group('staleness', () {
    test('a snapshot from hours ago is stale', () {
      final state = SyncState(
        isOnline: true,
        pendingWrites: 0,
        lastSyncedAt: DateTime.now().subtract(const Duration(hours: 12)),
      );

      expect(state.isStale, isTrue);
    });

    test('a snapshot from a moment ago is not', () {
      final state = SyncState(
        isOnline: true,
        pendingWrites: 0,
        lastSyncedAt: DateTime.now(),
      );

      expect(state.isStale, isFalse);
    });

    test('never having synced counts as stale', () {
      const state = SyncState.unknown();

      expect(state.isStale, isTrue);
      expect(state.hasSynced, isFalse);
    });

    test('a cached snapshot keeps the time the server last answered', () {
      // The second half of the same bug. If a cached snapshot reported "now",
      // the data would never age and isStale could never become true, however
      // long the device stayed offline.
      final served = DateTime.now().subtract(const Duration(hours: 9));
      final cached = snapshot(isLive: false, capturedAt: served);

      expect(cached.isLive, isFalse);
      expect(
        SyncState(
          isOnline: false,
          pendingWrites: 0,
          lastSyncedAt: cached.capturedAt,
        ).isStale,
        isTrue,
      );
    });
  });

  group('error messages reach the person', () {
    test('an auth message survives being turned into a failure', () {
      // It used to be replaced with "Sign in to continue", which is useless
      // on the one screen where knowing which of email or password was wrong
      // is the entire point.
      final failure = failureFromException(
        const AuthException('Email or password is incorrect.'),
      );

      expect(failure, isA<AuthFailure>());
      expect(failure.message, 'Email or password is incorrect.');
    });

    test('a permission message survives too', () {
      final failure = failureFromException(
        const PermissionException('Only leads and managers can do that.'),
      );

      expect(failure.message, 'Only leads and managers can do that.');
    });

    test('a network problem gets the standard wording', () {
      // Nothing useful to pass through: the exception message here is for a
      // log, and the person needs to be told what it means for them.
      final failure = failureFromException(
        const NetworkException('SocketException'),
      );

      expect(failure, isA<NetworkFailure>());
      expect(failure.message, isNot(contains('SocketException')));
    });

    test('a failure message never leads with a class name', () {
      // '$error' on an AppException prints "AuthException: ...", which is for
      // a log and not for somebody trying to get into their account.
      for (final error in <Object>[
        const AuthException('Email or password is incorrect.'),
        const PermissionException('Not allowed.'),
        const ValidationException('Enter a name.'),
        const NetworkException('whatever'),
      ]) {
        expect(
          failureFromException(error).message,
          isNot(contains('Exception')),
        );
      }
    });
  });
}

/// A repository whose stream the test drives.
class _StubRepository implements ProjectRepository {
  final _controller = StreamController<HealthSnapshot>.broadcast();

  void emit(HealthSnapshot snapshot) => _controller.add(snapshot);

  @override
  Stream<HealthSnapshot> watch() => _controller.stream;

  @override
  void dispose() => _controller.close();
}

/// Connectivity fixed at one value, so the test decides what offline means.
class _StubConnectivity implements ConnectivityService {
  _StubConnectivity({required bool online}) : isOnline = online;

  @override
  final bool isOnline;
  final _controller = StreamController<bool>.broadcast();

  @override
  Stream<bool> watch() {
    scheduleMicrotask(() {
      if (!_controller.isClosed) _controller.add(isOnline);
    });
    return _controller.stream;
  }

  @override
  void dispose() => _controller.close();
}

/// A cache that holds nothing, so the test sees only what the stream produced.
class _NoCache implements LocalCache {
  const _NoCache();

  @override
  Future<HealthSnapshot?> load() async => null;

  @override
  Future<void> save(HealthSnapshot snapshot) async {}

  @override
  Future<DateTime?> lastCapturedAt() async => null;

  @override
  Future<void> clear() async {}
}
