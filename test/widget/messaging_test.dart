import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:keel/data/mock_messaging_repository.dart';
import 'package:keel/models/app_user.dart';
import 'package:keel/models/conversation.dart';
import 'package:keel/models/directory_entry.dart';
import 'package:keel/screens/messaging/conversation_screen.dart';
import 'package:keel/screens/messaging/group_members_screen.dart';
import 'package:keel/state/providers.dart';

import '../support/fake_auth_repository.dart';

/// The two screens where the role rules show: who a person is offered the
/// chance to remove, and sending a direct message.
///
/// Runs against the in-memory repository, so it needs no Firebase.
void main() {
  const manager = DirectoryEntry(
    id: 'manager',
    displayName: 'Thandi',
    role: UserRole.manager,
  );
  const otherManager = DirectoryEntry(
    id: 'other-manager',
    displayName: 'Zodwa',
    role: UserRole.manager,
  );
  const lead = DirectoryEntry(
    id: 'lead',
    displayName: 'Naledi',
    role: UserRole.lead,
  );
  const otherLead = DirectoryEntry(
    id: 'other-lead',
    displayName: 'Sipho',
    role: UserRole.lead,
  );
  const developer = DirectoryEntry(
    id: 'developer',
    displayName: 'Ayanda',
    role: UserRole.developer,
  );
  const people = [manager, otherManager, lead, otherLead, developer];

  AppUser asUser(DirectoryEntry entry) => AppUser(
    id: entry.id,
    email: '${entry.id}@example.com',
    displayName: entry.displayName,
    orgId: 'demo-org',
    role: entry.role,
  );

  final squadGroup = Conversation(
    id: 'g',
    kind: ConversationKind.group,
    name: 'Ledger rebuild',
    memberIds: [for (final person in people) person.id],
    createdBy: manager.id,
    lastActivity: DateTime(2026, 10, 1),
  );

  Widget screen(Widget home, {required DirectoryEntry signedInAs}) {
    final user = asUser(signedInAs);
    final repository = MockMessagingRepository(
      user: user,
      directory: people,
      conversations: [squadGroup],
    );
    addTearDown(repository.dispose);

    return ProviderScope(
      overrides: [
        authRepositoryProvider.overrideWithValue(
          FakeAuthRepository(user: user),
        ),
        messagingRepositoryProvider.overrideWithValue(repository),
      ],
      child: MaterialApp(home: home),
    );
  }

  Widget members(DirectoryEntry signedInAs) => screen(
    const GroupMembersScreen(conversationId: 'g'),
    signedInAs: signedInAs,
  );

  group('group members', () {
    testWidgets('a manager can remove leads and developers, not managers', (
      tester,
    ) async {
      await tester.pumpWidget(members(manager));
      await tester.pumpAndSettle();

      expect(find.byTooltip('Remove Naledi'), findsOneWidget);
      expect(find.byTooltip('Remove Sipho'), findsOneWidget);
      expect(find.byTooltip('Remove Ayanda'), findsOneWidget);
      expect(find.byTooltip('Remove Zodwa'), findsNothing);
      expect(find.byTooltip('Remove Thandi'), findsNothing);
    });

    testWidgets('a lead can remove developers, not leads or managers', (
      tester,
    ) async {
      await tester.pumpWidget(members(lead));
      await tester.pumpAndSettle();

      expect(find.byTooltip('Remove Ayanda'), findsOneWidget);
      expect(find.byTooltip('Remove Sipho'), findsNothing);
      expect(find.byTooltip('Remove Thandi'), findsNothing);
      expect(find.byTooltip('Remove Zodwa'), findsNothing);
    });

    testWidgets('a developer can only leave, and cannot add anybody', (
      tester,
    ) async {
      await tester.pumpWidget(members(developer));
      await tester.pumpAndSettle();

      expect(find.textContaining('Remove '), findsNothing);
      expect(find.byTooltip('Remove Naledi'), findsNothing);
      expect(find.text('Leave'), findsOneWidget);
      expect(find.text('Add people'), findsNothing);
    });

    testWidgets('leads and managers are offered Add people', (tester) async {
      await tester.pumpWidget(members(lead));
      await tester.pumpAndSettle();

      expect(find.text('Add people'), findsOneWidget);
    });

    testWidgets('confirming a removal takes the person out of the list', (
      tester,
    ) async {
      await tester.pumpWidget(members(manager));
      await tester.pumpAndSettle();
      expect(find.text('Ayanda'), findsOneWidget);

      await tester.tap(find.byTooltip('Remove Ayanda'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(TextButton, 'Remove'));
      await tester.pumpAndSettle();

      expect(find.text('Ayanda'), findsNothing);
      expect(find.text('Naledi'), findsOneWidget);
    });
  });

  group('a direct conversation', () {
    testWidgets('shows the other person and sends as you', (tester) async {
      final direct = Conversation(
        id: Conversation.directIdFor(developer.id, lead.id),
        kind: ConversationKind.direct,
        memberIds: [developer.id, lead.id],
        createdBy: developer.id,
        lastActivity: DateTime(2026, 10, 1),
      );
      final user = asUser(developer);
      final repository = MockMessagingRepository(
        user: user,
        directory: people,
        conversations: [direct],
      );
      addTearDown(repository.dispose);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            authRepositoryProvider.overrideWithValue(
              FakeAuthRepository(user: user),
            ),
            messagingRepositoryProvider.overrideWithValue(repository),
          ],
          child: MaterialApp(
            home: ConversationScreen(conversationId: direct.id),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Titled after the other person, with no members control: it is not a
      // group.
      expect(find.text('Naledi'), findsOneWidget);
      expect(find.byTooltip('Members'), findsNothing);
      expect(find.text('No messages yet. Say hello.'), findsOneWidget);

      await tester.enterText(find.byType(TextField), '  Hello there  ');
      await tester.pump();
      await tester.tap(find.byTooltip('Send message'));
      await tester.pumpAndSettle();

      expect(find.text('Hello there'), findsOneWidget);
      expect(find.text('You'), findsOneWidget);
      expect(find.text('No messages yet. Say hello.'), findsNothing);
    });
  });
}
