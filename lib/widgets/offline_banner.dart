import 'package:flutter/material.dart';

import '../models/sync_state.dart';
import '../theme/tokens.dart';
import '../theme/typography.dart';

/// Says how current the data on screen is.
///
/// Shown whenever the device is offline or the data has gone stale. The app is
/// built on the assumption that connectivity fails, so "is this number still
/// true?" is a question the interface has to answer without being asked.
class OfflineBanner extends StatelessWidget {
  const OfflineBanner({super.key, required this.syncState});

  final SyncState syncState;

  @override
  Widget build(BuildContext context) {
    final offline = !syncState.isOnline;
    final stale = syncState.isStale;

    // Nothing to say when connected and current.
    if (!offline && !stale) return const SizedBox.shrink();

    final colour = offline ? Tokens.brass : Tokens.slate;

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: Tokens.space3,
        vertical: Tokens.space2,
      ),
      decoration: BoxDecoration(
        color: colour.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(Tokens.radiusSm),
        border: Border.all(color: colour.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Icon(
            offline ? Icons.cloud_off_outlined : Icons.schedule_outlined,
            size: 15,
            color: colour,
          ),
          const SizedBox(width: Tokens.space2),
          Expanded(
            child: Text(
              _message,
              style: AppType.body.copyWith(color: colour, fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }

  String get _message {
    final synced = syncState.lastSyncedAt;

    if (synced == null) {
      return 'No data yet. Connect to load project health.';
    }

    final age = DateTime.now().difference(synced);
    final ago = _ago(age);

    return syncState.isOnline
        ? 'Showing data from $ago. Reconnecting.'
        : 'Offline. Showing saved data from $ago.';
  }

  static String _ago(Duration age) {
    if (age.inMinutes < 1) return 'just now';
    if (age.inMinutes < 60) return '${age.inMinutes} minutes ago';
    if (age.inHours < 24) {
      return '${age.inHours} ${age.inHours == 1 ? 'hour' : 'hours'} ago';
    }
    return '${age.inDays} ${age.inDays == 1 ? 'day' : 'days'} ago';
  }
}
