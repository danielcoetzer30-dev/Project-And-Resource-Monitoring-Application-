import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../state/providers.dart';
import '../../state/settings_notifier.dart';
import '../../theme/tokens.dart';
import '../../theme/typography.dart';
import '../../widgets/panel.dart';

/// Lets a team change what it is measured on.
///
/// The most important screen in settings, and arguably the most important
/// non-dashboard screen in the app. An opaque score is the thing that turns
/// monitoring into surveillance; a score whose inputs you can see, question
/// and adjust is a tool your team owns.
class ScoringWeightsScreen extends ConsumerWidget {
  const ScoringWeightsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final draft = ref.watch(settingsProvider);
    final notifier = ref.read(settingsProvider.notifier);
    final weights = draft.weights;

    return Scaffold(
      appBar: AppBar(title: const Text('Scoring weights')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(
          Tokens.space4,
          Tokens.space2,
          Tokens.space4,
          Tokens.space7,
        ),
        children: [
          Panel(
            title: 'How the score is made',
            child: Text(
              'Five indicators are combined into one health score. Change how '
              'much each one counts to match how your team actually works. '
              'The weights must add up to 100%.',
              style: AppType.bodyMuted,
            ),
          ),
          const SizedBox(height: Tokens.space4),
          _WeightSlider(
            label: 'Budget burn',
            help: 'Spend rate against schedule elapsed',
            value: weights.budgetBurn,
            onChanged: notifier.setBudgetBurn,
          ),
          _WeightSlider(
            label: 'Task velocity',
            help: 'Throughput against this squad\'s own baseline',
            value: weights.taskVelocity,
            onChanged: notifier.setTaskVelocity,
          ),
          _WeightSlider(
            label: 'Issue complexity ratio',
            help: 'Whether remaining work is getting heavier',
            value: weights.issueComplexity,
            onChanged: notifier.setIssueComplexity,
          ),
          _WeightSlider(
            label: 'Commit volume',
            help:
                'Commit activity against baseline. Easiest to game, so '
                'weighted lowest by default.',
            value: weights.commitVolume,
            onChanged: notifier.setCommitVolume,
          ),
          _WeightSlider(
            label: 'Idle-time ratio',
            help: 'Use of workable time, with outage hours excluded',
            value: weights.idleTime,
            onChanged: notifier.setIdleTime,
          ),
          const SizedBox(height: Tokens.space4),
          _TotalRow(draft: draft, onNormalise: notifier.normalise),
          const SizedBox(height: Tokens.space5),
          Row(
            children: [
              Expanded(
                child: TextButton(
                  onPressed: notifier.resetToDefaults,
                  child: Text(
                    'Reset to defaults',
                    style: AppType.body.copyWith(color: Tokens.slate),
                  ),
                ),
              ),
              const SizedBox(width: Tokens.space3),
              Expanded(
                child: FilledButton(
                  onPressed: draft.canSave ? notifier.markSaved : null,
                  style: FilledButton.styleFrom(
                    backgroundColor: Tokens.beacon,
                    foregroundColor: Tokens.shaft,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(Tokens.radiusSm),
                    ),
                    padding: const EdgeInsets.symmetric(
                      vertical: Tokens.space3,
                    ),
                  ),
                  child: Text(
                    'Save weights',
                    style: AppType.bodyStrong.copyWith(color: Tokens.shaft),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _WeightSlider extends StatelessWidget {
  const _WeightSlider({
    required this.label,
    required this.help,
    required this.value,
    required this.onChanged,
  });

  final String label;
  final String help;
  final double value;
  final void Function(double) onChanged;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: Tokens.space4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(child: Text(label, style: AppType.bodyStrong)),
              Text('${(value * 100).round()}%', style: AppType.dataStrong),
            ],
          ),
          const SizedBox(height: Tokens.space1),
          Text(help, style: AppType.bodyMuted),
          SliderTheme(
            data: SliderTheme.of(context).copyWith(
              activeTrackColor: Tokens.beacon,
              inactiveTrackColor: Tokens.rule,
              thumbColor: Tokens.beacon,
              overlayColor: Tokens.beacon.withValues(alpha: 0.15),
              trackHeight: 3,
            ),
            child: Slider(
              value: value.clamp(0.0, 1.0),
              max: 1,
              divisions: 20,
              onChanged: onChanged,
            ),
          ),
        ],
      ),
    );
  }
}

class _TotalRow extends StatelessWidget {
  const _TotalRow({required this.draft, required this.onNormalise});

  final WeightsDraft draft;
  final VoidCallback onNormalise;

  @override
  Widget build(BuildContext context) {
    final total = draft.weights.total;
    final valid = draft.weights.isValid;
    final colour = valid ? Tokens.jade : Tokens.brass;

    return Container(
      padding: const EdgeInsets.all(Tokens.space3),
      decoration: BoxDecoration(
        color: colour.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(Tokens.radiusSm),
        border: Border.all(color: colour.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Icon(
            valid ? Icons.check_circle_outline : Icons.info_outline,
            size: 16,
            color: colour,
          ),
          const SizedBox(width: Tokens.space2),
          Expanded(
            child: Text(
              valid
                  ? 'Weights add up to 100%'
                  : 'Weights add up to ${(total * 100).round()}%. They need to make 100%.',
              style: AppType.body.copyWith(color: colour),
            ),
          ),
          if (!valid)
            TextButton(
              onPressed: onNormalise,
              child: Text(
                'Fix',
                style: AppType.bodyStrong.copyWith(color: colour),
              ),
            ),
        ],
      ),
    );
  }
}
