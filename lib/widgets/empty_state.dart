import 'package:flutter/material.dart';

import '../theme/tokens.dart';
import '../theme/typography.dart';

/// An empty screen is an invitation to act, not a blank.
///
/// Every empty state in the app names what is missing and what to do about it.
/// "No projects" tells someone nothing; "Connect a repository to start
/// tracking" tells them where to go next.
class EmptyState extends StatelessWidget {
  const EmptyState({
    super.key,
    required this.icon,
    required this.headline,
    required this.body,
    this.actionLabel,
    this.onAction,
  });

  final IconData icon;

  /// What is missing, as a statement rather than an error.
  final String headline;

  /// What to do about it.
  final String body;

  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(Tokens.space6),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 30, color: Tokens.slate),
            const SizedBox(height: Tokens.space4),
            Text(headline, style: AppType.heading, textAlign: TextAlign.center),
            const SizedBox(height: Tokens.space2),
            Text(body, style: AppType.bodyMuted, textAlign: TextAlign.center),
            if (actionLabel != null && onAction != null) ...[
              const SizedBox(height: Tokens.space5),
              TextButton(
                onPressed: onAction,
                style: TextButton.styleFrom(
                  foregroundColor: Tokens.beacon,
                  side: BorderSide(color: Tokens.beacon.withValues(alpha: 0.4)),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(Tokens.radiusSm),
                  ),
                  padding: const EdgeInsets.symmetric(
                    horizontal: Tokens.space5,
                    vertical: Tokens.space3,
                  ),
                ),
                child: Text(
                  actionLabel!,
                  style: AppType.bodyStrong.copyWith(color: Tokens.beacon),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
