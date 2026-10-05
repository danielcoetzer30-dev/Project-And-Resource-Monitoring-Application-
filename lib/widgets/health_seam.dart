import 'package:flutter/material.dart';

import '../models/health_state.dart';
import '../theme/tokens.dart';

/// One period of a project's history — a day, a sprint, whatever the caller
/// decides a segment means.
class SeamSegment {
  const SeamSegment({
    required this.state,
    required this.periodLabel,
    this.flagged = false,
  });

  final HealthState state;

  /// What this segment covers, e.g. "12 Jul" or "Sprint 4".
  final String periodLabel;

  /// A risk flag fired during this period. Drawn as a notch above the segment.
  final bool flagged;
}

/// The Health Seam.
///
/// Reads left to right as trajectory rather than snapshot: the point is to see
/// "this has been drifting for nine days", which is the difference between an
/// early warning system and a status light. Compact on list rows, expanded on
/// detail screens.
class HealthSeam extends StatelessWidget {
  const HealthSeam({
    super.key,
    required this.segments,
    this.height = 22,
    this.showAxis = false,
  });

  /// Oldest first, newest last.
  final List<SeamSegment> segments;
  final double height;

  /// Labels the first and last period. Detail screens want this; list rows
  /// would only be made noisier by it.
  final bool showAxis;

  @override
  Widget build(BuildContext context) {
    if (segments.isEmpty) {
      return SizedBox(
        height: height,
        child: Align(
          alignment: Alignment.centerLeft,
          child: Text(
            'No history yet',
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ),
      );
    }

    final latest = segments.last;
    final flagCount = segments.where((s) => s.flagged).length;

    final seam = Semantics(
      // The visual is a trend; screen readers get that trend as a sentence
      // rather than a list of eighty colours.
      label:
          'Health history over ${segments.length} periods. '
          'Currently ${latest.state.label}. '
          '${flagCount == 0 ? 'No risk flags' : '$flagCount risk flags'} in this window.',
      excludeSemantics: true,
      child: SizedBox(
        height: height,
        child: CustomPaint(
          size: Size.infinite,
          painter: _SeamPainter(segments),
        ),
      ),
    );

    if (!showAxis) return seam;

    final axisStyle = Theme.of(context).textTheme.labelSmall;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        seam,
        const SizedBox(height: Tokens.space2),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(segments.first.periodLabel, style: axisStyle),
            Text(segments.last.periodLabel, style: axisStyle),
          ],
        ),
      ],
    );
  }
}

class _SeamPainter extends CustomPainter {
  _SeamPainter(this.segments);

  final List<SeamSegment> segments;

  static const _gap = 2.0;
  static const _notchHeight = 4.0;
  static const _notchGap = 3.0;

  @override
  void paint(Canvas canvas, Size size) {
    final count = segments.length;
    if (count == 0) return;

    // Below roughly 3px per segment the gaps eat the signal, so the band goes
    // solid and reads as a continuous ribbon instead.
    final slot = size.width / count;
    final gap = slot > 5 ? _gap : 0.0;

    final top = _notchHeight + _notchGap;
    final barHeight = size.height - top;
    if (barHeight <= 0) return;

    final radius = Radius.circular(gap == 0 ? 0 : 1.5);
    final notchPaint = Paint()..color = Tokens.chalk;

    for (var i = 0; i < count; i++) {
      final segment = segments[i];
      final left = i * slot;
      final width = (slot - gap).clamp(0.5, slot);

      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(left, top, width, barHeight),
          radius,
        ),
        Paint()..color = segment.state.color,
      );

      if (segment.flagged) {
        // A chalk tick above the band. Colour already encodes state, so the
        // flag needs a different channel — position and shape — to be legible
        // to someone who cannot separate the hues.
        final notchWidth = width.clamp(1.0, 3.0);
        canvas.drawRect(
          Rect.fromLTWH(
            left + (width - notchWidth) / 2,
            0,
            notchWidth,
            _notchHeight,
          ),
          notchPaint,
        );
      }
    }
  }

  @override
  bool shouldRepaint(_SeamPainter oldDelegate) =>
      !identical(oldDelegate.segments, segments);
}
