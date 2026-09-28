import '../models/outage_window.dart';
import 'project_repository.dart';

/// Load-shedding data, as an interface.
///
/// The implementation belongs to the Infrastructure workstream — it may read a
/// public schedule API or fall back to windows a team enters by hand. Either
/// way the rest of the app only sees this.
abstract interface class OutageRepository {
  /// Current grid state, for the strip on the dashboard.
  Stream<GridStatus> watchGridStatus(String orgId);

  /// Windows starting from now, for capacity forecasting.
  Future<List<OutageWindow>> upcomingWindows(String orgId);

  /// Windows that have already happened in the given range, for working out
  /// how many hours a project lost.
  Future<List<OutageWindow>> windowsBetween({
    required String orgId,
    required DateTime from,
    required DateTime to,
  });
}
