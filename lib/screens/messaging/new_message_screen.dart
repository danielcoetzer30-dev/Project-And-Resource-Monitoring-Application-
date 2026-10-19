import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/errors/failure.dart';
import '../../models/directory_entry.dart';
import '../../routing/app_router.dart';
import '../../routing/routes.dart';
import '../../state/auth_notifier.dart';
import '../../state/providers.dart';
import '../../theme/tokens.dart';
import '../../theme/typography.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/error_state.dart';
import '../../widgets/panel.dart';
import 'messaging_labels.dart';

/// Pick somebody to message directly.
///
/// Open to every role, and it does not matter whether the two people share a
/// group. Choosing somebody opens the conversation you already have with them,
/// or starts one.
class NewMessageScreen extends ConsumerStatefulWidget {
  const NewMessageScreen({super.key});

  @override
  ConsumerState<NewMessageScreen> createState() => _NewMessageScreenState();
}

class _NewMessageScreenState extends ConsumerState<NewMessageScreen> {
  /// Who is being opened, so a second tap cannot start a second conversation.
  String? _openingId;

  Future<void> _open(DirectoryEntry person) async {
    if (_openingId != null) return;
    setState(() => _openingId = person.id);

    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);

    try {
      final id = await ref
          .read(messagingRepositoryProvider)
          .openDirect(person.id);
      unawaited(
        navigator.pushReplacementNamed(
          Routes.conversation,
          arguments: ConversationArgs(conversationId: id),
        ),
      );
    } catch (error) {
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            describeMessagingFailure(
              error,
              whenFailed: 'The conversation did not open.',
            ),
          ),
        ),
      );
      if (mounted) setState(() => _openingId = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    final me = ref.watch(currentUserProvider);
    final async = ref.watch(directoryProvider);
    final people = [
      for (final entry in async.value ?? const <DirectoryEntry>[])
        if (entry.id != me?.id) entry,
    ];

    return Scaffold(
      appBar: AppBar(title: const Text('New message')),
      body: _body(async, people),
    );
  }

  Widget _body(
    AsyncValue<List<DirectoryEntry>> async,
    List<DirectoryEntry> people,
  ) {
    if (async.value == null) {
      if (async.hasError) {
        return ErrorState(
          failure: failureFromException(async.error!),
          onRetry: () => ref.invalidate(directoryProvider),
        );
      }
      return const Center(
        child: SizedBox(
          width: 20,
          height: 20,
          child: CircularProgressIndicator(strokeWidth: 2, color: Tokens.slate),
        ),
      );
    }

    if (people.isEmpty) {
      return const EmptyState(
        icon: Icons.person_outline,
        headline: 'Nobody else is listed yet',
        body:
            'Teammates appear here once they have signed in to the app. '
            'Check back after they have.',
      );
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(
        Tokens.space4,
        Tokens.space2,
        Tokens.space4,
        Tokens.space7,
      ),
      children: [
        Panel(
          padding: EdgeInsets.zero,
          child: Column(
            children: [
              for (var i = 0; i < people.length; i++) ...[
                if (i > 0) const Divider(height: Tokens.hairline),
                InkWell(
                  onTap: _openingId == null ? () => _open(people[i]) : null,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: Tokens.space4,
                      vertical: Tokens.space3,
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.person_outline, color: Tokens.slate),
                        const SizedBox(width: Tokens.space3),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                people[i].displayName,
                                style: AppType.bodyStrong,
                                overflow: TextOverflow.ellipsis,
                              ),
                              Text(
                                people[i].role.label,
                                style: AppType.bodyMuted,
                              ),
                            ],
                          ),
                        ),
                        if (_openingId == people[i].id)
                          const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Tokens.slate,
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}
