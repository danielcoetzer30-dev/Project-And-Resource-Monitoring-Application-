import 'package:flutter/widgets.dart';

/// Every colour, space and radius in the app resolves here.
/// Change a value in this file and it changes everywhere.
abstract final class Tokens {
  // --- Structure -----------------------------------------------------------
  // A blue-black base rather than neutral grey, so the warm signal ramp below
  // reads as deliberate rather than as tinting on top of grey.
  static const shaft = Color(0xFF0D141B); // app background
  static const seam = Color(0xFF151F29); // panel surface
  static const rule = Color(0xFF24313E); // hairlines, gridlines, dividers
  static const chalk = Color(0xFFE6EDF3); // primary text, metrics
  static const slate = Color(0xFF8697A8); // labels, secondary text, axes

  /// Interactive affordances only — links, focus rings, selection.
  /// Deliberately cool so "tappable" can never be misread as a health state.
  static const beacon = Color(0xFF4C9DD8);

  // --- Signal ramp ---------------------------------------------------------
  // Runs cool -> hot, so it carries a temperature reading and a luminance
  // progression. That survives red/green colour blindness far better than a
  // plain red/amber/green set. Never used decoratively.
  static const jade = Color(0xFF35A87C); // on track
  static const brass = Color(0xFFD8A33A); // watch
  static const ember = Color(0xFFE2703A); // at risk
  static const flare = Color(0xFFE04B4B); // critical

  // --- Spacing -------------------------------------------------------------
  static const space1 = 4.0;
  static const space2 = 8.0;
  static const space3 = 12.0;
  static const space4 = 16.0;
  static const space5 = 24.0;
  static const space6 = 32.0;
  static const space7 = 48.0;

  // --- Radii ---------------------------------------------------------------
  // Small throughout. Instrument panel, not a card grid.
  static const radiusSm = 4.0;
  static const radiusMd = 6.0;
  static const radiusLg = 10.0;

  static const hairline = 1.0;
}
