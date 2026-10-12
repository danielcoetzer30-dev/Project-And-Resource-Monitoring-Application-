import 'package:flutter/material.dart';

import '../data/project_repository.dart';
import '../models/signal.dart';
import '../theme/tokens.dart';
import '../theme/typography.dart';
import '../widgets/signal_card.dart';

class SignalsScreen extends StatelessWidget {
  const SignalsScreen({super.key, required this.snapshot, this.onOpenSignal});

  final HealthSnapshot snapshot;

  /// Opens the discussion for a signal. The screen does not know about
  /// routing; the shell owns navigation, so this stays testable on its own.
  /// When null the cards are plain and do not invite a tap.
  final void Function(Signal signal, String projectName)? onOpenSignal;

  @override
  Widget build(BuildContext context) {
    final signals = [...snapshot.signals]
      ..sort((a, b) => b.severity.severity.compareTo(a.severity.severity));

    if (signals.isEmpty) {
      return _Empty();
    }

    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(
        Tokens.space4,
        Tokens.space2,
        Tokens.space4,
        Tokens.space7,
      ),
      itemCount: signals.length,
      separatorBuilder: (_, _) => const SizedBox(height: Tokens.space3),
      itemBuilder: (context, i) {
        final signal = signals[i];
        final projectName = _projectName(signal.projectId);
        final open = onOpenSignal;

        return SignalCard(
          signal: signal,
          projectName: projectName,
          onTap: open == null ? null : () => open(signal, projectName),
        );
      },
    );
  }

  String _projectName(String id) => snapshot.projects
      .firstWhere((p) => p.id == id, orElse: () => snapshot.projects.first)
      .name;
}

class _Empty extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(Tokens.space6),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.check_circle_outline,
              size: 32,
              color: Tokens.jade,
            ),
            const SizedBox(height: Tokens.space3),
            Text(
              'Nothing is trending toward failure',
              style: AppType.heading,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: Tokens.space2),
            Text(
              'Signals appear here as soon as a project starts drifting.',
              style: AppType.bodyMuted,
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
