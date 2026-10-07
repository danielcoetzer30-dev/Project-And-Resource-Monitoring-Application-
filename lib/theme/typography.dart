import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'tokens.dart';

/// Three faces, three jobs.
///
/// Archivo carries structure, IBM Plex Sans carries prose, IBM Plex Mono
/// carries anything that changes while you are looking at it. Numbers use
/// tabular figures so a live-updating metric does not jitter as digits change
/// width — the whole app is numbers that move.
abstract final class AppType {
  static TextStyle get _tabular =>
      const TextStyle(fontFeatures: [FontFeature.tabularFigures()]);

  // --- Display: Archivo ----------------------------------------------------
  /// Screen titles.
  static TextStyle get display => GoogleFonts.archivo(
    fontSize: 26,
    fontWeight: FontWeight.w700,
    letterSpacing: -0.6,
    height: 1.15,
    color: Tokens.chalk,
  );

  /// Section headings inside a screen.
  static TextStyle get heading => GoogleFonts.archivo(
    fontSize: 17,
    fontWeight: FontWeight.w600,
    letterSpacing: -0.2,
    height: 1.25,
    color: Tokens.chalk,
  );

  /// The large numbers — health scores, counts.
  static TextStyle get metric => GoogleFonts.archivo(
    fontSize: 34,
    fontWeight: FontWeight.w700,
    letterSpacing: -1.2,
    height: 1.0,
    color: Tokens.chalk,
  ).merge(_tabular);

  static TextStyle get metricSmall => GoogleFonts.archivo(
    fontSize: 20,
    fontWeight: FontWeight.w700,
    letterSpacing: -0.5,
    height: 1.0,
    color: Tokens.chalk,
  ).merge(_tabular);

  // --- Body: IBM Plex Sans -------------------------------------------------
  static TextStyle get body => GoogleFonts.ibmPlexSans(
    fontSize: 14,
    fontWeight: FontWeight.w400,
    height: 1.45,
    color: Tokens.chalk,
  );

  static TextStyle get bodyMuted => body.copyWith(color: Tokens.slate);

  static TextStyle get bodyStrong => body.copyWith(fontWeight: FontWeight.w500);

  // --- Utility -------------------------------------------------------------
  /// Small caps-ish label for panel headers and axes.
  static TextStyle get label => GoogleFonts.ibmPlexSans(
    fontSize: 11,
    fontWeight: FontWeight.w600,
    letterSpacing: 0.8,
    height: 1.2,
    color: Tokens.slate,
  );

  /// Data face — timestamps, deltas, identifiers, anything monospaced.
  static TextStyle get data => GoogleFonts.ibmPlexMono(
    fontSize: 12,
    fontWeight: FontWeight.w500,
    height: 1.3,
    color: Tokens.slate,
  ).merge(_tabular);

  static TextStyle get dataStrong => data.copyWith(color: Tokens.chalk);
}
