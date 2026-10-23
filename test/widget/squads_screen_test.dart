import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:prahm/data/mock_messaging_repository.dart';
import 'package:prahm/data/mock_squad_roster_repository.dart';
import 'package:prahm/data/project_repository.dart';
import 'package:prahm/models/app_user.dart';
import 'package:prahm/models/directory_entry.dart';
import 'package:prahm/models/squad.dart';
import 'package:prahm/models/squad_member.dart';
import 'package:prahm/screens/squads_screen.dart';
import 'package:prahm/state/providers.dart';
import 'package:prahm/theme/app_theme.dart';

import '../support/fake_auth_repository.dart';

/// The Capacity tab: squad totals, and the roster beneath each one.
///
/// The roster is the part worth testing hard. It is a privacy position the
/// team reversed deliberately, and what has to keep
/// holding is that the move control follows rank, that a refusal is said out
/// loud, and that no figure ever appears against a person.
///
/// The snapshot is built here rather than taken from MockProjectRepository:
/// that one drifts its numbers on a periodic timer, which is right for a
/// demonstration and wrong for a test that should assert on fixed figures.
void main() {
  const squads = [
    Squad(
      id: 's1',
      name: 'Platform squad',
      headcount: 2,
      capacityUsed: 1.28,
      activeProjectCount: 2,
      velocityTrend: -0.31,
    ),
    Squad(
      id: 's2',
      name: 'Mobile squad',
      headcount: 1,
      capacityUsed: 0.78,
      activeProjectCount: 1,
      velocityTrend: 0.04,
    ),
  ];

  final snapshot = HealthSnapshot(
    projects: const [],
    squads: squads,
    signals: const [],
    grid: const GridStatus(
      stage: 0,
      nextOutageStart: null,
      nextOutageEnd: null,
      hoursLostThisWeek: 0,
    ),
    capturedAt: DateTime.utc(2026, 10, 21, 9),
    isLive: true,
  );

  const directory = [
    DirectoryEntry(
      id: 'mgr',
      displayName: 'Thandi Mokoena',
      role: UserRole.manager,
    ),
    DirectoryEntry(
      id: 'lead',
      displayName: 'Sipho Dlamini',
      role: UserRole.lead,
    ),
    DirectoryEntry(
      id: 'dev',
      displayName: 'Ada Pillay',
      role: UserRole.developer,
    ),
    DirectoryEntry(
      id: 'dev2',
      displayName: 'Johan Smit',
      role: UserRole.developer,
    ),
  ];

  const placements = [
    SquadPlacement(userId: 'dev', squadId: 's1'),
    SquadPlacement(userId: 'lead', squadId: 's1'),
    SquadPlacement(userId: 'mgr', squadId: 's2'),
    // dev2 is deliberately unplaced.
  ];

  const manager = AppUser(
    id: 'mgr',
    email: 'mgr@example.com',
    displayName: 'Thandi Mokoena',
    orgId: 'demo-org',
    role: UserRole.manager,
  );

  const lead = AppUser(
    id: 'lead',
    email: 'lead@example.com',
    displayName: 'Sipho Dlamini',
    orgId: 'demo-org',
    role: UserRole.lead,
  );

  const developer = AppUser(
    id: 'dev',
    email: 'dev@example.com',
    displayName: 'Ada Pillay',
    orgId: 'demo-org',
    role: UserRole.developer,
  );

  /// The Capacity tab with the snapshot handed in, the way the shell hands it
  /// one, and the directory and roster behind mocks.
  /// [displayedAs] is what the screen draws its rows from, and [writesAgainst]
  /// is what the repository checks a move against. They are separate because
  /// the interesting refusal is exactly when they diverge: a role that changed
  /// after the row was drawn.
  Future<MockSquadRosterRepository> pumpScreen(
    WidgetTester tester, {
    required AppUser signedInAs,
    List<DirectoryEntry> displayedAs = directory,
    List<DirectoryEntry>? writesAgainst,
    List<SquadPlacement> initial = placements,
  }) async {
    final roster = MockSquadRosterRepository(
      author: signedInAs,
      directory: writesAgainst ?? displayedAs,
      initial: initial,
    );
    addTearDown(roster.dispose);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authRepositoryProvider.overrideWithValue(
            FakeAuthRepository(user: signedInAs),
          ),
          squadRosterRepositoryProvider.overrideWithValue(roster),
          messagingRepositoryProvider.overrideWithValue(
            MockMessagingRepository(user: signedInAs, directory: displayedAs),
          ),
        ],
        child: MaterialApp(
          theme: AppTheme.dark,
          home: Scaffold(body: SquadsScreen(snapshot: snapshot)),
        ),
      ),
    );
    await tester.pumpAndSettle();

    return roster;
  }

  testWidgets('shows each squad with the people on it', (tester) async {
    await pumpScreen(tester, signedInAs: manager);

    expect(find.text('Platform squad'), findsOneWidget);
    expect(find.text('Ada Pillay'), findsOneWidget);
    expect(find.text('Sipho Dlamini'), findsOneWidget);
    expect(find.text('ON THIS SQUAD'), findsNWidgets(2));
  });

  testWidgets('lists the people on no squad rather than hiding them', (
    tester,
  ) async {
    await pumpScreen(tester, signedInAs: manager);

    await tester.scrollUntilVisible(
      find.text('ON NO SQUAD'),
      300,
      scrollable: find.byType(Scrollable).first,
    );

    expect(find.text('Johan Smit'), findsOneWidget);
  });

  testWidgets('still says no activity is stored against a person', (
    tester,
  ) async {
    // The screen gained names; it must not have lost the statement about what
    // it does not measure, which is the whole reason the roster is only a
    // roster.
    await pumpScreen(tester, signedInAs: manager);

    expect(
      find.textContaining('No activity is stored, scored or shown against'),
      findsOneWidget,
    );
  });

  testWidgets('says so when the roster and the stated headcount disagree', (
    tester,
  ) async {
    // Mobile squad states one person and has the manager placed on it, which
    // agrees. Platform states two and has two, which also agrees, so moving
    // one away has to produce the warning rather than a silent reconcile.
    final roster = await pumpScreen(tester, signedInAs: manager);

    await roster.place(userId: 'dev', squadId: 's2');
    await tester.pumpAndSettle();

    expect(find.textContaining('The stated headcount is'), findsWidgets);
  });

  testWidgets('a developer gets no move control at all', (tester) async {
    await pumpScreen(tester, signedInAs: developer);

    expect(find.byIcon(Icons.swap_horiz), findsNothing);
  });

  testWidgets('a lead can move a developer but not a lead or a manager', (
    tester,
  ) async {
    await pumpScreen(tester, signedInAs: lead);

    expect(find.byTooltip('Move Ada Pillay to another squad'), findsOneWidget);
    expect(find.byTooltip('Move Sipho Dlamini to another squad'), findsNothing);
    expect(
      find.byTooltip('Move Thandi Mokoena to another squad'),
      findsNothing,
    );
  });

  testWidgets('a manager moves somebody to another squad', (tester) async {
    final roster = await pumpScreen(tester, signedInAs: manager);

    await tester.tap(find.byTooltip('Move Ada Pillay to another squad'));
    await tester.pumpAndSettle();

    expect(find.text('Move Ada Pillay'), findsOneWidget);
    // Marked so a tap that changes nothing is obvious before it is made.
    expect(find.text('ON NOW'), findsOneWidget);

    await tester.tap(find.text('Mobile squad').last);
    await tester.pumpAndSettle();

    expect(roster.squadOf('dev'), 's2');
    expect(
      find.textContaining('Ada Pillay is now on Mobile squad'),
      findsOneWidget,
    );
  });

  testWidgets('taking somebody off every squad keeps the placement', (
    tester,
  ) async {
    final roster = await pumpScreen(tester, signedInAs: manager);

    await tester.tap(find.byTooltip('Move Ada Pillay to another squad'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('No squad').last);
    await tester.pumpAndSettle();

    // There is no delete: an emptied squadId, so the placement stays a record
    // of a decision somebody made.
    expect(roster.squadOf('dev'), '');
    expect(roster.placements, hasLength(placements.length));
  });

  testWidgets('a refused move is reported rather than swallowed', (
    tester,
  ) async {
    // The row was drawn from a directory that said developer, and the
    // repository reads the role again when it writes. If somebody was
    // promoted in between, the move is refused, and has to be said, or the
    // person who made it carries on believing the roster says what they meant.
    final roster = await pumpScreen(
      tester,
      signedInAs: lead,
      writesAgainst: const [
        DirectoryEntry(
          id: 'dev',
          displayName: 'Ada Pillay',
          role: UserRole.lead,
        ),
      ],
    );

    await tester.tap(find.byTooltip('Move Ada Pillay to another squad'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Mobile squad').last);
    await tester.pumpAndSettle();

    expect(roster.squadOf('dev'), 's1');
    expect(find.textContaining('below yours'), findsOneWidget);
  });

  testWidgets('renders before anybody has been placed', (tester) async {
    // Every organisation's first run. The capacity figures still have to be
    // readable, and the screen has to invite the first placement rather than
    // look broken.
    await pumpScreen(
      tester,
      signedInAs: manager,
      displayedAs: const [],
      initial: const [],
    );

    expect(find.text('Platform squad'), findsOneWidget);
    expect(
      find.textContaining('Nobody placed on this squad yet'),
      findsNWidgets(2),
    );
    expect(find.text('ON NO SQUAD'), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
