/// Who said it.
enum ChatRole { user, assistant }

/// One turn in a conversation with the assistant.
///
/// Conversations are not persisted. They live for as long as the screen does
/// and are gone when the app closes — a question about project health is not
/// something the app needs to keep, and storing it would mean storing a copy
/// of the data outside the security rules that protect the original.
class ChatMessage {
  const ChatMessage({
    required this.role,
    required this.text,
    required this.at,
    this.isError = false,
  });

  ChatMessage.user(this.text)
    : role = ChatRole.user,
      at = DateTime.now(),
      isError = false;

  ChatMessage.assistant(this.text)
    : role = ChatRole.assistant,
      at = DateTime.now(),
      isError = false;

  /// A failure, shown in the conversation rather than as a dialog, so the
  /// question it relates to stays visible above it.
  ChatMessage.failure(this.text)
    : role = ChatRole.assistant,
      at = DateTime.now(),
      isError = true;

  final ChatRole role;
  final String text;
  final DateTime at;
  final bool isError;

  bool get isUser => role == ChatRole.user;
}
