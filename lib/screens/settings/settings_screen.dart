import 'package:flutter/material.dart';

import '../../routing/routes.dart';
import '../../theme/tokens.dart';
import '../../theme/typography.dart';
import '../../widgets/panel.dart';

/// Account, data sources, and how the score is calculated.
class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(
          Tokens.space4,
          Tokens.space2,
          Tokens.space4,
          Tokens.space7,
        ),
        children: [
          Panel(
            title: 'Monitoring',
            padding: EdgeInsets.zero,
            child: Column(
              children: [
                _Row(
                  icon: Icons.tune,
                  title: 'Scoring weights',
                  subtitle: 'Change what your team is measured on',
                  onTap: () =>
                      Navigator.of(context).pushNamed(Routes.scoringWeights),
                ),
                const Divider(height: 1),
                _Row(
                  icon: Icons.link,
                  title: 'Connected sources',
                  subtitle: 'Repositories and trackers read automatically',
                  onTap: () =>
                      Navigator.of(context).pushNamed(Routes.ingestionSources),
                ),
              ],
            ),
          ),
          const SizedBox(height: Tokens.space4),
          Panel(
            title: 'What this app does not collect',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _PrivacyLine(
                  text:
                      'No individual developer is measured, ever. All '
                      'activity is aggregated to squad level before storage.',
                ),
                const SizedBox(height: Tokens.space3),
                _PrivacyLine(
                  text:
                      'Squads with too few contributors to be anonymous are '
                      'not reported at all.',
                ),
                const SizedBox(height: Tokens.space3),
                _PrivacyLine(
                  text: 'Code, commit messages and issue text are never read.',
                ),
                const SizedBox(height: Tokens.space3),
                _PrivacyLine(
                  text:
                      'Hours lost to load-shedding are reported but never '
                      'deducted from a health score.',
                ),
              ],
            ),
          ),
          const SizedBox(height: Tokens.space4),
          Panel(
            title: 'Account',
            padding: EdgeInsets.zero,
            child: _Row(
              icon: Icons.logout,
              title: 'Sign in',
              subtitle: 'Not signed in — running on demonstration data',
              onTap: () => Navigator.of(context).pushNamed(Routes.signIn),
            ),
          ),
        ],
      ),
    );
  }
}

class _Row extends StatelessWidget {
  const _Row({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.all(Tokens.space4),
        child: Row(
          children: [
            Icon(icon, size: 18, color: Tokens.slate),
            const SizedBox(width: Tokens.space3),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: AppType.bodyStrong),
                  const SizedBox(height: Tokens.space1),
                  Text(subtitle, style: AppType.bodyMuted),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, size: 18, color: Tokens.slate),
          ],
        ),
      ),
    );
  }
}

class _PrivacyLine extends StatelessWidget {
  const _PrivacyLine({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Icon(Icons.check, size: 15, color: Tokens.jade),
        const SizedBox(width: Tokens.space3),
        Expanded(child: Text(text, style: AppType.bodyMuted)),
      ],
    );
  }
}
