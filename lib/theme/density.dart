import 'package:flutter/material.dart';

/// Lets widgets follow the Density choice under Customisations.
///
/// The choice already reaches the theme as a [VisualDensity], so widgets read
/// it from there. That means no widget needs to know about the preferences
/// provider, and each one rebuilds on its own when the theme changes.
extension DensityContext on BuildContext {
  /// True when the person picked Compact.
  bool get isCompact => Theme.of(this).visualDensity.vertical < 0;

  /// A spacing value, tightened by a quarter when Compact is on.
  ///
  /// Pass the same [Tokens] value the widget used before, e.g.
  /// `context.dense(Tokens.space4)`.
  double dense(double space) =>
      isCompact ? (space * 0.75).roundToDouble() : space;
}
