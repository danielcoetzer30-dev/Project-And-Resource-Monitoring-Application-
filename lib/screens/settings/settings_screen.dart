import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../routing/routes.dart';
import '../../state/auth_notifier.dart';
import '../../state/providers.dart';
import '../../theme/density.dart';
import '../../theme/tokens.dart';
import '../../theme/typography.dart';
import '../../widgets/panel.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(currentUserProvider);
    final canChangeSettings = ref.watch(canChangeSettingsProvider);

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
                  subtitle: canChangeSettings
                      ? 'Change what your team is measured on'
                      : 'View scoring weight configuration (Read-only)',
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
                const Divider(height: 1),
                _Row(
                  icon: Icons.key_outlined,
                  title: 'Assistant API key',
                  subtitle: 'Your own key, kept on this device',
                  onTap: () => Navigator.of(context).pushNamed(Routes.apiKey),
                ),
              ],
            ),
          ),
          const SizedBox(height: Tokens.space4),
          // Everything in here is this device's business only, which is why it
          // sits apart from Monitoring above.
          Panel(
            title: 'Preferences',
            padding: EdgeInsets.zero,
            child: Column(
              children: [
                _Row(
                  icon: Icons.dashboard_customize_outlined,
                  title: 'Customisations',
                  subtitle: 'Formats, density, start screen, dashboard',
                  onTap: () =>
                      Navigator.of(context).pushNamed(Routes.customisations),
                ),
                const Divider(height: 1),
                _Row(
                  icon: Icons.accessibility_new_outlined,
                  title: 'Accessibility',
                  subtitle: 'Text size, bold text',
                  onTap: () =>
                      Navigator.of(context).pushNamed(Routes.accessibility),
                ),
                const Divider(height: 1),
                _Row(
                  icon: Icons.info_outline,
                  title: 'About and help',
                  subtitle: 'How scores work, what the colours mean',
                  onTap: () => Navigator.of(context).pushNamed(Routes.about),
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
                const SizedBox(height: Tokens.space3),
                _PrivacyLine(
                  text:
                      'Your role decides what you can change, never what can '
                      'be seen about you.',
                ),
              ],
            ),
          ),
          const SizedBox(height: Tokens.space4),
          // Names the signed-in person and their role, so it is obvious why a
          // setting above is or is not editable.
          Panel(
            title: 'Account',
            padding: EdgeInsets.zero,
            child: user != null
                ? Column(
                    children: [
                      _Row(
                        icon: Icons.person_outline,
                        title: user.displayName.isNotEmpty
                            ? user.displayName
                            : user.email,
                        subtitle: '${user.role.label} in ${user.orgId}',
                        onTap: null,
                      ),
                      const Divider(height: 1),
                      _Row(
                        icon: Icons.logout,
                        title: 'Sign out',
                        subtitle: 'You will need your password to come back',
                        onTap: () =>
                            ref.read(authNotifierProvider.notifier).signOut(),
                      ),
                    ],
                  )
                : _Row(
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

  /// Null for a row that only states something, so it does not look tappable.
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: EdgeInsets.all(context.dense(Tokens.space4)),
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
            if (onTap != null)
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
