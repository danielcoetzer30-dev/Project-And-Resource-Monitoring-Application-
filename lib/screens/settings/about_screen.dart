import 'package:flutter/material.dart';

import '../../models/health_state.dart';
import '../../theme/tokens.dart';
import '../../theme/typography.dart';
import '../../widgets/panel.dart';
import '../../widgets/status_pill.dart';

/// What the app is, how to read it, and what it does and does not do with
/// people's data. Static text: nothing here is stored or fetched.
class AboutScreen extends StatelessWidget {
  const AboutScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('About and help')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(
          Tokens.space4,
          Tokens.space2,
          Tokens.space4,
          Tokens.space7,
        ),
        children: [
          Panel(
            title: 'Keel',
            child: Text(
              'Keel watches the health of your projects and the capacity of '
              'your squads in real time, and warns you early when something '
              'is drifting. It reads from the tools your squads already use, '
              'so nobody has to type in progress.',
              style: AppType.body,
            ),
          ),
          const SizedBox(height: Tokens.space4),
          Panel(
            title: 'How scores work',
            child: Text(
              'Each project gets a score out of 100, built from several '
              'factors that are each scored and weighted. Open any project to '
              'see every factor, its weight and the reason behind it. A score '
              'on its own is a snapshot, so the health history beside it '
              'shows how the project got there.',
              style: AppType.body,
            ),
          ),
          const SizedBox(height: Tokens.space4),
          Panel(
            title: 'What the colours mean',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                  spacing: Tokens.space2,
                  runSpacing: Tokens.space2,
                  children: [
                    for (final state in HealthState.values.reversed)
                      StatusPill(state: state),
                  ],
                ),
                const SizedBox(height: Tokens.space3),
                Text(
                  'Colour is never the only signal. Every state also has an '
                  'icon and a word, so it reads the same without colour.',
                  style: AppType.bodyMuted,
                ),
              ],
            ),
          ),
          const SizedBox(height: Tokens.space4),
          Panel(
            title: 'People and outages',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Capacity is aggregated per squad. Individual activity is '
                  'never stored, scored or shown.',
                  style: AppType.body,
                ),
                const SizedBox(height: Tokens.space3),
                Text(
                  'Load-shedding hours are reported but never deducted. A '
                  'score measures delivery, not the grid.',
                  style: AppType.body,
                ),
              ],
            ),
          ),
          const SizedBox(height: Tokens.space4),
          Panel(
            padding: EdgeInsets.zero,
            child: ListTile(
              leading: const Icon(Icons.description_outlined, size: 18),
              title: Text('Open source licences', style: AppType.bodyStrong),
              trailing: const Icon(Icons.chevron_right, size: 18),
              onTap: () =>
                  showLicensePage(context: context, applicationName: 'Keel'),
            ),
          ),
        ],
      ),
    );
  }
}
