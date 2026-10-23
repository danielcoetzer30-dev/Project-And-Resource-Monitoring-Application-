import '../models/project_plan.dart';

/// The projects a team has told the app about.
///
/// Deliberately not on [ProjectRepository]. That interface reads ingestion's
/// output and has no write method, which is constraint 4 in code; this one
/// writes what people state. Keeping them apart is what makes the difference
/// visible at the call site, a screen that saves a plan cannot accidentally
/// be a screen that edits a score.
///
/// The split in one line: a plan says what a project *is*, and `projects/`
/// says how it is *going*.
abstract interface class ProjectPlanRepository {
  /// Every plan for the organisation, archived ones included.
  ///
  /// Archived plans are returned rather than filtered so a team can find one
  /// again and bring it back. Screens decide what to show.
  Stream<List<ProjectPlan>> watch();

  /// One plan, or null when there is none.
  Stream<ProjectPlan?> watchOne(String projectId);

  /// Creates or replaces a plan, returning the id it was saved under.
  ///
  /// A plan with an empty [ProjectPlan.projectId] is new and gets one
  /// allocated. Ingestion creates the matching `projects/` document on its
  /// next run, so a project appears on the dashboard shortly after it is
  /// saved rather than instantly, which is honest, because there is nothing
  /// to say about its health until something has been read.
  Future<String> save(ProjectPlan plan);

  /// Archives a plan, or brings it back.
  ///
  /// There is no delete. Removing a failing project is the simplest way to
  /// make it stop looking bad, and the history is the research record.
  Future<void> setArchived({required String projectId, required bool archived});
}
