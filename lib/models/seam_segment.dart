import 'health_state.dart';

/// One period of a project's history — a day, a sprint, whatever the caller
/// decides a segment means.
///
/// Lives in `models/` rather than next to the widget that draws it because
/// ingestion builds these server-side, where there is no Flutter. A plain data
/// class is the only thing both sides can share.
class SeamSegment {
  const SeamSegment({
    required this.state,
    required this.periodLabel,
    this.flagged = false,
  });

  final HealthState state;

  /// What this segment covers, e.g. "12 Jul" or "Sprint 4".
  final String periodLabel;

  /// A risk flag fired during this period. Drawn as a notch above the segment.
  final bool flagged;
}
