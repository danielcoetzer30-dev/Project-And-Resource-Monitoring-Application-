import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/errors/failure.dart';
import '../data/assistant_repository.dart';
import '../data/project_repository.dart';
import '../models/chat_message.dart';
import '../services/assistant/snapshot_brief.dart';
import 'providers.dart';

/// The conversation, and whether a reply is in flight.
class AssistantState {
  const AssistantState({
    this.messages = const [],
    this.isWaiting = false,
    this.isConfigured = true,
  });

  final List<ChatMessage> messages;

  /// A question has been sent and the answer has not come back.
  final bool isWaiting;

  /// False when no API key is saved, so the screen can say so instead of
  /// failing on the first question.
  final bool isConfigured;

  bool get isEmpty => messages.isEmpty;

  AssistantState copyWith({
    List<ChatMessage>? messages,
    bool? isWaiting,
    bool? isConfigured,
  }) {
    return AssistantState(
      messages: messages ?? this.messages,
      isWaiting: isWaiting ?? this.isWaiting,
      isConfigured: isConfigured ?? this.isConfigured,
    );
  }
}

/// Owns the conversation.
///
/// The snapshot is read fresh for each question rather than captured when the
/// screen opened, so an answer always describes what the dashboard currently
/// shows. Asking about data that has since changed would be worse than useless
/// in a monitoring tool.
class AssistantNotifier extends Notifier<AssistantState> {
  late final AssistantRepository _repository = ref.read(
    assistantRepositoryProvider,
  );

  @override
  AssistantState build() {
    _checkConfigured();
    return const AssistantState();
  }

  Future<void> _checkConfigured() async {
    final configured = await _repository.isConfigured();
    state = state.copyWith(isConfigured: configured);
  }

  /// Call when returning from Settings, in case a key was just added.
  Future<void> refreshConfiguration() => _checkConfigured();

  Future<void> send(String question) async {
    final trimmed = question.trim();
    if (trimmed.isEmpty || state.isWaiting) return;

    final history = state.messages;
    state = state.copyWith(
      messages: [...history, ChatMessage.user(trimmed)],
      isWaiting: true,
    );

    final snapshot = ref.read(healthSnapshotProvider).value;
    if (snapshot == null) {
      _appendFailure(
        'No project data has loaded yet, so there is nothing to answer '
        'questions about. Open Health and try again once it has.',
      );
      return;
    }

    try {
      final answer = await _repository.ask(
        question: trimmed,
        context: SnapshotBrief.build(snapshot),
        history: history,
      );
      state = state.copyWith(
        messages: [...state.messages, ChatMessage.assistant(answer)],
        isWaiting: false,
      );
    } catch (error) {
      _appendFailure(failureFromException(error).message);
    }
  }

  void clear() => state = state.copyWith(messages: const [], isWaiting: false);

  void _appendFailure(String message) {
    state = state.copyWith(
      messages: [...state.messages, ChatMessage.failure(message)],
      isWaiting: false,
    );
  }
}

/// Questions offered on the empty screen.
///
/// Chosen to show what the assistant is actually for — reading the data and
/// the reasoning behind it — rather than what a chat box could theoretically
/// be asked.
const assistantSuggestions = <String>[
  'Which project is in the most trouble, and why?',
  'Is any squad over capacity?',
  'How much has load-shedding cost us this week?',
  'What should I look at first today?',
];

/// Snapshot type re-exported so screens importing this file do not also need
/// the repository import just to name it.
typedef AssistantSnapshot = HealthSnapshot;
