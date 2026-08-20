import 'package:flutter/material.dart';

import '../data/project_repository.dart';
import '../models/signal.dart';
import '../theme/tokens.dart';
import '../theme/typography.dart';
import '../widgets/status_pill.dart';

class SignalsScreen extends StatelessWidget {
  const SignalsScreen({super.key, required this.snapshot});

  final HealthSnapshot snapshot;

  @override
  Widget build(BuildContext context) {
    final signals = [...snapshot.signals]..sort(
        (a, b) => b.severity.severity.compareTo(a.severity.severity),
      );

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
      itemBuilder: (context, i) => _SignalCard(
        signal: signals[i],
        projectName: _projectName(signals[i].projectId),
      ),
    );
  }

  String _projectName(String id) => snapshot.projects
      .firstWhere(
        (p) => p.id == id,
        orElse: () => snapshot.projects.first,
      )
      .name;
}

class _SignalCard extends StatelessWidget {
  const _SignalCard({required this.signal, required this.projectName});

  final Signal signal;
  final String projectName;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(Tokens.space4),
      decoration: BoxDecoration(
        color: Tokens.seam,
        borderRadius: BorderRadius.circular(Tokens.radiusMd),
        border: Border.all(color: Tokens.rule, width: Tokens.hairline),
      ),
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
                const Icon(Icons.bolt_outlined, size: 14, color: Tokens.brass),
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
        ],
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

class _Empty extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(Tokens.space6),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.check_circle_outline,
                size: 32, color: Tokens.jade),
            const SizedBox(height: Tokens.space3),
            Text('Nothing is trending toward failure',
                style: AppType.heading, textAlign: TextAlign.center),
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
