/// The four states everything in the app resolves to.
///
/// Deliberately free of Flutter. Ingestion scores projects server-side, where
/// there is no Flutter to import, and it has to arrive at the same states the
/// app renders — one definition, used by both.
///
/// The colour and icon that go with each state live in
/// `lib/theme/health_state_style.dart`. They are not optional: a state is
/// always shown as colour **and** icon **and** word, because colour alone is
/// not an accessible signal and this app is read at a glance by people
/// deciding whether to act.
enum HealthState {
  onTrack(label: 'On track', severity: 0),
  watch(label: 'Watch', severity: 1),
  atRisk(label: 'At risk', severity: 2),
  critical(label: 'Critical', severity: 3);

  const HealthState({required this.label, required this.severity});

  final String label;

  /// Higher is worse. Used for sorting worst-first, which is the order that
  /// matters in an early warning system.
  final int severity;

  /// Maps a 0–100 health score onto a state.
  ///
  /// Thresholds are a starting point and will move once the interview data
  /// says where the real boundaries sit.
  static HealthState fromScore(double score) {
    if (score >= 75) return HealthState.onTrack;
    if (score >= 55) return HealthState.watch;
    if (score >= 35) return HealthState.atRisk;
    return HealthState.critical;
  }

  /// Parses a stored state name back into a state.
  ///
  /// Falls back to onTrack rather than throwing: a malformed document should
  /// not take down the whole dashboard.
  static HealthState fromName(String? name) {
    return HealthState.values.firstWhere(
      (state) => state.name == name,
      orElse: () => HealthState.onTrack,
    );
  }
}
