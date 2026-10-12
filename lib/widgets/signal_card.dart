import 'package:flutter/material.dart';

import '../models/signal.dart';
import '../theme/tokens.dart';
import '../theme/typography.dart';
import 'status_pill.dart';

/// A signal with the reason it fired.
///
/// Shared by the Signals list and the top of a discussion, so the warning looks
/// the same wherever it is read. [onTap], when given, makes the card open its
/// discussion and adds the "Discuss" cue; without it the card is plain.
class SignalCard extends StatelessWidget {
  const SignalCard({
    super.key,
    required this.signal,
    required this.projectName,
    this.onTap,
  });

  final Signal signal;
  final String projectName;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Tokens.seam,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(Tokens.radiusMd),
        side: const BorderSide(color: Tokens.rule, width: Tokens.hairline),
      ),
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(Tokens.space4),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  StatusPill(state: signal.severity),
                  const SizedBox(width: Tokens.space3),
                  Expanded(
                    child: Text(
                      projectName,
                      style: AppType.data,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  Text(_ago(signal.raisedAt), style: AppType.data),
                ],
              ),
              const SizedBox(height: Tokens.space3),
              Text(signal.title, style: AppType.heading),
              const SizedBox(height: Tokens.space2),
              // Every signal shows its reasoning. An unexplained score is what
              // makes monitoring feel like surveillance rather than support.
              Text(signal.because, style: AppType.bodyMuted),
              if (signal.infrastructureRelated) ...[
                const SizedBox(height: Tokens.space3),
                Row(
                  children: [
                    const Icon(
                      Icons.bolt_outlined,
                      size: 14,
                      color: Tokens.brass,
                    ),
                    const SizedBox(width: Tokens.space2),
                    Expanded(
                      child: Text(
                        'Infrastructure, not delivery. No score was reduced.',
                        style: AppType.label.copyWith(
                          color: Tokens.brass,
                          letterSpacing: 0.2,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
              if (onTap != null) ...[
                const SizedBox(height: Tokens.space3),
                Row(
                  children: [
                    const Icon(
                      Icons.chat_bubble_outline,
                      size: 14,
                      color: Tokens.beacon,
                    ),
                    const SizedBox(width: Tokens.space2),
                    Text(
                      'Discuss',
                      style: AppType.label.copyWith(
                        color: Tokens.beacon,
                        letterSpacing: 0.2,
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  static String _ago(DateTime t) {
    final d = DateTime.now().difference(t);
    if (d.inMinutes < 60) return '${d.inMinutes}m ago';
    if (d.inHours < 24) return '${d.inHours}h ago';
    return '${d.inDays}d ago';
  }
}
