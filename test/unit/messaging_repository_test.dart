import 'package:flutter_test/flutter_test.dart';

import 'package:keel/core/errors/exceptions.dart';
import 'package:keel/data/mock_messaging_repository.dart';
import 'package:keel/models/app_user.dart';
import 'package:keel/models/conversation.dart';
import 'package:keel/models/directory_entry.dart';
import 'package:keel/models/message.dart';

/// Messaging as the screens rely on it. Runs against the in-memory repository,
/// which applies the same permissions as `firestore.rules`.
void main() {
  const boss = DirectoryEntry(
    id: 'boss',
    displayName: 'Thandi',
    role: UserRole.manager,
  );
  const otherBoss = DirectoryEntry(
    id: 'other-boss',
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
  const dev = DirectoryEntry(
    id: 'dev',
    displayName: 'Ayanda',
    role: UserRole.developer,
  );
  const otherDev = DirectoryEntry(
    id: 'other-dev',
    displayName: 'Lerato',
    role: UserRole.developer,
  );

  const everyone = [boss, otherBoss, lead, otherLead, dev, otherDev];

  AppUser asUser(DirectoryEntry entry) => AppUser(
    id: entry.id,
    email: '${entry.id}@example.com',
    displayName: entry.displayName,
    orgId: 'demo-org',
    role: entry.role,
  );

  MockMessagingRepository repoAs(
    DirectoryEntry who, {
    List<Conversation> conversations = const [],
    Map<String, List<Message>> messages = const {},
  }) {
    final repository = MockMessagingRepository(
      user: asUser(who),
      directory: everyone,
      conversations: conversations,
      messages: messages,
    );
    addTearDown(repository.dispose);
    return repository;
  }

  /// A group everybody is in, so each test only has to say who is acting.
  Conversation fullGroup() => Conversation(
    id: 'g',
    kind: ConversationKind.group,
    name: 'Ledger rebuild',
    memberIds: [for (final person in everyone) person.id],
    createdBy: boss.id,
    lastActivity: DateTime(2026, 10, 1),
  );

  Future<List<String>> membersSeenBy(MockMessagingRepository repo) async {
    final inbox = await repo.watchConversations().first;
    return inbox.singleWhere((c) => c.id == 'g').memberIds;
  }

  group('creating a group', () {
    test('a manager can, and is in it', () async {
      final repo = repoAs(boss);

      final id = await repo.createGroup(
        name: '  Ledger rebuild  ',
        memberIds: [lead.id, dev.id],
      );

      final group = (await repo.watchConversations().first).single;
      expect(group.id, id);
      expect(group.isGroup, isTrue);
      expect(group.name, 'Ledger rebuild');
      expect(group.memberIds, containsAll([boss.id, lead.id, dev.id]));
    });

    test('a lead can', () async {
      final repo = repoAs(lead);

      await repo.createGroup(name: 'Mobile squad', memberIds: [dev.id]);

      expect(await repo.watchConversations().first, hasLength(1));
    });

    test('a developer cannot', () async {
      final repo = repoAs(dev);

      await expectLater(
        repo.createGroup(name: 'Secret club', memberIds: [otherDev.id]),
        throwsA(isA<PermissionException>()),
      );
      expect(await repo.watchConversations().first, isEmpty);
    });

    test('it needs a name', () async {
      final repo = repoAs(boss);

      await expectLater(
        repo.createGroup(name: '   ', memberIds: [lead.id]),
        throwsA(isA<ValidationException>()),
      );
    });

    test('the creator is not listed twice', () async {
      final repo = repoAs(boss);

      await repo.createGroup(name: 'Ops', memberIds: [boss.id, lead.id]);

      final group = (await repo.watchConversations().first).single;
      expect(group.memberIds.where((id) => id == boss.id), hasLength(1));
    });
  });

  group('adding people to a group', () {
    Conversation smallGroup(List<String> ids) => Conversation(
      id: 'g',
      kind: ConversationKind.group,
      name: 'Ledger rebuild',
      memberIds: ids,
      createdBy: boss.id,
      lastActivity: DateTime(2026, 10, 1),
    );

    test('a lead can', () async {
      final repo = repoAs(
        lead,
        conversations: [
          smallGroup([lead.id]),
        ],
      );

      await repo.addMember(conversationId: 'g', userId: dev.id);

      expect(await membersSeenBy(repo), [lead.id, dev.id]);
    });

    test('a developer cannot', () async {
      final repo = repoAs(
        dev,
        conversations: [
          smallGroup([dev.id]),
        ],
      );

      await expectLater(
        repo.addMember(conversationId: 'g', userId: otherDev.id),
        throwsA(isA<PermissionException>()),
      );
      expect(await membersSeenBy(repo), [dev.id]);
    });

    test('somebody outside the organisation cannot be added', () async {
      final repo = repoAs(
        boss,
        conversations: [
          smallGroup([boss.id]),
        ],
      );

      await expectLater(
        repo.addMember(conversationId: 'g', userId: 'stranger'),
        throwsA(isA<PermissionException>()),
      );
    });
  });

  group('removing people from a group', () {
    Future<void> expectRemoved(
      DirectoryEntry actor,
      DirectoryEntry target,
    ) async {
      final repo = repoAs(actor, conversations: [fullGroup()]);

      await repo.removeMember(conversationId: 'g', userId: target.id);

      expect(await membersSeenBy(repo), isNot(contains(target.id)));
    }

    Future<void> expectRefused(
      DirectoryEntry actor,
      DirectoryEntry target,
    ) async {
      final repo = repoAs(actor, conversations: [fullGroup()]);

      await expectLater(
        repo.removeMember(conversationId: 'g', userId: target.id),
        throwsA(isA<PermissionException>()),
      );
      expect(await membersSeenBy(repo), contains(target.id));
    }

    test('a manager can remove a lead', () => expectRemoved(boss, lead));

    test('a manager can remove a developer', () => expectRemoved(boss, dev));

    test('a lead can remove a developer', () => expectRemoved(lead, dev));

    test('a lead cannot remove a manager', () => expectRefused(lead, boss));

    test('a lead cannot remove another lead', () {
      return expectRefused(lead, otherLead);
    });

    test('a manager cannot remove another manager', () {
      return expectRefused(boss, otherBoss);
    });

    test('a developer cannot remove anybody', () async {
      await expectRefused(dev, otherDev);
      await expectRefused(dev, lead);
      await expectRefused(dev, boss);
    });

    test('a developer can leave, and loses the conversation', () async {
      final repo = repoAs(dev, conversations: [fullGroup()]);

      await repo.removeMember(conversationId: 'g', userId: dev.id);

      expect(await repo.watchConversations().first, isEmpty);
      await expectLater(
        repo.watchMessages('g'),
        emitsError(isA<PermissionException>()),
      );
    });

    test('a manager can leave too', () async {
      final repo = repoAs(boss, conversations: [fullGroup()]);

      await repo.removeMember(conversationId: 'g', userId: boss.id);

      expect(await repo.watchConversations().first, isEmpty);
    });
  });

  group('direct messages', () {
    test('anybody can message anybody, with no group in common', () async {
      final repo = repoAs(dev);

      final id = await repo.openDirect(otherDev.id);

      final conversation = (await repo.watchConversations().first).single;
      expect(conversation.id, id);
      expect(conversation.isGroup, isFalse);
      expect(conversation.memberIds, unorderedEquals([dev.id, otherDev.id]));
    });

    test('a developer can message a manager', () async {
      final repo = repoAs(dev);

      await repo.openDirect(boss.id);

      expect(await repo.watchConversations().first, hasLength(1));
    });

    test('the same two people always share one conversation', () async {
      final fromDev = repoAs(dev);
      final fromOtherDev = repoAs(otherDev);

      final first = await fromDev.openDirect(otherDev.id);
      final again = await fromDev.openDirect(otherDev.id);
      final fromTheirSide = await fromOtherDev.openDirect(dev.id);

      expect(again, first);
      expect(fromTheirSide, first);
      expect(await fromDev.watchConversations().first, hasLength(1));
    });

    test('you cannot message yourself', () async {
      final repo = repoAs(dev);

      await expectLater(
        repo.openDirect(dev.id),
        throwsA(isA<ValidationException>()),
      );
    });

    test('somebody outside the organisation cannot be messaged', () async {
      final repo = repoAs(dev);

      await expectLater(
        repo.openDirect('stranger'),
        throwsA(isA<PermissionException>()),
      );
    });
  });

  group('sending', () {
    test('a message is sent as the signed-in user, and trimmed', () async {
      final repo = repoAs(lead, conversations: [fullGroup()]);

      await repo.send(conversationId: 'g', body: '  Fix ships Friday  ');

      final message = (await repo.watchMessages('g').first).single;
      expect(message.body, 'Fix ships Friday');
      expect(message.senderId, lead.id);
      expect(message.senderName, lead.displayName);
    });

    test('messages read oldest first', () async {
      final repo = repoAs(dev, conversations: [fullGroup()]);

      await repo.send(conversationId: 'g', body: 'first');
      await repo.send(conversationId: 'g', body: 'second');

      final thread = await repo.watchMessages('g').first;
      expect(thread.map((m) => m.body), ['first', 'second']);
    });

    test('a blank message is refused', () async {
      final repo = repoAs(dev, conversations: [fullGroup()]);

      await expectLater(
        repo.send(conversationId: 'g', body: '   '),
        throwsA(isA<ParseException>()),
      );
      expect(await repo.watchMessages('g').first, isEmpty);
    });

    test('somebody who is not in the conversation cannot send', () async {
      final group = Conversation(
        id: 'g',
        kind: ConversationKind.group,
        name: 'Leads only',
        memberIds: [boss.id, lead.id],
        createdBy: boss.id,
        lastActivity: DateTime(2026, 10, 1),
      );
      final repo = repoAs(dev, conversations: [group]);

      await expectLater(
        repo.send(conversationId: 'g', body: 'let me in'),
        throwsA(isA<PermissionException>()),
      );
      await expectLater(
        repo.watchMessages('g'),
        emitsError(isA<PermissionException>()),
      );
    });

    test('the conversation with the latest message comes first', () async {
      final repo = repoAs(boss);
      final withLead = await repo.openDirect(lead.id);
      final withDev = await repo.openDirect(dev.id);

      // A short gap between sends, so the order does not depend on two
      // timestamps landing in different microseconds.
      const gap = Duration(milliseconds: 5);
      await repo.send(conversationId: withLead, body: 'hello');
      await Future<void>.delayed(gap);
      await repo.send(conversationId: withDev, body: 'hello');
      await Future<void>.delayed(gap);
      await repo.send(conversationId: withLead, body: 'one more thing');

      final inbox = await repo.watchConversations().first;
      expect(inbox.map((c) => c.id), [withLead, withDev]);
    });

    test('an open conversation hears about a new message', () async {
      final repo = repoAs(dev, conversations: [fullGroup()]);
      final emitted = <List<Message>>[];
      final subscription = repo.watchMessages('g').listen(emitted.add);
      await pumpEventQueue();

      await repo.send(conversationId: 'g', body: 'hello');
      await pumpEventQueue();
      await subscription.cancel();

      expect(emitted.map((t) => t.length), [0, 1]);
    });
  });
}
