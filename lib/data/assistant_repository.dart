import '../models/chat_message.dart';

/// Answers questions about the current project health data.
///
/// An interface for the same reason every other repository is one: the screens
/// never learn which model answered, the conversation can be tested without a
/// network, and swapping a direct API call for a backend proxy later is one new
/// class rather than a rewrite of the chat screen.
abstract interface class AssistantRepository {
  /// True when the assistant is usable — for the direct implementation, that
  /// means an API key has been entered.
  Future<bool> isConfigured();

  /// Answers [question] given [context] describing the current data, with
  /// [history] as the conversation so far.
  ///
  /// Throws an [AppException] subclass on failure so the caller can turn it
  /// into a readable message rather than surfacing a status code.
  Future<String> ask({
    required String question,
    required String context,
    required List<ChatMessage> history,
  });
}
