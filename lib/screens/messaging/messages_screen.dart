import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/errors/failure.dart';
import '../../models/conversation.dart';
import '../../models/directory_entry.dart';
import '../../models/messaging_rules.dart';
import '../../routing/app_router.dart';
import '../../routing/routes.dart';
import '../../state/auth_notifier.dart';
import '../../state/providers.dart';
import '../../theme/tokens.dart';
import '../../theme/typography.dart';
import '../../widgets/dashboard/dashboard_format.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/error_state.dart';
import '../../widgets/panel.dart';
import 'messaging_labels.dart';

/// Every conversation the signed-in person is in, most recent first.
///
/// Anybody can start a direct message. Only leads and managers are offered a
/// new group, and the route and the security rules refuse it for a developer
/// as well, so hiding the button is the polite layer and not the only one.
class MessagesScreen extends ConsumerWidget {
  const MessagesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final conversations = ref.watch(conversationsProvider);
    final people = peopleById(ref.watch(directoryProvider).value ?? const []);
    final user = ref.watch(currentUserProvider);
    final canCreateGroup =
        user != null && MessagingRules.canCreateGroup(user.role);

    void newMessage() => Navigator.of(context).pushNamed(Routes.newMessage);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Messages'),
        actions: [
          IconButton(
            onPressed: newMessage,
            icon: const Icon(Icons.edit_outlined),
            tooltip: 'New message',
          ),
          if (canCreateGroup)
            IconButton(
              onPressed: () => Navigator.of(context).pushNamed(Routes.newGroup),
              icon: const Icon(Icons.group_add_outlined),
              tooltip: 'New group',
            ),
        ],
      ),
      body: _body(
        context,
        ref,
        conversations: conversations,
        people: people,
        myId: user?.id ?? '',
        canCreateGroup: canCreateGroup,
        onNewMessage: newMessage,
      ),
    );
  }

  Widget _body(
    BuildContext context,
    WidgetRef ref, {
    required AsyncValue<List<Conversation>> conversations,
    required Map<String, DirectoryEntry> people,
    required String myId,
    required bool canCreateGroup,
    required VoidCallback onNewMessage,
  }) {
    // .value keeps the last good list on screen through a transient error,
    // which is what an app built for flaky connectivity wants.
    final list = conversations.value;

    if (list == null) {
      if (conversations.hasError) {
        return ErrorState(
          failure: failureFromException(conversations.error!),
          onRetry: () => ref.invalidate(conversationsProvider),
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

    if (list.isEmpty) {
      // An empty inbox is an invitation, not a blank.
      return EmptyState(
        icon: Icons.chat_bubble_outline,
        headline: 'No conversations yet',
        body: canCreateGroup
            ? 'Message a teammate, or start a group for a project.'
            : 'Message a teammate to start talking.',
        actionLabel: 'New message',
        onAction: onNewMessage,
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
              for (var i = 0; i < list.length; i++) ...[
                if (i > 0) const Divider(height: Tokens.hairline),
                _ConversationRow(
                  conversation: list[i],
                  title: conversationTitle(list[i], myId: myId, people: people),
                  subtitle: _subtitle(list[i], myId, people),
                  onTap: () => Navigator.of(context).pushNamed(
                    Routes.conversation,
                    arguments: ConversationArgs(conversationId: list[i].id),
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  static String _subtitle(
    Conversation conversation,
    String myId,
    Map<String, DirectoryEntry> people,
  ) {
    if (conversation.isGroup) {
      return plural(conversation.memberIds.length, 'member');
    }
    return people[conversation.otherMemberId(myId)]?.role.label ?? '';
  }
}

class _ConversationRow extends StatelessWidget {
  const _ConversationRow({
    required this.conversation,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final Conversation conversation;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: Tokens.space4,
          vertical: Tokens.space3,
        ),
        child: Row(
          children: [
            Icon(
              conversation.isGroup
                  ? Icons.groups_outlined
                  : Icons.person_outline,
              color: Tokens.slate,
            ),
            const SizedBox(width: Tokens.space3),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: AppType.bodyStrong,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (subtitle.isNotEmpty)
                    Text(subtitle, style: AppType.bodyMuted),
                ],
              ),
            ),
            const SizedBox(width: Tokens.space3),
            Text(agoLabel(conversation.lastActivity), style: AppType.data),
          ],
        ),
      ),
    );
  }
}
