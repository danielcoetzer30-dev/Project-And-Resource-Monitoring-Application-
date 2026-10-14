import 'package:flutter/material.dart';

import '../models/health_state.dart';
import 'tokens.dart';

/// How each [HealthState] is drawn.
///
/// Separate from the enum so the state itself stays pure Dart and ingestion can
/// score projects server-side against the same definition the app renders.
///
/// Presentation code uses the colour, the icon **and** [HealthState.label]
/// together. Colour alone is not an accessible signal — `StatusPill` is the
/// component that gets this right, and everything else should follow it.
extension HealthStateStyle on HealthState {
  Color get color => switch (this) {
    HealthState.onTrack => Tokens.jade,
    HealthState.watch => Tokens.brass,
    HealthState.atRisk => Tokens.ember,
    HealthState.critical => Tokens.flare,
  };

  IconData get icon => switch (this) {
    HealthState.onTrack => Icons.check_circle_outline,
    HealthState.watch => Icons.trending_down,
    HealthState.atRisk => Icons.warning_amber_outlined,
    HealthState.critical => Icons.error_outline,
  };
}
