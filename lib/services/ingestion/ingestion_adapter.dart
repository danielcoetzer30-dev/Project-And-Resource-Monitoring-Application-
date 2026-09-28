import '../../models/activity_event.dart';
import '../../models/ingestion_source.dart';

/// Reads activity from one kind of external system.
///
/// Adapters only read. There is no method here for writing anything back, and
/// none of them touch code content — commit messages, diffs and issue bodies
/// are never requested. Metadata is all the scoring engine needs, and asking
/// for less is what makes it defensible to point this at a client's private
/// repository.
abstract interface class IngestionAdapter {
  SourceType get type;

  /// Events since [since], newest included.
  ///
  /// The token is passed in per call and never held on the adapter or on
  /// [IngestionSource]. Credentials belong to the backend; a device only ever
  /// borrows one for the length of a request.
  Future<List<RawActivityEvent>> fetchEvents({
    required IngestionSource source,
    required DateTime since,
    required String token,
  });
}
