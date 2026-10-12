import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/errors/failure.dart';
import '../models/comment.dart';
import '../models/signal.dart';
import '../state/auth_notifier.dart';
import '../state/providers.dart';
import '../theme/tokens.dart';
import '../theme/typography.dart';
import '../widgets/comment_tile.dart';
import '../widgets/error_state.dart';
import '../widgets/panel.dart';
import '../widgets/signal_card.dart';

/// A warning and the conversation about it, in one place.
///
/// The point is that the discussion about why something went critical lives
/// next to the signal that raised it, not in a group chat where it scrolls
/// away. It is scoped to one signal and nothing more: there is no inbox, no
/// notification feed and no way to talk about anything that is not a warning.
class SignalThreadScreen extends ConsumerStatefulWidget {
  const SignalThreadScreen({
    super.key,
    required this.signal,
    required this.projectName,
  });

  final Signal signal;
  final String projectName;

  @override
  ConsumerState<SignalThreadScreen> createState() => _SignalThreadScreenState();
}

class _SignalThreadScreenState extends ConsumerState<SignalThreadScreen> {
  final _input = TextEditingController();

  @override
  void dispose() {
    _input.dispose();
    super.dispose();
  }

  void _send() {
    if (CommentRules.problemWith(_input.text) != null) return;

    final body = _input.text.trim();
    _input.clear();

    // Not awaited. Offline, Firestore holds the write and the comment already
    // shows as sending, so the screen must not wait on a confirmation that may
    // be hours away.
    unawaited(_post(body));
  }

  Future<void> _post(String body) async {
    final messenger = ScaffoldMessenger.of(context);

    try {
      await ref
          .read(commentRepositoryProvider)
          .add(signalId: widget.signal.id, body: body);
    } catch (error) {
      // Put the words back, so a failed send never costs someone what they
      // wrote. Skipped if they have started typing something else.
      if (mounted && _input.text.isEmpty) _input.text = body;
      messenger.showSnackBar(SnackBar(content: Text(_sendFailure(error))));
    }
  }

  Future<void> _confirmDelete(Comment comment) async {
    final messenger = ScaffoldMessenger.of(context);
    final repository = ref.read(commentRepositoryProvider);

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Delete this comment?', style: AppType.heading),
        content: Text(
          'It disappears for everyone on the team.',
          style: AppType.bodyMuted,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Keep it'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    // Not awaited for the same reason as sending: offline, the thread already
    // reflects the deletion.
    unawaited(
      repository
          .delete(signalId: widget.signal.id, commentId: comment.id)
          .catchError((Object error) {
            messenger.showSnackBar(
              SnackBar(content: Text(_deleteFailure(error))),
            );
          }),
    );
  }

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(signalCommentsProvider(widget.signal.id));
    final auth = ref.watch(authNotifierProvider);
    final myId = auth is SignedIn ? auth.user.id : null;

    // .value keeps the last good thread on screen through a transient error,
    // which is what an app built for flaky connectivity wants.
    final comments = async.value;

    return Scaffold(
      appBar: AppBar(title: const Text('Signal')),
      body: Column(
        children: [
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(
                Tokens.space4,
                Tokens.space2,
                Tokens.space4,
                Tokens.space5,
              ),
              children: [
                SignalCard(
                  signal: widget.signal,
                  projectName: widget.projectName,
                ),
                const SizedBox(height: Tokens.space3),
                Panel(
                  title: 'Discussion',
                  trailing: comments == null || comments.isEmpty
                      ? null
                      : Padding(
                          padding: const EdgeInsets.only(right: Tokens.space1),
                          child: Text(
                            '${comments.length}',
                            style: AppType.data,
                          ),
                        ),
                  child: _Thread(
                    comments: comments,
                    error: async.hasError ? async.error : null,
                    myId: myId,
                    onDelete: _confirmDelete,
                    onRetry: () => ref.invalidate(
                      signalCommentsProvider(widget.signal.id),
                    ),
                  ),
                ),
              ],
            ),
          ),
          _Composer(controller: _input, onSend: _send),
        ],
      ),
    );
  }

  /// Says what went wrong and what to do, never just that something did.
  static String _sendFailure(Object error) {
    return switch (failureFromException(error)) {
      PermissionFailure() =>
        'Your comment did not send. Your account cannot comment here.',
      AuthFailure() => 'Sign in to join the discussion.',
      NetworkFailure() =>
        'Your comment did not send. Check your connection and try again.',
      DataFailure() => 'Your comment did not send. Try again.',
      // Carries its own message, already written for the person reading it.
      ValidationFailure(:final message) => message,
    };
  }

  static String _deleteFailure(Object error) {
    return switch (failureFromException(error)) {
      PermissionFailure() =>
        'Only the person who wrote a comment can delete it.',
      AuthFailure() => 'Sign in to delete a comment.',
      NetworkFailure() =>
        'The comment was not deleted. Check your connection and try again.',
      DataFailure() => 'The comment was not deleted. Try again.',
      ValidationFailure(:final message) => message,
    };
  }
}

