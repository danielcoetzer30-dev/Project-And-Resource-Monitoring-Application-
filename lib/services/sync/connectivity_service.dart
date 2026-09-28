import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';

/// Watches whether the device has a connection.
///
/// Deliberately reports *reachability of a network*, not reachability of the
/// backend. A phone on a tower with no backhaul will report online and the
/// request will still fail, which is why every repository handles its own
/// failures rather than trusting this. What this is for is the banner: telling
/// someone their data is stale before they act on it.
class ConnectivityService {
  ConnectivityService({Connectivity? connectivity})
    : _connectivity = connectivity ?? Connectivity();

  final Connectivity _connectivity;

  StreamSubscription<List<ConnectivityResult>>? _subscription;
  final _controller = StreamController<bool>.broadcast();

  bool _isOnline = true;

  /// Last known state, for callers that cannot await a stream.
  bool get isOnline => _isOnline;

  Stream<bool> watch() {
    _subscription ??= _connectivity.onConnectivityChanged.listen((results) {
      final online = _isConnected(results);
      if (online != _isOnline) {
        _isOnline = online;
        if (!_controller.isClosed) _controller.add(online);
      }
    });

    // Seed the current state so a listener does not wait for the first change.
    unawaited(_refresh());

    return _controller.stream;
  }

  Future<void> _refresh() async {
    try {
      final results = await _connectivity.checkConnectivity();
      _isOnline = _isConnected(results);
      if (!_controller.isClosed) _controller.add(_isOnline);
    } catch (_) {
      // Assume online rather than blocking the app behind a failed check.
      _isOnline = true;
    }
  }

  bool _isConnected(List<ConnectivityResult> results) {
    return results.any((r) => r != ConnectivityResult.none);
  }

  void dispose() {
    _subscription?.cancel();
    _controller.close();
  }
}
