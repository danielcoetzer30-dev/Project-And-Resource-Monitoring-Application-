import '../../core/errors/failure.dart';
import '../../models/conversation.dart';
import '../../models/directory_entry.dart';

/// The directory keyed by uid, for looking people up by the ids a
/// conversation stores.
Map<String, DirectoryEntry> peopleById(List<DirectoryEntry> entries) {
  return {for (final entry in entries) entry.id: entry};
}

/// What to call a conversation: a group by its name, a direct conversation by
/// the other person.
String conversationTitle(
  Conversation conversation, {
  required String myId,
  required Map<String, DirectoryEntry> people,
}) {
  if (conversation.isGroup) {
    return conversation.name.isEmpty ? 'Group' : conversation.name;
  }
  return people[conversation.otherMemberId(myId)]?.displayName ?? 'A teammate';
}

/// Says what went wrong and what to do, never just that something did.
///
/// [whenFailed] is the opening sentence, e.g. "Your message did not send.".
String describeMessagingFailure(Object error, {required String whenFailed}) {
  return switch (failureFromException(error)) {
    // Carries its own message, already written for the person reading it.
    PermissionFailure(:final message) => '$whenFailed $message',
    AuthFailure() => 'Sign in to use messages.',
    NetworkFailure() => '$whenFailed Check your connection and try again.',
    DataFailure() => '$whenFailed Try again.',
    ValidationFailure(:final message) => message,
  };
}
