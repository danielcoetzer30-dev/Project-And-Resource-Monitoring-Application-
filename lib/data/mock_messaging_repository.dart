import 'dart:async';

import '../core/errors/exceptions.dart';
import '../models/app_user.dart';
import '../models/conversation.dart';
import '../models/directory_entry.dart';
import '../models/message.dart';
import '../models/messaging_rules.dart';
import 'messaging_repository.dart';

/// An in-memory [MessagingRepository], for tests and for running the app with
/// no backend.
///
/// Applies the same [MessagingRules] and the same membership checks as the
/// security rules, so a test that passes here cannot be relying on something
/// Firestore would refuse. Roles come from [directory], which plays the part of
/// the real `users` documents the rules read.
class MockMessagingRepository implements MessagingRepository {
  MockMessagingRepository({
    required this.user,
    required List<DirectoryEntry> directory,
    List<Conversation> conversations = const [],
    Map<String, List<Message>> messages = const {},
  }) : _directory = [...directory] {
    for (final conversation in conversations) {
      _conversations[conversation.id] = conversation;
    }
    for (final entry in messages.entries) {
      _messages[entry.key] = [...entry.value];
    }
  }

  /// Who writes are made as.
  final AppUser user;

  final List<DirectoryEntry> _directory;
  final _conversations = <String, Conversation>{};
  final _messages = <String, List<Message>>{};
  final _changed = StreamController<void>.broadcast();
  var _nextId = 0;

  UserRole? _roleOf(String userId) {
    for (final entry in _directory) {
      if (entry.id == userId) return entry.role;
    }
    return null;
  }

  bool _inOrganisation(String userId) => _roleOf(userId) != null;

  Stream<T> _watch<T>(T Function() read) {
    late StreamController<T> controller;
    StreamSubscription<void>? subscription;

    void emit() {
      try {
        controller.add(read());
      } on AppException catch (error) {
        controller.addError(error);
      }
    }

    controller = StreamController<T>(
      onListen: () {
        emit();
        subscription = _changed.stream.listen((_) => emit());
      },
      onCancel: () => subscription?.cancel(),
    );

    return controller.stream;
  }

  @override
  Stream<List<DirectoryEntry>> watchDirectory() {
    return _watch(() {
      final entries = [..._directory];
      entries.sort(
        (a, b) =>
            a.displayName.toLowerCase().compareTo(b.displayName.toLowerCase()),
      );
      return entries;
    });
  }

  @override
  Stream<List<Conversation>> watchConversations() {
    return _watch(() {
      final mine = _conversations.values
          .where((conversation) => conversation.hasMember(user.id))
          .toList();
      mine.sort((a, b) => b.lastActivity.compareTo(a.lastActivity));
      return mine;
    });
  }

  @override
  Stream<List<Message>> watchMessages(String conversationId) {
    return _watch(() {
      _requireMember(conversationId);
      return List.unmodifiable(_messages[conversationId] ?? const <Message>[]);
    });
  }

  Conversation _requireMember(String conversationId) {
    final conversation = _conversations[conversationId];
    if (conversation == null || !conversation.hasMember(user.id)) {
      throw const PermissionException('You are not in this conversation.');
    }
    return conversation;
  }

  @override
  Future<String> openDirect(String userId) async {
    if (userId == user.id) {
      throw const ValidationException('Pick somebody other than yourself.');
    }
    if (!_inOrganisation(userId)) {
      throw const PermissionException('That person is not in your team.');
    }

    final id = Conversation.directIdFor(user.id, userId);
    if (!_conversations.containsKey(id)) {
      final ids = [user.id, userId]..sort();
      _conversations[id] = Conversation(
        id: id,
        kind: ConversationKind.direct,
        memberIds: ids,
        createdBy: user.id,
        lastActivity: DateTime.now(),
      );
      _changed.add(null);
    }
    return id;
  }

  @override
  Future<String> createGroup({
    required String name,
    required List<String> memberIds,
  }) async {
    if (!MessagingRules.canCreateGroup(user.role)) {
      throw const PermissionException(
        'Only leads and managers can create groups.',
      );
    }

    final title = name.trim();
    final problem = MessagingRules.problemWithGroupName(title);
    if (problem != null) throw ValidationException(problem);

    final others = memberIds.where((id) => id != user.id).toSet().toList();
    if (others.length + 1 > MessagingRules.maxGroupSize) {
      throw const ValidationException(
        'A group holds at most ${MessagingRules.maxGroupSize} people.',
      );
    }
    if (!others.every(_inOrganisation)) {
      throw const PermissionException('That person is not in your team.');
    }

    final id = 'mock-group-${_nextId++}';
    _conversations[id] = Conversation(
      id: id,
      kind: ConversationKind.group,
      name: title,
      memberIds: [user.id, ...others],
      createdBy: user.id,
      lastActivity: DateTime.now(),
    );
    _changed.add(null);
    return id;
  }

  @override
  Future<void> addMember({
    required String conversationId,
    required String userId,
  }) async {
    final conversation = _requireMember(conversationId);

    if (!conversation.isGroup) {
      throw const PermissionException('People cannot be added to this.');
    }
    if (!MessagingRules.canAddMembers(user.role)) {
      throw const PermissionException(
        'Only leads and managers can add people to a group.',
      );
    }
    if (!_inOrganisation(userId)) {
      throw const PermissionException('That person is not in your team.');
    }
    if (conversation.hasMember(userId)) return;
    if (conversation.memberIds.length >= MessagingRules.maxGroupSize) {
      throw const ValidationException(
        'A group holds at most ${MessagingRules.maxGroupSize} people.',
      );
    }

    _conversations[conversationId] = conversation.copyWith(
      memberIds: [...conversation.memberIds, userId],
    );
    _changed.add(null);
  }

  @override
  Future<void> removeMember({
    required String conversationId,
    required String userId,
  }) async {
    final conversation = _requireMember(conversationId);

    if (!conversation.isGroup) {
      throw const PermissionException('People cannot be removed from this.');
    }
    if (!conversation.hasMember(userId)) return;

    final targetRole = _roleOf(userId);
    final allowed =
        targetRole != null &&
        MessagingRules.canRemove(
          actorId: user.id,
          actorRole: user.role,
          targetId: userId,
          targetRole: targetRole,
        );
    if (!allowed) {
      throw const PermissionException(
        'You can only remove people whose role is below yours.',
      );
    }

    _conversations[conversationId] = conversation.copyWith(
      memberIds: [
        for (final id in conversation.memberIds)
          if (id != userId) id,
      ],
    );
    _changed.add(null);
  }

  @override
  Future<void> send({
    required String conversationId,
    required String body,
  }) async {
    final conversation = _requireMember(conversationId);

    final text = body.trim();
    if (MessagingRules.problemWithMessage(text) != null) {
      throw const ParseException('That message cannot be sent.');
    }

    final now = DateTime.now();
    (_messages[conversationId] ??= []).add(
      Message(
        id: 'mock-${_nextId++}',
        body: text,
        senderId: user.id,
        senderName: user.displayName,
        createdAt: now,
      ),
    );
    _conversations[conversationId] = conversation.copyWith(lastActivity: now);
    _changed.add(null);
  }

  void dispose() => _changed.close();
}
