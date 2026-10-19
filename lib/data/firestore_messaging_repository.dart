import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';

import '../core/constants/app_constants.dart';
import '../core/errors/exceptions.dart';
import '../models/app_user.dart';
import '../models/conversation.dart';
import '../models/directory_entry.dart';
import '../models/message.dart';
import '../models/messaging_rules.dart';
import 'dto/conversation_dto.dart';
import 'dto/directory_dto.dart';
import 'dto/message_dto.dart';
import 'messaging_repository.dart';

/// The real implementation of [MessagingRepository].
///
/// Everything sits under the organisation, so one membership check scopes it
/// and no team can see another's conversations. A conversation's messages are
/// its own subcollection, so nothing is read until somebody opens it, and the
/// one listener that runs for an open conversation is bounded by
/// [AppConstants.messagesShown] and closes with the screen.
///
/// The inbox query filters on membership and sorts on the device, which keeps
/// it free of a composite index.
class FirestoreMessagingRepository implements MessagingRepository {
  FirestoreMessagingRepository({
    required this.orgId,
    this.user,
    FirebaseFirestore? firestore,
  }) : _firestore = firestore ?? FirebaseFirestore.instance;

  final String orgId;

  /// Who messages are sent as. Null when nobody is signed in, in which case
  /// reading yields nothing and writing is refused.
  final AppUser? user;

  final FirebaseFirestore _firestore;

  DocumentReference<Map<String, dynamic>> get _org =>
      _firestore.collection(AppConstants.organisationsCollection).doc(orgId);

  CollectionReference<Map<String, dynamic>> get _directory =>
      _org.collection(AppConstants.directoryCollection);

  CollectionReference<Map<String, dynamic>> get _conversations =>
      _org.collection(AppConstants.conversationsCollection);

  CollectionReference<Map<String, dynamic>> _messages(String conversationId) =>
      _conversations
          .doc(conversationId)
          .collection(AppConstants.messagesCollection);

  /// Nobody signed in, or no organisation: Firestore rejects a path with a
  /// blank segment outright, so reads answer with nothing instead.
  bool get _hasNoSession => orgId.isEmpty || user == null;

  AppUser _requireUser() {
    final me = user;
    if (me == null || orgId.isEmpty) {
      throw const AuthException('Sign in to use messages.');
    }
    return me;
  }

  @override
  Stream<List<DirectoryEntry>> watchDirectory() {
    if (orgId.isEmpty) return Stream.value(const []);

    return _translated(
      _directory.snapshots().map((query) {
        final entries = query.docs.map(DirectoryDto.fromDoc).toList();
        entries.sort(
          (a, b) => a.displayName.toLowerCase().compareTo(
            b.displayName.toLowerCase(),
          ),
        );
        return entries;
      }),
    );
  }

  @override
  Stream<List<Conversation>> watchConversations() {
    final me = user;
    if (_hasNoSession || me == null) return Stream.value(const []);

    return _translated(
      _conversations
          .where('memberIds', arrayContains: me.id)
          // Metadata changes are free of read charges and keep the inbox in
          // step with a message that has just been sent from this device.
          .snapshots(includeMetadataChanges: true)
          .map((query) {
            final conversations = query.docs
                .map(ConversationDto.fromDoc)
                .toList();
            conversations.sort(
              (a, b) => b.lastActivity.compareTo(a.lastActivity),
            );
            return conversations;
          }),
    );
  }

  @override
  Stream<List<Message>> watchMessages(String conversationId) {
    if (_hasNoSession) return Stream.value(const []);

    return _translated(
      _messages(conversationId)
          .orderBy('createdAt')
          .limitToLast(AppConstants.messagesShown)
          .snapshots(includeMetadataChanges: true)
          .map((query) => query.docs.map(MessageDto.fromDoc).toList()),
    );
  }

  @override
  Future<String> openDirect(String userId) async {
    final me = _requireUser();
    if (userId == me.id) {
      throw const ValidationException('Pick somebody other than yourself.');
    }

    final id = Conversation.directIdFor(me.id, userId);
    final ref = _conversations.doc(id);
    final ids = [me.id, userId]..sort();

    try {
      // Read from the server rather than the cache. It answers "does this
      // exist yet" truthfully, and fails at once when offline instead of
      // queueing a write the person would not know was waiting.
      final existing = await ref.get(const GetOptions(source: Source.server));
      if (!existing.exists) {
        await ref.set(
          ConversationDto.toNewDirect(
            creator: me,
            firstId: ids[0],
            secondId: ids[1],
          ),
        );
      }
    } on FirebaseException catch (error) {
      throw _translate(error);
    }
    return id;
  }

