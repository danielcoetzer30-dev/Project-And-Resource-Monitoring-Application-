/// What a team states about a project, as opposed to what ingestion measures.
///
/// The half of a project people own. A name, a client, a budget and a roster
/// cannot be read passively the way commits can, so they are stated here and
/// read on every scoring run.
///
/// Kept separate from `projects/` because that collection is ingestion's
/// output and read-only to every client, which is what stops a team editing
/// its own scores. This is also how a project comes into existence: ingestion
/// builds the `projects/` document from the plan, so a new project reaches
/// the dashboard on the next run.
///
/// Not status entry in the sense constraint 4 rules out. Nothing here says how
/// the work is going, and nothing here flatters a score: spending more of a
/// budget always lowers it.
class ProjectPlan {
  const ProjectPlan({
    required this.projectId,
    this.name = '',
    this.client = '',
    this.squadId = '',
    this.budgetTotal = 0,
    this.budgetSpent = 0,
    this.startDate,
    this.endDate,
    this.weeklyHours = 0,
    this.isArchived = false,
  });

  /// Empty for a plan that has not been saved yet.
  final String projectId;

  final String name;

  /// Who the work is for. Free text, and shown as the project's subtitle.
  final String client;

  /// The squad doing the work. A project with no squad is never scored,
  /// because activity arrives attributed to a squad and nothing would match.
  final String squadId;

  /// Currency is deliberately not recorded. Only the ratio is ever used, so
  /// storing an amount without a unit cannot produce a wrong conversion.
  final double budgetTotal;
  final double budgetSpent;

  final DateTime? startDate;
  final DateTime? endDate;

  /// Hours the squad is expected to spend on this project in a normal week,
  /// across the whole squad. Not a per-person figure.
  ///
  /// It has to match what the source actually reports or the idle-time
  /// indicator becomes a fact about this number rather than about the work.
  final double weeklyHours;

  /// Archived projects stop being scored and leave the dashboard.
  ///
  /// There is no hard delete, and that is deliberate. Removing a failing
  /// project is the simplest way to make it stop looking bad, which is the
  /// behaviour the whole anti-gaming argument exists to resist. Archiving
  /// keeps the history and the seam, so a project that went wrong can still
  /// be looked at afterwards, which is the post-mortem this app is supposed
  /// to make unnecessary, not impossible.
  final bool isArchived;

  /// True when there is enough here to score budget burn and idle time.
  ///
  /// Checked rather than assumed: a project whose plan was half filled in
  /// should be scored on what is known about it, not on zeroes that would
  /// read as a team spending nothing and working never.
  bool get isUsable =>
      budgetTotal > 0 &&
      weeklyHours > 0 &&
      startDate != null &&
      endDate != null;

  /// How far through the planned schedule we are, 0 to 1, or null when the
  /// dates are missing or make no sense.
  double? scheduleElapsedAt(DateTime now) {
    final start = startDate;
    final end = endDate;
    if (start == null || end == null) return null;

    final total = end.difference(start).inMinutes;
    if (total <= 0) return null;

    final gone = now.difference(start).inMinutes;
    if (gone <= 0) return 0;
    return gone >= total ? 1 : gone / total;
  }

  /// Whole days of schedule left, floored at zero. Null when undatable.
  int? scheduleDaysRemainingAt(DateTime now) {
    final end = endDate;
    if (end == null) return null;

    final left = end.difference(now).inDays;
    return left > 0 ? left : 0;
  }

  ProjectPlan copyWith({
    String? name,
    String? client,
    String? squadId,
    double? budgetTotal,
    double? budgetSpent,
    DateTime? startDate,
    DateTime? endDate,
    double? weeklyHours,
    bool? isArchived,
  }) {
    return ProjectPlan(
      projectId: projectId,
      name: name ?? this.name,
      client: client ?? this.client,
      squadId: squadId ?? this.squadId,
      budgetTotal: budgetTotal ?? this.budgetTotal,
      budgetSpent: budgetSpent ?? this.budgetSpent,
      startDate: startDate ?? this.startDate,
      endDate: endDate ?? this.endDate,
      weeklyHours: weeklyHours ?? this.weeklyHours,
      isArchived: isArchived ?? this.isArchived,
    );
  }
}

/// What may be saved, in one place so the app, the mock and the security
/// rules agree.
///
/// `firestore.rules` repeats these limits. If you change one, change both.
abstract final class ProjectPlanRules {
  static const maxName = 80;
  static const maxClient = 80;

  /// Enough for a decade. The cap exists so a typo in a date picker cannot
  /// produce a schedule that makes every forecast meaningless.
  static const maxScheduleDays = 3650;

  static int _length(String raw) => raw.trim().runes.length;

  static String? nameProblem(String raw) {
    final length = _length(raw);
    if (length == 0) return 'Give the project a name.';
    if (length > maxName) {
      return 'Keep the name to $maxName characters or fewer.';
    }
    return null;
  }

  static String? clientProblem(String raw) {
    if (_length(raw) > maxClient) {
      return 'Keep the client to $maxClient characters or fewer.';
    }
    return null;
  }

  /// Money is checked for sense, not for size. A spend above the total is
  /// allowed, that is an overrun, and reporting it is the point.
  static String? budgetProblem(ProjectPlan plan) {
    if (plan.budgetTotal < 0 || plan.budgetSpent < 0) {
      return 'Budget figures cannot be negative.';
    }
    return null;
  }

  static String? scheduleProblem(ProjectPlan plan) {
    final start = plan.startDate;
    final end = plan.endDate;

    if (start == null || end == null) return null;

    if (!end.isAfter(start)) return 'The end date has to be after the start.';

    if (end.difference(start).inDays > maxScheduleDays) {
      return 'A schedule longer than ten years is probably a typo.';
    }

    return null;
  }

  static String? hoursProblem(double weeklyHours) {
    if (weeklyHours < 0) return 'Weekly hours cannot be negative.';
    return null;
  }

  /// The first thing wrong with [plan], or null when it can be saved.
  ///
  /// A squad is required: activity arrives attributed to a squad, so a
  /// project without one would be created and then never scored, which looks
  /// exactly like a project nobody is working on.
  static String? problemWith(ProjectPlan plan) {
    return nameProblem(plan.name) ??
        clientProblem(plan.client) ??
        (plan.squadId.isEmpty ? 'Choose the squad doing this work.' : null) ??
        budgetProblem(plan) ??
        scheduleProblem(plan) ??
        hoursProblem(plan.weeklyHours);
  }
}
