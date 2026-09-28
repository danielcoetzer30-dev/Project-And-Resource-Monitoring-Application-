import 'dart:async';

import '../../core/constants/app_constants.dart';
import '../../models/ingestion_source.dart';
import 'ingestion_service.dart';

/// Runs ingestion on a timer, and backs off when it should not.
///
/// Backing off matters more here than in most apps. The users are on South
/// African mobile data with intermittent connectivity, and a scheduler that
/// retries hard through an outage burns both battery and prepaid data at
/// exactly the moment a team can least afford it.
class IngestionScheduler {
  IngestionScheduler({
    required this.service,
    required this.sourcesProvider,
    required this.tokensProvider,
    required this.isOnline,
    this.interval = AppConstants.pollInterval,
  });

  final IngestionService service;

  /// Read fresh each run, so adding a source takes effect without a restart.
  final Future<List<IngestionSource>> Function() sourcesProvider;
  final Future<Map<String, String>> Function() tokensProvider;

  /// Checked before every run. False means skip entirely rather than fail.
  final bool Function() isOnline;

  final Duration interval;

  Timer? _timer;
  bool _running = false;
  int _consecutiveFailures = 0;

  final _results = StreamController<IngestionResult>.broadcast();

  Stream<IngestionResult> get results => _results.stream;

  void start() {
    if (_timer != null) return;
    _timer = Timer.periodic(interval, (_) => _tick());
    unawaited(_tick()); // run once immediately rather than waiting a full cycle
  }

  void stop() {
    _timer?.cancel();
    _timer = null;
  }

  Future<void> _tick() async {
    // Never overlap runs. A slow run on a bad connection would otherwise stack
    // up behind itself.
    if (_running) return;
    if (!isOnline()) return;

    // Exponential back-off, capped. After repeated failures the scheduler
    // waits several cycles rather than hammering an endpoint that is down.
    if (_consecutiveFailures > 0) {
      final skipCycles = _consecutiveFailures.clamp(1, 8);
      if (DateTime.now().millisecondsSinceEpoch %
              (skipCycles * interval.inMilliseconds) >
          interval.inMilliseconds) {
        return;
      }
    }

    _running = true;
    try {
      final sources = await sourcesProvider();
      if (sources.isEmpty) return;

      final tokens = await tokensProvider();
      final now = DateTime.now();

      final result = await service.run(
        sources: sources,
        tokensBySourceId: tokens,
        windowStart: now.subtract(
          const Duration(days: AppConstants.seamWindowDays),
        ),
        windowEnd: now,
      );

      _consecutiveFailures = result.isCompletelyFailed
          ? _consecutiveFailures + 1
          : 0;

      if (!_results.isClosed) _results.add(result);
    } catch (_) {
      _consecutiveFailures++;
    } finally {
      _running = false;
    }
  }

  void dispose() {
    stop();
    _results.close();
  }
}
