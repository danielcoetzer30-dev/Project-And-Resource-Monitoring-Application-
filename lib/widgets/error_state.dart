import 'package:flutter/material.dart';

import '../core/errors/failure.dart';
import '../theme/tokens.dart';
import '../theme/typography.dart';

/// Says what went wrong and how to fix it.
///
/// Errors here do not apologise and are never vague. The message comes from
/// the [Failure] itself, which is written for the person reading it rather
/// than for a log file.
class ErrorState extends StatelessWidget {
  const ErrorState({super.key, required this.failure, this.onRetry});

  final Failure failure;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(Tokens.space6),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(_icon, size: 30, color: _colour),
            const SizedBox(height: Tokens.space4),
            Text(
              _headline,
              style: AppType.heading,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: Tokens.space2),
            Text(
              failure.message,
              style: AppType.bodyMuted,
              textAlign: TextAlign.center,
            ),
            if (onRetry != null) ...[
              const SizedBox(height: Tokens.space5),
              TextButton(
                onPressed: onRetry,
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
                  'Try again',
                  style: AppType.bodyStrong.copyWith(color: Tokens.beacon),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  /// Network trouble is expected here and styled as such — amber, not red.
  /// Treating an outage as a system failure would be the wrong tone in an app
  /// built for unreliable connectivity.
  Color get _colour => switch (failure) {
    NetworkFailure() => Tokens.brass,
    AuthFailure() => Tokens.beacon,
    _ => Tokens.ember,
  };

  IconData get _icon => switch (failure) {
    NetworkFailure() => Icons.cloud_off_outlined,
    AuthFailure() => Icons.lock_outline,
    PermissionFailure() => Icons.shield_outlined,
    DataFailure() => Icons.error_outline,
  };

  String get _headline => switch (failure) {
    NetworkFailure() => 'No connection',
    AuthFailure() => 'Sign in needed',
    PermissionFailure() => 'No access',
    DataFailure() => 'Could not load this',
  };
}
