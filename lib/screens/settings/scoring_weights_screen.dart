import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/errors/failure.dart';
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
                  ? 'Five indicators combine into one health score. Change how '
                        'much each one counts to match how your team actually '
                        'works.'
                  : 'Five indicators combine into one health score. Every '
                        'member can see the weights; leads and managers '
                        'change them.',
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
          _TotalRow(
            draft: draft,
            onNormalise: canEdit ? notifier.normalise : null,
          ),
          if (draft.failure != null) ...[
            const SizedBox(height: Tokens.space4),
            _SaveFailure(failure: draft.failure!),
          ],
          const SizedBox(height: Tokens.space5),
          Row(
            children: [
              Expanded(
                child: TextButton(
                  onPressed: canEdit && !draft.isSaving
                      ? notifier.resetToDefaults
                      : null,
                  child: Text(
                    'Reset to defaults',
                    style: AppType.body.copyWith(color: Tokens.slate),
                  ),
                ),
              ),
              const SizedBox(width: Tokens.space3),
              Expanded(
                child: FilledButton(
                  onPressed: (canEdit && draft.canSave) ? notifier.save : null,
                  style: FilledButton.styleFrom(
                    backgroundColor: Tokens.beacon,
                    foregroundColor: Tokens.shaft,
                  ),
                  child: Text(
                    draft.isSaving ? 'Saving…' : 'Save weights',
                    style: AppType.bodyStrong.copyWith(color: Tokens.shaft),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: Tokens.space4),
          Text(
            'Weights are saved for the whole organisation, so everyone is '
            'measured the same way and can see how.',
            style: AppType.bodyMuted,
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

/// Why a save was refused. Sits directly above the button that was pressed,
/// so the reason and the control are in the same glance.
class _SaveFailure extends StatelessWidget {
  const _SaveFailure({required this.failure});

  final Failure failure;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(Tokens.space3),
      decoration: BoxDecoration(
        color: Tokens.flare.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(Tokens.radiusSm),
        border: Border.all(color: Tokens.flare.withValues(alpha: 0.3)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.error_outline, size: 16, color: Tokens.flare),
          const SizedBox(width: Tokens.space2),
          Expanded(
            child: Text(
              failure.message,
              style: AppType.body.copyWith(color: Tokens.flare),
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

  /// Null for a read-only viewer, so the "Fix" shortcut is not offered to
  /// somebody who cannot save the result.
  final VoidCallback? onNormalise;

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
          if (!valid && onNormalise != null)
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
