import '../models/conversation.dart';
import '../models/directory_entry.dart';
import '../models/message.dart';

/// Direct messages and groups, as an interface.
///
/// Kept apart from [CommentRepository] and [ProjectRepository]. Comments are a
/// discussion attached to one signal; this is people talking to people. Neither
/// feeds a score and neither reaches the assistant.
///
/// Permissions are enforced twice. The implementations refuse what the rules
/// would refuse, so a screen gets a message it can show, and `firestore.rules`
/// refuses it again, which is what makes the first check more than a courtesy.
/// The rules themselves are written down in `MessagingRules`.
abstract interface class MessagingRepository {
  /// Everyone in the organisation who can be messaged, live.
  Stream<List<DirectoryEntry>> watchDirectory();

  /// The conversations the signed-in person is in, most recent first, live.
  Stream<List<Conversation>> watchConversations();

  /// One conversation's messages, oldest first, live. Emits immediately from the
  /// local cache when offline.
  Stream<List<Message>> watchMessages(String conversationId);

  /// The direct conversation with [userId], starting it if there is none, and
  /// returns its id. Open to every role, and does not need a shared group.
  ///
  /// Needs a connection: it has to find out whether the conversation exists.
  Future<String> openDirect(String userId);

  /// Makes a group and adds [memberIds] to it, with the creator already in it,
  /// and returns its id. Leads and managers only.
  ///
  /// Needs a connection.
  Future<String> createGroup({
    required String name,
    required List<String> memberIds,
  });

  /// Adds somebody to a group. Leads and managers only.
  Future<void> addMember({
    required String conversationId,
    required String userId,
  });

  /// Takes somebody out of a group.
  ///
  /// Anyone may remove themselves. Removing somebody else needs a strictly
  /// higher role than theirs: managers can remove leads and developers, leads
  /// can remove developers, and nobody can remove their own rank or above.
  Future<void> removeMember({
    required String conversationId,
    required String userId,
  });

  /// Sends a message as the signed-in user.
  ///
  /// Offline, the returned future does not complete until the server confirms,
  /// while [watchMessages] already shows the message as pending. Callers should
  /// not block the screen on it.
  Future<void> send({required String conversationId, required String body});
}
