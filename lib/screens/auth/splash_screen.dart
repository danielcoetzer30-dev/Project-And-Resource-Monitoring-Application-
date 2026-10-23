import 'package:flutter/material.dart';

import '../../theme/tokens.dart';
import '../../theme/typography.dart';

/// The first thing the app draws, while it works out whether anybody is
/// signed in.
///
/// It replaced a bare spinner. The wait is real, Firebase has to restore the
/// session and then read the user's document for their organisation and role,
/// and on a slow connection an unlabelled spinner on a dark screen reads as an
/// app that has failed to start.
///
/// Deliberately plain, and deliberately not a data screen. It states the name,
/// what the app is for, and that it is still working. Nothing here needs a
/// connection, so it renders instantly whatever the network is doing, which is
/// the same reason the Home tab shows no data.
class SplashScreen extends StatelessWidget {
  const SplashScreen({super.key, this.message = 'Checking your session'});

  /// What the app is waiting for. Stated rather than implied, so a long wait
  /// is explained instead of just being long.
  final String message;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Tokens.shaft,
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(Tokens.space6),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // A measured line that dips and recovers, over the baseline it
              // is judged against, the same idea as the health seam, at the
              // smallest size it still reads at. Drawn rather than shipped as
              // an asset, so it scales and recolours with the theme.
              const _PrahmMark(),
              const SizedBox(height: Tokens.space5),
              Text('PRAHM', style: AppType.display),
              const SizedBox(height: Tokens.space2),
              Text(
                'Project health, read from the tools your team already uses.',
                style: AppType.bodyMuted,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: Tokens.space6),
              const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Tokens.slate,
                ),
              ),
              const SizedBox(height: Tokens.space3),
              // Announced to a screen reader as a live region, so somebody not
              // looking at the spinner is still told the app is working.
              Semantics(
                liveRegion: true,
                child: Text(
                  message,
                  style: AppType.label,
                  textAlign: TextAlign.center,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// The app mark: a rising seam over a baseline.
///
/// The same two-element idea as `HealthSeam`, a measured line against the
/// level it is judged by, at the smallest size it still reads at.
class _PrahmMark extends StatelessWidget {
  const _PrahmMark();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 72,
      height: 44,
      child: CustomPaint(painter: _PrahmPainter()),
    );
  }
}

class _PrahmPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final baseline = Paint()
      ..color = Tokens.rule
      ..strokeWidth = 1.5
      ..strokeCap = StrokeCap.round;

    final seam = Paint()
      ..color = Tokens.beacon
      ..strokeWidth = 2.5
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    canvas.drawLine(
      Offset(0, size.height - 1),
      Offset(size.width, size.height - 1),
      baseline,
    );

    // Dips, then recovers above where it started: the shape a project makes
    // when something was caught early.
    final path = Path()
      ..moveTo(0, size.height * 0.55)
      ..lineTo(size.width * 0.32, size.height * 0.82)
      ..lineTo(size.width * 0.62, size.height * 0.34)
      ..lineTo(size.width, size.height * 0.12);

    canvas.drawPath(path, seam);
  }

  // Nothing here depends on state, so it never needs repainting.
  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
