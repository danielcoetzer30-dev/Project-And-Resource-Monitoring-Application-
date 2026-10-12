import 'package:flutter/material.dart';

import '../models/preferences.dart';

/// Applies the person's text size and bold text choice to everything below.
///
/// Text size multiplies the phone's own setting rather than replacing it, so a
/// person who already runs large system text still gets larger text, never
/// smaller. Bold text uses Flutter's own flag, which every [Text] honours, so
/// no widget needs to know about it.
Widget accessibilityScope(
  BuildContext context, {
  required TextSize textSize,
  required bool boldText,
  required Widget child,
}) {
  final media = MediaQuery.of(context);
  final system = media.textScaler.scale(1);

  return MediaQuery(
    data: media.copyWith(
      textScaler: TextScaler.linear((system * textSize.scale).clamp(0.8, 2.0)),
      boldText: media.boldText || boldText,
    ),
    child: child,
  );
}
