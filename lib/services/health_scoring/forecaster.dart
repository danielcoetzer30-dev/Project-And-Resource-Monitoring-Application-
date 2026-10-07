import '../../models/project.dart';

/// What the current trend implies about the end of a project.
///
/// Every field is nullable, and null means "not enough information to say"
/// rather than zero. A monitoring tool that invents a date is worse than one
/// that admits it cannot produce one — a team will plan around a number they
/// are given, and a wrong one costs more than a blank.
class Forecast {
  const Forecast({
    this.budgetRunsOutInDays,
    this.budgetShortfallDays,
    this.projectedOverrunDays,
    this.projectedCompletionDays,
  });

  const Forecast.unknown()
    : budgetRunsOutInDays = null,
      budgetShortfallDays = null,
      projectedOverrunDays = null,
      projectedCompletionDays = null;

  /// Days until the budget is exhausted at the current burn rate.
  final int? budgetRunsOutInDays;

  /// How many days before the scope closes the money runs out. Positive means
  /// the budget goes first; negative means there is money left over.
  final int? budgetShortfallDays;

  /// Days past the planned end date, at the current velocity.
  final int? projectedOverrunDays;

  /// Days until the work actually finishes, at the current velocity.
  final int? projectedCompletionDays;

  bool get hasBudgetWarning =>
      budgetShortfallDays != null && budgetShortfallDays! > 0;

  bool get hasScheduleWarning =>
      projectedOverrunDays != null && projectedOverrunDays! > 0;

  bool get isEmpty =>
      budgetRunsOutInDays == null && projectedCompletionDays == null;
}

/// Projects the current trend forward.
///
/// Deliberately linear. The honest reading of "at the current rate" is a
/// straight line, and a straight line is something a team lead can check
/// against their own judgement. Anything fitted or smoothed would be harder to
/// argue with and no more likely to be right — there is no historical outcome
/// data to fit against, and the research this implements is qualitative.
///
/// This is what turns the app from "your project is at 28" into "your budget
/// runs out eight days before the work does", which is the difference between
/// a status light and an early warning.
class Forecaster {
  const Forecaster();

  /// Burn rates below this are treated as no signal. A project that has barely
  /// started produces a rate close to zero, and dividing by it yields a
  /// completion date centuries away.
  static const _minimumBurnRate = 0.0001;

  /// Velocity this far below baseline produces absurd projections — at 2% of
  /// baseline a two-week sprint finishes next year. Report it as stalled
  /// rather than as a date.
  static const _minimumVelocityRatio = 0.05;

  Forecast project(Project project) {
    return Forecast(
      budgetRunsOutInDays: _budgetRunsOutInDays(project),
      budgetShortfallDays: _budgetShortfall(project),
      projectedCompletionDays: _projectedCompletion(project),
      projectedOverrunDays: _projectedOverrun(project),
    );
  }

  /// Days of money left, at the rate it has been spent so far.
  int? _budgetRunsOutInDays(Project p) {
    final elapsed = p.scheduleElapsedDays;
    if (elapsed == null) return null;
    if (p.budgetBurn >= 1) return 0; // already spent

    final ratePerDay = p.budgetBurn / elapsed;
    if (ratePerDay < _minimumBurnRate) return null;

    final remaining = 1 - p.budgetBurn;
    return (remaining / ratePerDay).round();
  }

  /// How far ahead of the work the money runs out.
  ///
  /// This is the number worth acting on. Burn alone says nothing — 94% spent
  /// is fine at 94% elapsed and alarming at 60%.
  int? _budgetShortfall(Project p) {
    final runsOut = _budgetRunsOutInDays(p);
    if (runsOut == null) return null;
    return p.scheduleDaysRemaining - runsOut;
  }

  /// How long the remaining work actually takes at the current throughput.
  int? _projectedCompletion(Project p) {
    if (p.scheduleDaysRemaining <= 0) return null;
    if (p.velocityRatio < _minimumVelocityRatio) return null;

    return (p.scheduleDaysRemaining / p.velocityRatio).round();
  }

  int? _projectedOverrun(Project p) {
    final completion = _projectedCompletion(p);
    if (completion == null) return null;
    return completion - p.scheduleDaysRemaining;
  }

  /// A plain sentence for whichever problem lands first.
  ///
  /// Returns null when there is nothing to warn about, so callers can skip the
  /// row entirely rather than render "no issues".
  String? headline(Project project) {
    final f = project.forecast;

    if (f.hasBudgetWarning && f.hasScheduleWarning) {
      return 'At the current rate the budget runs out '
          '${_days(f.budgetShortfallDays!)} before the work does, and the work '
          'itself finishes ${_days(f.projectedOverrunDays!)} late.';
    }
    if (f.hasBudgetWarning) {
      return 'At the current rate the budget runs out '
          '${_days(f.budgetShortfallDays!)} before the scope closes.';
    }
    if (f.hasScheduleWarning) {
      return 'At the current velocity this finishes '
          '${_days(f.projectedOverrunDays!)} past its planned end.';
    }
    return null;
  }

  static String _days(int count) => '$count ${count == 1 ? 'day' : 'days'}';
}

/// Convenience so screens can read `project.forecast` without wiring the
/// service through every widget. The calculation is pure and cheap.
extension ProjectForecast on Project {
  Forecast get forecast => const Forecaster().project(this);
}
