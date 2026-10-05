import 'package:flutter/material.dart';

import '../../../models/signal.dart';
import '../../../theme/tokens.dart';
import '../../../theme/typography.dart';
import '../panel.dart';
import '../status_pill.dart';
import 'dashboard_format.dart';

/// The latest signals, each with the reasoning that raised it.
///
/// `because` is always rendered. An unexplained warning is what makes
/// monitoring feel like surveillance, so there is no compact mode that drops it.
class SignalsPanel extends StatelessWidget {
  const SignalsPanel({
    super.key,
    required this.signals,
    required this.projectNames,
    this.limit = 5,
  });

  /// Newest first, as the repository delivers them.
  final List<Signal> signals;

  /// Project id to display name.
  final Map<String, String> projectNames;

  final int limit;

  @override
  Widget build(BuildContext context) {
    final shown = signals.take(limit).toList();

    return Panel(
      title: 'Latest signals',
      child: shown.isEmpty
          ? Text(
              'No signals right now. When something needs attention, it '
              'appears here with the reason.',
              style: AppType.bodyMuted,
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (var i = 0; i < shown.length; i++) ...[
                  if (i > 0)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: Tokens.space3),
                      child: Divider(height: Tokens.hairline),
                    ),
                  _SignalTile(
                    signal: shown[i],
                    projectName: projectNames[shown[i].projectId],
                  ),
                ],
              ],
            ),
    );
  }
}

class _SignalTile extends StatelessWidget {
  const _SignalTile({required this.signal, required this.projectName});

  final Signal signal;
  final String? projectName;

  @override
  Widget build(BuildContext context) {
    final meta = [?projectName, agoLabel(signal.raisedAt)].join(' · ');

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: Tokens.space2,
          runSpacing: Tokens.space2,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            StatusPill(state: signal.severity),
            if (signal.infrastructureRelated) const _InfrastructureTag(),
          ],
        ),
        const SizedBox(height: Tokens.space2),
        Text(signal.title, style: AppType.bodyStrong),
        const SizedBox(height: Tokens.space1),
        Text(signal.because, style: AppType.bodyMuted),
        const SizedBox(height: Tokens.space2),
        Text(meta, style: AppType.data),
      ],
    );
  }
}

/// Marks a signal as grid or connectivity rather than delivery.
///
/// Neutral on purpose: it is a category, not a health state, so it takes none
/// of the signal ramp.
class _InfrastructureTag extends StatelessWidget {
  const _InfrastructureTag();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: Tokens.space2,
        vertical: Tokens.space1,
      ),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(Tokens.radiusSm),
        border: Border.all(color: Tokens.rule, width: Tokens.hairline),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.bolt_outlined, size: 14, color: Tokens.slate),
          const SizedBox(width: Tokens.space1),
          Text('Grid, not delivery', style: AppType.label),
        ],
      ),
    );
  }
}
