import 'package:flutter/material.dart';

import '../../core/utils/duration_format.dart';
import '../../models/ingestion_source.dart';
import '../../routing/routes.dart';
import '../../theme/tokens.dart';
import '../../theme/typography.dart';
import '../../widgets/empty_state.dart';

/// Connected repositories and trackers, and when each last synced.
///
/// "Last synced" is the column that matters. A source that silently stopped
/// working three weeks ago is worse than no source, because the scores keep
/// rendering and nobody knows they are stale.
class IngestionSourcesScreen extends StatelessWidget {
  const IngestionSourcesScreen({super.key, this.sources = const []});

  final List<IngestionSource> sources;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Connected sources')),
      body: sources.isEmpty
          ? EmptyState(
              icon: Icons.link_off_outlined,
              headline: 'No sources connected',
              body:
                  'Connect a repository or issue tracker and the app starts '
                  'reading activity on its own. Nothing needs typing in.',
              actionLabel: 'Connect a source',
              onAction: () =>
                  Navigator.of(context).pushNamed(Routes.connectSource),
            )
          : ListView.separated(
              padding: const EdgeInsets.fromLTRB(
                Tokens.space4,
                Tokens.space2,
                Tokens.space4,
                Tokens.space7,
              ),
              itemCount: sources.length,
              separatorBuilder: (_, _) => const SizedBox(height: Tokens.space3),
              itemBuilder: (context, i) => _SourceRow(source: sources[i]),
            ),
      floatingActionButton: sources.isEmpty
          ? null
          : FloatingActionButton.extended(
              onPressed: () =>
                  Navigator.of(context).pushNamed(Routes.connectSource),
              backgroundColor: Tokens.beacon,
              foregroundColor: Tokens.shaft,
              icon: const Icon(Icons.add),
              label: const Text('Connect'),
            ),
    );
  }
}

class _SourceRow extends StatelessWidget {
  const _SourceRow({required this.source});

  final IngestionSource source;

  @override
  Widget build(BuildContext context) {
    final synced = source.lastSyncedAt;
    final stale =
        synced == null || DateTime.now().difference(synced).inHours > 24;

    return Container(
      padding: const EdgeInsets.all(Tokens.space4),
      decoration: BoxDecoration(
        color: Tokens.seam,
        borderRadius: BorderRadius.circular(Tokens.radiusMd),
        border: Border.all(color: Tokens.rule),
      ),
      child: Row(
        children: [
          Icon(
            source.type == SourceType.github || source.type == SourceType.gitlab
                ? Icons.code
                : Icons.task_alt,
            size: 18,
            color: source.isEnabled ? Tokens.beacon : Tokens.slate,
          ),
          const SizedBox(width: Tokens.space3),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(source.label, style: AppType.bodyStrong),
                const SizedBox(height: Tokens.space1),
                Text(
                  '${source.type.label} · ${source.remoteId}',
                  style: AppType.data,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          const SizedBox(width: Tokens.space3),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                source.isEnabled ? 'ON' : 'OFF',
                style: AppType.label.copyWith(
                  color: source.isEnabled ? Tokens.jade : Tokens.slate,
                ),
              ),
              const SizedBox(height: Tokens.space1),
              Text(
                synced == null
                    ? 'never synced'
                    : DurationFormatting.ago(synced),
                style: AppType.data.copyWith(
                  color: stale ? Tokens.brass : Tokens.slate,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
