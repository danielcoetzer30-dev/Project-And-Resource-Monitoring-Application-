import 'package:flutter/material.dart';

import 'data/project_repository.dart';
import 'screens/dashboard_screen.dart';
import 'screens/infrastructure_screen.dart';
import 'screens/signals_screen.dart';
import 'screens/squads_screen.dart';
import 'theme/tokens.dart';
import 'theme/typography.dart';

class AppShell extends StatefulWidget {
  const AppShell({super.key, required this.repository});

  final ProjectRepository repository;

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  int _index = 0;

  static const _titles = ['Health', 'Squads', 'Signals', 'Grid'];

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<HealthSnapshot>(
      stream: widget.repository.watch(),
      builder: (context, asyncSnapshot) {
        final snapshot = asyncSnapshot.data;

        return Scaffold(
          appBar: AppBar(
            title: Text(_titles[_index]),
            actions: [
              if (snapshot != null)
                Padding(
                  padding: const EdgeInsets.only(right: Tokens.space4),
                  child: _SyncBadge(snapshot: snapshot),
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
              : IndexedStack(
                  index: _index,
                  children: [
                    DashboardScreen(snapshot: snapshot),
                    SquadsScreen(snapshot: snapshot),
                    SignalsScreen(snapshot: snapshot),
                    InfrastructureScreen(snapshot: snapshot),
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
      },
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
