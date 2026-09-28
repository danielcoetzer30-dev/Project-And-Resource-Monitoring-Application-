import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'data/project_repository.dart';
import 'routing/routes.dart';
import 'screens/dashboard_screen.dart';
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
  int _index = 0;

  static const _titles = ['Health', 'Squads', 'Signals', 'Grid'];

  @override
  Widget build(BuildContext context) {
    // .value keeps the last good snapshot on screen through a transient error,
    // which is the behaviour an app built for flaky connectivity wants.
    final snapshot = ref.watch(healthSnapshotProvider).value;

    final syncState = ref.watch(syncStateProvider).value;

    return Scaffold(
      appBar: AppBar(
        title: Text(_titles[_index]),
        actions: [
          if (snapshot != null) _SyncBadge(snapshot: snapshot),
          IconButton(
            onPressed: () => Navigator.of(context).pushNamed(Routes.settings),
            icon: const Icon(Icons.settings_outlined),
            tooltip: 'Settings',
          ),
        ],
      ),
      body: snapshot == null
          ? const Center(
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Tokens.slate,
                ),
              ),
            )
          : Column(
              children: [
                if (syncState != null)
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
                      DashboardScreen(snapshot: snapshot),
                      SquadsScreen(snapshot: snapshot),
                      SignalsScreen(snapshot: snapshot),
                      InfrastructureScreen(snapshot: snapshot),
                    ],
                  ),
                ),
              ],
            ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (i) => setState(() => _index = i),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.monitor_heart_outlined),
            selectedIcon: Icon(Icons.monitor_heart),
            label: 'Health',
          ),
          NavigationDestination(
            icon: Icon(Icons.group_work_outlined),
            selectedIcon: Icon(Icons.group_work),
            label: 'Squads',
          ),
          NavigationDestination(
            icon: Icon(Icons.notifications_none),
            selectedIcon: Icon(Icons.notifications),
            label: 'Signals',
          ),
          NavigationDestination(
            icon: Icon(Icons.bolt_outlined),
            selectedIcon: Icon(Icons.bolt),
            label: 'Grid',
          ),
        ],
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