class _Thread extends StatelessWidget {
  const _Thread({
    required this.comments,
    required this.error,
    required this.myId,
    required this.onDelete,
    required this.onRetry,
  });

  final List<Comment>? comments;
  final Object? error;
  final String? myId;
  final ValueChanged<Comment> onDelete;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final list = comments;

    if (list == null) {
      if (error != null) {
        return ErrorState(
          failure: failureFromException(error!),
          onRetry: onRetry,
        );
      }
      return const Padding(
        padding: EdgeInsets.all(Tokens.space4),
        child: Center(
          child: SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: Tokens.slate,
            ),
          ),
        ),
      );
    }

    if (list.isEmpty) {
      // An empty thread is an invitation, not a blank.
      return Text(
        'Nobody has said anything yet. Add what you know about why this '
        'fired, or what you are doing about it.',
        style: AppType.bodyMuted,
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (var i = 0; i < list.length; i++) ...[
          if (i > 0)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: Tokens.space3),
              child: Divider(height: Tokens.hairline),
            ),
          CommentTile(
            comment: list[i],
            // Only your own, and only once the server has it: deleting
            // something still queued on this device has nothing to delete yet.
            onDelete: list[i].authorId == myId && !list[i].isPending
                ? () => onDelete(list[i])
                : null,
          ),
        ],
      ],
    );
  }
}

class _Composer extends StatelessWidget {
  const _Composer({required this.controller, required this.onSend});

  final TextEditingController controller;
  final VoidCallback onSend;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(
        Tokens.space4,
        Tokens.space2,
        Tokens.space4,
        Tokens.space4,
      ),
      decoration: const BoxDecoration(
        border: Border(top: BorderSide(color: Tokens.rule)),
      ),
      child: SafeArea(
        top: false,
        child: ValueListenableBuilder<TextEditingValue>(
          valueListenable: controller,
          builder: (context, value, _) {
            final length = CommentRules.lengthOf(value.text);
            final canSend = CommentRules.problemWith(value.text) == null;
            final nearLimit = length >= CommentRules.maxLength * 0.9;

            return Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Expanded(
                      child: TextField(
                        controller: controller,
                        style: AppType.body,
                        minLines: 1,
                        maxLines: 5,
                        textCapitalization: TextCapitalization.sentences,
                        decoration: InputDecoration(
                          hintText: 'Add to the discussion',
                          hintStyle: AppType.bodyMuted,
                          filled: true,
                          fillColor: Tokens.seam,
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: Tokens.space3,
                            vertical: Tokens.space3,
                          ),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(
                              Tokens.radiusSm,
                            ),
                            borderSide: const BorderSide(color: Tokens.rule),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(
                              Tokens.radiusSm,
                            ),
                            borderSide: const BorderSide(color: Tokens.rule),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(
                              Tokens.radiusSm,
                            ),
                            borderSide: const BorderSide(
                              color: Tokens.beacon,
                              width: 1.5,
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: Tokens.space2),
                    IconButton(
                      onPressed: canSend ? onSend : null,
                      icon: const Icon(Icons.arrow_upward),
                      tooltip: 'Post comment',
                      style: IconButton.styleFrom(
                        backgroundColor: canSend ? Tokens.beacon : Tokens.rule,
                        foregroundColor: canSend ? Tokens.shaft : Tokens.slate,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(Tokens.radiusSm),
                        ),
                      ),
                    ),
                  ],
                ),
                // The count appears only when it matters, and says so in
                // words: over the limit is stated, not just coloured.
                if (nearLimit) ...[
                  const SizedBox(height: Tokens.space1),
                  Text(
                    length > CommentRules.maxLength
                        ? '${length - CommentRules.maxLength} over the '
                              '${CommentRules.maxLength} character limit'
                        : '$length of ${CommentRules.maxLength} characters',
                    style: AppType.data.copyWith(
                      color: length > CommentRules.maxLength
                          ? Tokens.ember
                          : Tokens.slate,
                    ),
                    textAlign: TextAlign.end,
                  ),
                ],
              ],
            );
          },
        ),
      ),
    );
  }
}
