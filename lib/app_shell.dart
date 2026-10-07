import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'data/project_repository.dart';
import 'models/squad.dart';
import 'routing/app_router.dart';
import 'routing/routes.dart';
import 'screens/dashboard_screen.dart';
import 'screens/home_screen.dart';
import 'screens/infrastructure_screen.dart';
import 'screens/signals_screen.dart';
import 'screens/squads_screen.dart';
import 'state/providers.dart';
import 'theme/tokens.dart';
import 'theme/typography.dart';
import 'widgets/offline_banner.dart';

class AppShell extends ConsumerStatefulWidget {
  const AppShell({super.key});

  @override
  ConsumerState<AppShell> createState() => _AppShellState();
}

class _AppShellState extends ConsumerState<AppShell> {
  /// 0 is Home. The data sections follow, in the order of [_sections].
  int _index = 0;

  /// Everything the user can open from Home. The navigation bar is built from
  /// this same list, so a section is named and iconed in exactly one place.
  static const _sections = [
    HomeDestination(
      title: 'Health',
      description:
          'How each project is doing, worst first, with the trend behind '
          'every score.',
      icon: Icons.monitor_heart_outlined,
      selectedIcon: Icons.monitor_heart,
    ),
    HomeDestination(
      title: 'Squads',
      description: 'Capacity and velocity for each squad.',
      icon: Icons.group_work_outlined,
      selectedIcon: Icons.group_work,
    ),
    HomeDestination(
      title: 'Signals',
      description: 'Early warnings, each with the reason it was raised.',
      icon: Icons.notifications_none,
      selectedIcon: Icons.notifications,
    ),
    HomeDestination(
      title: 'Grid',
      description: 'Load-shedding, and the hours it has taken from your week.',
      icon: Icons.bolt_outlined,
      selectedIcon: Icons.bolt,
    ),
  ];

  String get _title => _index == 0 ? 'Home' : _sections[_index - 1].title;

  /// The squad a project belongs to, or null if it is not in this snapshot.
  Squad? _squadFor(HealthSnapshot snapshot, String squadId) {
    for (final squad in snapshot.squads) {
      if (squad.id == squadId) return squad;
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(healthSnapshotProvider);
    // .value keeps the last good snapshot on screen through a transient error,
    // which is the behaviour an app built for flaky connectivity wants.
    final snapshot = async.value;
    final syncState = ref.watch(syncStateProvider).value;

    // Only the data tabs wait for a snapshot. Home needs none, so the app
    // opens straight onto it with or without a connection.
    Widget withData(Widget Function(HealthSnapshot snapshot) build) {
      if (snapshot != null) return build(snapshot);
      return async.hasError ? const _LoadError() : const _Loading();
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(_title),
        actions: [
          if (snapshot != null) _SyncBadge(snapshot: snapshot),
          IconButton(
            onPressed: () => Navigator.of(context).pushNamed(Routes.settings),
            icon: const Icon(Icons.settings_outlined),
            tooltip: 'Settings',
          ),
        ],
      ),
      body: Column(
        children: [
          // Hidden on Home, which shows no data and so cannot be stale.
          if (syncState != null && _index != 0)
            Padding(
              padding: const EdgeInsets.fromLTRB(
                Tokens.space4,
                Tokens.space2,
                Tokens.space4,
                0,
              ),
              child: OfflineBanner(syncState: syncState),
            ),
          Expanded(
            child: IndexedStack(
              index: _index,
              children: [
                HomeScreen(
                  destinations: _sections,
                  onOpen: (i) => setState(() => _index = i + 1),
                ),
                withData(
                  (s) => DashboardScreen(
                    snapshot: s,
                    // The dashboard does not know about routing; the shell
                    // owns navigation, so the screen stays testable on its own.
                    onOpenProject: (project) => Navigator.of(context).pushNamed(
                      Routes.projectDetail,
                      arguments: ProjectDetailArgs(
                        project: project,
                        squad: _squadFor(s, project.squadId),
                      ),
                    ),
                  ),
                ),
                withData((s) => SquadsScreen(snapshot: s)),
                withData((s) => SignalsScreen(snapshot: s)),
                withData((s) => InfrastructureScreen(snapshot: s)),
              ],
            ),
          ),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (i) => setState(() => _index = i),
        destinations: [
          const NavigationDestination(
            icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home),
            label: 'Home',
          ),
          for (final section in _sections)
            NavigationDestination(
              icon: Icon(section.icon),
              selectedIcon: Icon(section.selectedIcon),
              label: section.title,
            ),
        ],
      ),
    );
  }
}

class _Loading extends StatelessWidget {
  const _Loading();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: SizedBox(
        width: 20,
        height: 20,
        child: CircularProgressIndicator(strokeWidth: 2, color: Tokens.slate),
      ),
    );
  }
}

/// Shown on a data tab when the first snapshot fails to arrive. The stream
/// keeps running after an error, so this clears by itself once data flows.
class _LoadError extends StatelessWidget {
  const _LoadError();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(Tokens.space5),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.cloud_off_outlined, size: 24, color: Tokens.slate),
            const SizedBox(height: Tokens.space3),
            Text(
              'Your projects did not load',
              style: AppType.heading,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: Tokens.space2),
            Text(
              'Check your connection and that you are signed in to the right '
              'organisation. This screen updates by itself once data '
              'returns.',
              style: AppType.bodyMuted,
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

/// Connectivity is unreliable by assumption, so the app always states how
/// current the data on screen actually is.
class _SyncBadge extends StatelessWidget {
  const _SyncBadge({required this.snapshot});

  final HealthSnapshot snapshot;

  @override
  Widget build(BuildContext context) {
    final live = snapshot.isLive;
    final color = live ? Tokens.jade : Tokens.brass;

    return Semantics(
      label: live ? 'Data is live' : 'Showing cached data, not connected',
      excludeSemantics: true,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: Tokens.space2),
          Text(
            live ? 'Live' : 'Cached',
            style: AppType.label.copyWith(color: color, letterSpacing: 0.2),
          ),
        ],
      ),
    );
  }
}
