import 'package:flutter/material.dart';

import 'data/project_repository.dart';
import 'screens/dashboard_screen.dart';
import 'screens/home_screen.dart';
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

  /// Subscribed once. Calling watch() inside build would ask the repository
  /// for the stream again on every tab change.
  late final Stream<HealthSnapshot> _stream = widget.repository.watch();

  String get _title => _index == 0 ? 'Home' : _sections[_index - 1].title;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<HealthSnapshot>(
      stream: _stream,
      builder: (context, asyncSnapshot) {
        final snapshot = asyncSnapshot.data;

        // Only the data tabs wait for a snapshot. Home needs none, so the app
        // opens straight onto it with or without a connection.
        Widget withData(Widget Function(HealthSnapshot snapshot) build) {
          if (snapshot != null) return build(snapshot);
          return asyncSnapshot.hasError ? const _LoadError() : const _Loading();
        }

        return Scaffold(
          appBar: AppBar(
            title: Text(_title),
            actions: [
              if (snapshot != null)
                Padding(
                  padding: const EdgeInsets.only(right: Tokens.space4),
                  child: _SyncBadge(snapshot: snapshot),
                ),
            ],
          ),
          body: IndexedStack(
            index: _index,
            children: [
              HomeScreen(
                destinations: _sections,
                onOpen: (i) => setState(() => _index = i + 1),
              ),
              withData((s) => DashboardScreen(snapshot: s)),
              withData((s) => SquadsScreen(snapshot: s)),
              withData((s) => SignalsScreen(snapshot: s)),
              withData((s) => InfrastructureScreen(snapshot: s)),
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
      },
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
