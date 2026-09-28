import '../models/health_state.dart';
import '../models/project_metrics.dart';
import '../models/signal.dart';
import 'health_scoring/health_score_engine.dart';

/// Turns a health assessment into early warnings.
///
/// The score says how a project is doing. A signal says what specifically is
/// wrong and why, which is the difference between a dashboard and an early
/// warning system — the research is explicit that existing tools are reactive
/// because they report state without explaining it.
///
/// Every signal this produces carries its reasoning. That is enforced by the
/// Signal model itself, where `because` is a required field.
class SignalEngine {
  const SignalEngine();

  /// Thresholds below which a factor is worth raising on its own, even when
  /// the overall score still looks acceptable. A project can be averaging 70
  /// while its budget quietly runs out.
  static const _factorConcern = 40.0;
  static const _factorCritical = 25.0;

  List<Signal> evaluate({
    required HealthAssessment assessment,
    required ProjectMetrics metrics,
    required String projectName,
  }) {
    final signals = <Signal>[];
    final now = DateTime.now();

    // --- Whole-project signal ---------------------------------------------
    if (assessment.state.severity >= HealthState.atRisk.severity) {
      signals.add(
        Signal(
          id: '${metrics.projectId}-overall',
          title: '$projectName is trending toward failure',
          because:
              'The composite health score is ${assessment.score.round()} out of 100, '
              'which is ${assessment.state.label}. '
              '${_weakestFactorSentence(assessment)}',
          severity: assessment.state,
          projectId: metrics.projectId,
          raisedAt: now,
        ),
      );
    }

    // --- Per-factor signals -------------------------------------------------
    for (final factor in assessment.factors) {
      if (factor.value >= _factorConcern) continue;

      final severity = factor.value < _factorCritical
          ? HealthState.critical
          : HealthState.atRisk;

      signals.add(
        Signal(
          id: '${metrics.projectId}-${_slug(factor.name)}',
          title: '$projectName: ${factor.name.toLowerCase()} needs attention',
          because:
              '${factor.detail}. This indicator carries '
              '${(factor.weight * 100).round()}% of the overall score.',
          severity: severity,
          projectId: metrics.projectId,
          raisedAt: now,
        ),
      );
    }

    // --- Infrastructure -----------------------------------------------------
    // Raised separately and flagged, so nobody reads lost grid hours as a
    // delivery problem. Nothing here reduces a score; it explains one.
    if (metrics.outageHours > 0) {
      final lostFraction = metrics.availableHours > 0
          ? metrics.outageHours / metrics.availableHours
          : 0.0;

      if (lostFraction > 0.1) {
        signals.add(
          Signal(
            id: '${metrics.projectId}-outage',
            title:
                '$projectName lost ${metrics.outageHours.toStringAsFixed(1)} hours to outages',
            because:
                'That is ${(lostFraction * 100).round()}% of the squad\'s rostered time in this window. '
                'Capacity forecasts have been adjusted; no health score was reduced for it.',
            severity: lostFraction > 0.25
                ? HealthState.atRisk
                : HealthState.watch,
            projectId: metrics.projectId,
            raisedAt: now,
            infrastructureRelated: true,
          ),
        );
      }
    }

    signals.sort((a, b) => b.severity.severity.compareTo(a.severity.severity));
    return signals;
  }

  String _weakestFactorSentence(HealthAssessment assessment) {
    if (assessment.factors.isEmpty) return '';

    final weakest = assessment.factors.reduce(
      (a, b) => a.value <= b.value ? a : b,
    );
    return 'The weakest indicator is ${weakest.name.toLowerCase()}: ${weakest.detail}.';
  }

  String _slug(String name) =>
      name.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]+'), '-');
}
