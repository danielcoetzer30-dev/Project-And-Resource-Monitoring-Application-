import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../state/auth_notifier.dart';
import '../../state/providers.dart';
import '../../state/settings_notifier.dart';
import '../../theme/tokens.dart';
import '../../theme/typography.dart';
import '../../widgets/panel.dart';

class ScoringWeightsScreen extends ConsumerWidget {
  const ScoringWeightsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final draft = ref.watch(settingsProvider);
    final notifier = ref.read(settingsProvider.notifier);
    final weights = draft.weights;

    final canEdit = ref.watch(canChangeSettingsProvider);

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
              canEdit
                  ? 'Five indicators are combined into one health score. Change how much each one counts to match how your team actually works.'
                  : 'Five indicators are combined into one health score. Only Leads and Managers can modify scoring weights.',
              style: AppType.bodyMuted,
            ),
          ),
          const SizedBox(height: Tokens.space4),
          _WeightSlider(
            label: 'Budget burn',
            help: 'Spend rate against schedule elapsed',
            value: weights.budgetBurn,
            onChanged: canEdit ? notifier.setBudgetBurn : null,
          ),
          _WeightSlider(
            label: 'Task velocity',
            help: 'Throughput against baseline',
            value: weights.taskVelocity,
            onChanged: canEdit ? notifier.setTaskVelocity : null,
          ),
          _WeightSlider(
            label: 'Issue complexity ratio',
            help: 'Backlog weight distribution',
            value: weights.issueComplexity,
            onChanged: canEdit ? notifier.setIssueComplexity : null,
          ),
          _WeightSlider(
            label: 'Commit volume',
            help: 'Code activity across the codebase',
            value: weights.commitVolume,
            onChanged: canEdit ? notifier.setCommitVolume : null,
          ),
          _WeightSlider(
            label: 'Idle-time ratio',
            help: 'Time lost excluding outages',
            value: weights.idleTime,
            onChanged: canEdit ? notifier.setIdleTime : null,
          ),
          const SizedBox(height: Tokens.space3),
          _TotalRow(draft: draft, onNormalise: notifier.normalise),
          const SizedBox(height: Tokens.space5),
          Row(
            children: [
              Expanded(
                child: TextButton(
                  onPressed: canEdit ? notifier.resetToDefaults : null,
                  child: Text(
                    'Reset to defaults',
                    style: AppType.body.copyWith(color: Tokens.slate),
                  ),
                ),
              ),
              const SizedBox(width: Tokens.space3),
              Expanded(
                child: FilledButton(
                  onPressed: (canEdit && draft.canSave)
                      ? notifier.markSaved
                      : null,
                  style: FilledButton.styleFrom(
                    backgroundColor: Tokens.beacon,
                    foregroundColor: Tokens.shaft,
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
  final ValueChanged<double>? onChanged;

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