  @override
  Future<String> createGroup({
    required String name,
    required List<String> memberIds,
  }) async {
    final me = _requireUser();
    if (!MessagingRules.canCreateGroup(me.role)) {
      throw const PermissionException(
        'Only leads and managers can create groups.',
      );
    }

    final title = name.trim();
    final problem = MessagingRules.problemWithGroupName(title);
    if (problem != null) throw ValidationException(problem);

    final others = memberIds.where((id) => id != me.id).toSet().toList();
    if (others.length + 1 > MessagingRules.maxGroupSize) {
      throw const ValidationException(
        'A group holds at most ${MessagingRules.maxGroupSize} people.',
      );
    }

    final ref = _conversations.doc();

    try {
      await _requireOnline(ref);
      await ref.set(ConversationDto.toNewGroup(creator: me, name: title));
      // One at a time: the rules check each newcomer's organisation, and can
      // only check one person per write.
      for (final id in others) {
        await ref.update({
          'memberIds': FieldValue.arrayUnion([id]),
        });
      }
    } on FirebaseException catch (error) {
      throw _translate(error);
    }
    return ref.id;
  }

  @override
  Future<void> addMember({
    required String conversationId,
    required String userId,
  }) async {
    final me = _requireUser();
    if (!MessagingRules.canAddMembers(me.role)) {
      throw const PermissionException(
        'Only leads and managers can add people to a group.',
      );
    }

    final ref = _conversations.doc(conversationId);
    try {
      await _requireOnline(ref);
      await ref.update({
        'memberIds': FieldValue.arrayUnion([userId]),
      });
    } on FirebaseException catch (error) {
      throw _translate(error);
    }
  }

  @override
  Future<void> removeMember({
    required String conversationId,
    required String userId,
  }) async {
    _requireUser();

    // Whether the caller outranks the target is decided by the rules, from the
    // two people's real roles on their `users` documents. The screen decides
    // whether to offer the control; this does not trust it.
    final ref = _conversations.doc(conversationId);
    try {
      await _requireOnline(ref);
      await ref.update({
        'memberIds': FieldValue.arrayRemove([userId]),
      });
    } on FirebaseException catch (error) {
      throw _translate(error);
    }
  }

  @override
  Future<void> send({
    required String conversationId,
    required String body,
  }) async {
    final me = _requireUser();

    final text = body.trim();
    if (MessagingRules.problemWithMessage(text) != null) {
      throw const ParseException('That message cannot be sent.');
    }

    final conversation = _conversations.doc(conversationId);
    final batch = _firestore.batch()
      ..set(
        _messages(conversationId).doc(),
        MessageDto.toNewMap(body: text, sender: me),
      )
      // Keeps the inbox ordered by what was said last. Members may change this
      // one field and nothing else about a conversation.
      ..update(conversation, {'lastMessageAt': FieldValue.serverTimestamp()});

    try {
      await batch.commit();
    } on FirebaseException catch (error) {
      throw _translate(error);
    }
  }

  /// Fails at once when the device cannot reach the backend, so membership
  /// changes and new groups are never left queued where the person cannot see
  /// them.
  Future<void> _requireOnline(DocumentReference<Map<String, dynamic>> ref) {
    return ref.get(const GetOptions(source: Source.server));
  }

  Stream<T> _translated<T>(Stream<T> source) {
    return source.transform(
      StreamTransformer<T, T>.fromHandlers(
        handleError: (error, stackTrace, sink) =>
            sink.addError(_translate(error), stackTrace),
      ),
    );
  }

  /// Converts a Firestore error at the repository boundary, so nothing above
  /// this file catches a raw `FirebaseException`.
  Object _translate(Object error) {
    if (error is! FirebaseException) return error;

    return switch (error.code) {
      'permission-denied' => const PermissionException(
        'The backend refused this. Your role may not allow it.',
      ),
      'unavailable' || 'deadline-exceeded' => const NetworkException(
        'The device could not reach the backend.',
      ),
      _ => error,
    };
  }
}
