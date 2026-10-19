import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/errors/failure.dart';
import '../../models/conversation.dart';
import '../../models/message.dart';
import '../../models/messaging_rules.dart';
import '../../routing/app_router.dart';
import '../../routing/routes.dart';
import '../../state/auth_notifier.dart';
import '../../state/providers.dart';
import '../../theme/tokens.dart';
import '../../theme/typography.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/error_state.dart';
import '../../widgets/message_composer.dart';
import '../../widgets/message_tile.dart';
import 'messaging_labels.dart';

/// One conversation: its messages, and a box to write in.
///
/// The conversation is read from the live inbox rather than passed in, so if
/// somebody takes you out of a group while you are looking at it, the screen
/// says so instead of leaving a box you can no longer send from.
class ConversationScreen extends ConsumerStatefulWidget {
  const ConversationScreen({super.key, required this.conversationId});

  final String conversationId;

  @override
  ConsumerState<ConversationScreen> createState() => _ConversationScreenState();
}

class _ConversationScreenState extends ConsumerState<ConversationScreen> {
  final _input = TextEditingController();

  @override
  void dispose() {
    _input.dispose();
    super.dispose();
  }

  void _send() {
    if (MessagingRules.problemWithMessage(_input.text) != null) return;

    final body = _input.text.trim();
    _input.clear();

    // Not awaited. Offline, Firestore holds the write and the message already
    // shows as sending, so the screen must not wait on a confirmation that may
    // be hours away.
    unawaited(_post(body));
  }

  Future<void> _post(String body) async {
    final messenger = ScaffoldMessenger.of(context);

    try {
      await ref
          .read(messagingRepositoryProvider)
          .send(conversationId: widget.conversationId, body: body);
    } catch (error) {
      // Put the words back, so a failed send never costs someone what they
      // wrote. Skipped if they have started typing something else.
      if (mounted && _input.text.isEmpty) _input.text = body;
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            describeMessagingFailure(
              error,
              whenFailed: 'Your message did not send.',
            ),
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(currentUserProvider);
    final inbox = ref.watch(conversationsProvider);
    final people = peopleById(ref.watch(directoryProvider).value ?? const []);

    final conversation = inbox.value
        ?.where((c) => c.id == widget.conversationId)
        .firstOrNull;

    if (user == null || conversation == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Conversation')),
        // Loaded but not in the list means this person is no longer a member.
        body: inbox.hasValue
            ? EmptyState(
                icon: Icons.lock_outline,
                headline: 'You are not in this conversation',
                body:
                    'You were removed, or it does not exist. You can still '
                    'message anybody directly.',
                actionLabel: 'Back to messages',
                onAction: () => Navigator.of(context).popUntil(
                  (route) =>
                      route.settings.name == Routes.messages || route.isFirst,
                ),
              )
            : const _Loading(),
      );
    }

    final messages = ref.watch(conversationMessagesProvider(conversation.id));

    return Scaffold(
      appBar: AppBar(
        title: Text(
          conversationTitle(conversation, myId: user.id, people: people),
        ),
        actions: [
          if (conversation.isGroup)
            IconButton(
              onPressed: () => Navigator.of(context).pushNamed(
                Routes.groupMembers,
                arguments: ConversationArgs(conversationId: conversation.id),
              ),
              icon: const Icon(Icons.groups_outlined),
              tooltip: 'Members',
            ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: _Thread(
              conversation: conversation,
              messages: messages.value,
              error: messages.hasError ? messages.error : null,
              myId: user.id,
              onRetry: () =>
                  ref.invalidate(conversationMessagesProvider(conversation.id)),
            ),
          ),
          MessageComposer(
            controller: _input,
            onSend: _send,
            hint: conversation.isGroup
                ? 'Message the group'
                : 'Write a message',
          ),
        ],
      ),
    );
  }
}

class _Loading extends StatelessWidget {
  const _Loading();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: SizedBox(
        width: 20,
        height: 20,
        child: CircularProgressIndicator(strokeWidth: 2, color: Tokens.slate),
      ),
    );
  }
}

class _Thread extends StatelessWidget {
  const _Thread({
    required this.conversation,
    required this.messages,
    required this.error,
    required this.myId,
    required this.onRetry,
  });

  final Conversation conversation;
  final List<Message>? messages;
  final Object? error;
  final String myId;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final list = messages;

    if (list == null) {
      if (error != null) {
        return ErrorState(
          failure: failureFromException(error!),
          onRetry: onRetry,
        );
      }
      return const _Loading();
    }

    if (list.isEmpty) {
      // An empty conversation is an invitation, not a blank.
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(Tokens.space5),
          child: Text(
            conversation.isGroup
                ? 'Nobody has said anything in this group yet. Start it off.'
                : 'No messages yet. Say hello.',
            style: AppType.bodyMuted,
            textAlign: TextAlign.center,
          ),
        ),
      );
    }

    // Reversed, so the newest message sits at the bottom next to the box and
    // the conversation opens there without any scrolling.
    return ListView.separated(
      reverse: true,
      padding: const EdgeInsets.all(Tokens.space4),
      itemCount: list.length,
      separatorBuilder: (context, index) => const Padding(
        padding: EdgeInsets.symmetric(vertical: Tokens.space3),
        child: Divider(height: Tokens.hairline),
      ),
      itemBuilder: (context, index) {
        final message = list[list.length - 1 - index];
        return MessageTile(message: message, isMine: message.senderId == myId);
      },
    );
  }
}
