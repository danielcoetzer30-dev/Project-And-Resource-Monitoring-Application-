import 'package:flutter/material.dart';

import '../theme/tokens.dart';

/// A compact trend line for one indicator's recent history.
///
/// The Seam shows *state* over time in bands; this shows *value* over time as
/// a line. They answer different questions: the Seam says "how long has this
/// been bad", a sparkline says "is this number moving".
///
/// The last point is emphasised, because the current value is the one being
/// read and the line behind it is context.
class Sparkline extends StatelessWidget {
  const Sparkline({
    super.key,
    required this.values,
    this.color = Tokens.beacon,
    this.height = 32,
    this.showArea = true,
  });

  /// Oldest first. Values are on any scale; the line normalises to its own
  /// minimum and maximum, so a flat series renders flat rather than noisy.
  final List<double> values;

  final Color color;
  final double height;
  final bool showArea;

  @override
  Widget build(BuildContext context) {
    if (values.length < 2) {
      return SizedBox(height: height);
    }

    return SizedBox(
      height: height,
      child: CustomPaint(
        size: Size.infinite,
        painter: _SparklinePainter(
          values: values,
          color: color,
          showArea: showArea,
        ),
      ),
    );
  }
}

class _SparklinePainter extends CustomPainter {
  _SparklinePainter({
    required this.values,
    required this.color,
    required this.showArea,
  });

  final List<double> values;
  final Color color;
  final bool showArea;

  @override
  void paint(Canvas canvas, Size size) {
    final lowest = values.reduce((a, b) => a < b ? a : b);
    final highest = values.reduce((a, b) => a > b ? a : b);
    final range = highest - lowest;

    // A flat series has no range to normalise against. Draw it down the middle
    // rather than dividing by zero.
    double yFor(double value) {
      if (range == 0) return size.height / 2;
      final normalised = (value - lowest) / range;
      return size.height - (normalised * size.height);
    }

    final stepX = size.width / (values.length - 1);
    final points = <Offset>[
      for (var i = 0; i < values.length; i++)
        Offset(i * stepX, yFor(values[i])),
    ];

    final line = Path()..moveTo(points.first.dx, points.first.dy);
    for (final point in points.skip(1)) {
      line.lineTo(point.dx, point.dy);
    }

    if (showArea) {
      final area = Path.from(line)
        ..lineTo(points.last.dx, size.height)
        ..lineTo(points.first.dx, size.height)
        ..close();

      canvas.drawPath(area, Paint()..color = color.withValues(alpha: 0.12));
    }

    canvas.drawPath(
      line,
      Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round,
    );

    // The endpoint, emphasised.
    canvas.drawCircle(points.last, 2.5, Paint()..color = color);
  }

  @override
  bool shouldRepaint(_SparklinePainter oldDelegate) =>
      !identical(oldDelegate.values, values) || oldDelegate.color != color;
}
