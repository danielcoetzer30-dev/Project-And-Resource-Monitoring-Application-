import 'package:flutter/material.dart';

import '../models/health_state.dart';
import '../theme/tokens.dart';
import '../theme/typography.dart';

/// Colour, icon and word together — the only sanctioned way to render a state.
///
/// Using this everywhere is what guarantees the app never leans on hue alone.
class StatusPill extends StatelessWidget {
  const StatusPill({super.key, required this.state, this.compact = false});

  final HealthState state;

  /// Drops the word, keeping colour and icon. For dense rows where the label
  /// appears adjacent anyway.
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final content = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(state.icon, size: compact ? 14 : 15, color: state.color),
        if (!compact) ...[
          const SizedBox(width: Tokens.space2),
          Text(
            state.label,
            style: AppType.label.copyWith(
              color: state.color,
              letterSpacing: 0.4,
            ),
          ),
        ],
      ],
    );

    return Semantics(
      label: 'Status: ${state.label}',
      excludeSemantics: true,
      child: Container(
        padding: EdgeInsets.symmetric(
          horizontal: compact ? Tokens.space1 : Tokens.space2,
          vertical: Tokens.space1,
        ),
        decoration: BoxDecoration(
          color: state.color.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(Tokens.radiusSm),
          border: Border.all(color: state.color.withValues(alpha: 0.35)),
        ),
        child: content,
      ),
    );
  }
}
