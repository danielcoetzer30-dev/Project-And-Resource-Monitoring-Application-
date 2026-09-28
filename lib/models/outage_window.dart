/// A scheduled load-shedding slot.
///
/// Stored as its own record rather than as a field on a project, because one
/// outage affects several squads at once and the hours it costs have to be
/// attributable to each of them independently.
class OutageWindow {
  const OutageWindow({
    required this.id,
    required this.stage,
    required this.start,
    required this.end,
    required this.affectedSquadIds,
  });

  final String id;

  final int stage;

  final DateTime start;
  final DateTime end;

  final List<String> affectedSquadIds;

  Duration get duration => end.difference(start);
  double get hoursLost => duration.inMinutes / 60.0;

  bool isActiveAt(DateTime moment) {
    return moment.isAfter(start) && moment.isBefore(end);
  }

  bool get isUpcoming => start.isAfter(DateTime.now());
}
