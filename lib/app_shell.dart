import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'data/project_repository.dart';
import 'models/preferences.dart';
import 'models/squad.dart';
import 'routing/app_router.dart';
import 'routing/routes.dart';
import 'screens/assistant_screen.dart';
import 'screens/dashboard_screen.dart';
import 'screens/home_screen.dart';
import 'screens/signals_screen.dart';
import 'screens/squads_screen.dart';
import 'screens/week_screen.dart';
import 'state/auth_notifier.dart';
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

  @override
  void initState() {
    super.initState();
    _openOnStartTab();
  }

  /// Opens on the tab the person chose under Customisations.
  ///
  /// Saved preferences arrive a moment after launch, so this reads the store
  /// directly rather than waiting on the provider, and gives up if they have
  /// already tapped somewhere in the meantime — moving the screen out from
  /// under somebody is worse than ignoring their preference once.
  Future<void> _openOnStartTab() async {
    final saved = await ref.read(preferencesStoreProvider).load();
    if (!mounted || _index != 0 || saved.startTab == StartTab.home) return;
    setState(() => _index = saved.startTab.index);
  }

  /// Everything the user can open from Home. The navigation bar is built from
  /// this same list, so a section is named and iconed in exactly one place.
  ///
  /// Each title names what the tab is for rather than what it is about.
  /// "Health" and "Week" were both renamed on 21 October 2026, because
  /// neither said what you would find: one is the project list and now also
  /// where projects are set up, the other is the week laid out against the
  /// hours load-shedding took. "Signals" stayed — it is the deliberate word,
  /// milder than an alert and stronger than a note, and the copy voice in
  /// `docs/DESIGN.md` rests on it.
  ///
  /// [StartTab] in `lib/models/preferences.dart` is indexed straight into
  /// this list, so its labels have to match these titles. Its enum *names*
  /// are what gets stored on the device and must not be renamed, or every
  /// saved start-tab preference stops resolving.
  static const _sections = [
    HomeDestination(
      title: 'Projects',
      description:
          'How each project is doing, worst first, and where you set one up.',
      icon: Icons.inventory_2_outlined,
      selectedIcon: Icons.inventory_2,
    ),
    HomeDestination(
      title: 'Capacity',
      description:
          'What each squad has committed against the hours it has, and who '
          'is on it.',
      icon: Icons.group_work_outlined,
      selectedIcon: Icons.group_work,
    ),
    HomeDestination(
      title: 'Signals',
      description:
          'Early warnings, each with the reason it was raised and a place '
          'to discuss it.',
      icon: Icons.notifications_none,
      selectedIcon: Icons.notifications,
    ),
    HomeDestination(
      title: 'Schedule',
      description:
          'What is scheduled this week, and what load-shedding has taken '
          'from it so far.',
      icon: Icons.calendar_month_outlined,
      selectedIcon: Icons.calendar_month,
    ),
    HomeDestination(
      title: 'Ask',
      description: 'Questions about your projects, answered from this data.',
      icon: Icons.forum_outlined,
      selectedIcon: Icons.forum,
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

    // Drives the role chip. Null when signed out, which is the normal state
    // while the mock repository is in use.
    final user = ref.watch(currentUserProvider);

    // Dates and times are formatted through static helpers rather than off the
    // context, so nothing here depends on them. Watched anyway, so changing a
    // format repaints the tabs instead of waiting for the next rebuild.
    ref.watch(preferencesProvider);

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
          // Shows the signed-in person their own role, so it is obvious why a
          // setting is or is not editable. It is never anybody else's.
          if (user != null) ...[
            const SizedBox(width: Tokens.space2),
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: Tokens.space2,
                vertical: Tokens.space1,
              ),
              decoration: BoxDecoration(
                color: Tokens.shaft,
                borderRadius: BorderRadius.circular(Tokens.radiusSm),
                border: Border.all(color: Tokens.rule, width: Tokens.hairline),
              ),
              child: Text(
                user.role.label.toUpperCase(),
                style: AppType.label.copyWith(
                  fontSize: 10,
                  color: Tokens.slate,
                ),
              ),
            ),
          ],
          // Messaging is reached from here rather than from a tab: the six
          // sections are what the app measures, and a conversation is not a
          // measurement.
          if (user != null)
            IconButton(
              onPressed: () => Navigator.of(context).pushNamed(Routes.messages),
              icon: const Icon(Icons.chat_bubble_outline),
              tooltip: 'Messages',
            ),
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
                    // Project setup lives on this tab rather than in
                    // Settings: a project is the thing the tab is about, and
                    // somebody looking at a project that is missing a budget
                    // should not have to go looking in a different part of
                    // the app to add one.
                    onManageProjects: () =>
                        Navigator.of(context).pushNamed(Routes.projects),
                  ),
                ),
                withData((s) => SquadsScreen(snapshot: s)),
                withData(
                  (s) => SignalsScreen(
                    snapshot: s,
                    // Same split as the dashboard: the screen raises the
                    // intent, the shell owns the route.
                    onOpenSignal: (signal, projectName) =>
                        Navigator.of(context).pushNamed(
                          Routes.signalThread,
                          arguments: SignalThreadArgs(
                            signal: signal,
                            projectName: projectName,
                          ),
                        ),
                  ),
                ),
                withData((s) => WeekScreen(snapshot: s)),
                // Not wrapped in withData: the assistant reads the snapshot
                // itself when a question is asked, and says so plainly if
                // there is nothing loaded yet.
                const AssistantScreen(),
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
