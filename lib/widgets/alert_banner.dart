import 'package:flutter/material.dart';

import '../services/sync/notification_service.dart';
import '../theme/health_state_style.dart';
import '../theme/tokens.dart';
import '../theme/typography.dart';

/// Says that a project has just crossed into, or out of, a failing state.
///
/// The in-app half of alerting. The tray notification is for somebody who is
/// not looking at the app; this is for somebody who is, because a notification
/// posted while the app is open is easy to miss and tells them nothing the
/// screen could not.
///
/// Dismissible, and deliberately not blocking. An early warning is a thing to
/// notice, not a thing to acknowledge, a banner with an OK button would train
/// people to clear it without reading, which is the failure mode this whole
/// tool exists to avoid.
///
/// Like every other status in the app, it renders as colour *and* icon *and*
/// word, so it reads in greyscale and to a colour-blind user.
class AlertBanner extends StatelessWidget {
  const AlertBanner({super.key, required this.alert, required this.onDismiss});

  final HealthAlert alert;
  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) {
    final worse = alert.isWorsening;
    final colour = worse ? alert.to.color : Tokens.jade;

    return Semantics(
      liveRegion: true,
      label:
          '${alert.title}. '
          '${worse ? 'Down from' : 'Up from'} ${alert.from.label}.',
      excludeSemantics: true,
      child: Container(
        padding: const EdgeInsets.all(Tokens.space3),
        decoration: BoxDecoration(
          color: colour.withValues(alpha: 0.10),
          borderRadius: BorderRadius.circular(Tokens.radiusSm),
          border: Border.all(color: colour.withValues(alpha: 0.35)),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              worse ? Icons.trending_down : Icons.trending_up,
              size: 18,
              color: colour,
            ),
            const SizedBox(width: Tokens.space3),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    alert.title,
                    style: AppType.bodyStrong.copyWith(color: colour),
                  ),
                  const SizedBox(height: Tokens.space1),
                  Text(
                    '${worse ? 'Down from' : 'Up from'} '
                    '${alert.from.label.toLowerCase()}.',
                    style: AppType.bodyMuted,
                  ),
                ],
              ),
            ),
            const SizedBox(width: Tokens.space2),
            IconButton(
              onPressed: onDismiss,
              icon: const Icon(Icons.close, size: 16),
              color: Tokens.slate,
              visualDensity: VisualDensity.compact,
              tooltip: 'Dismiss',
            ),
          ],
        ),
      ),
    );
  }
}
