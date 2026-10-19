import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/app_user.dart';
import '../../models/conversation.dart';
import '../../models/directory_entry.dart';
import '../../models/messaging_rules.dart';
import '../../routing/routes.dart';
import '../../state/auth_notifier.dart';
import '../../state/providers.dart';
import '../../theme/tokens.dart';
import '../../theme/typography.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/panel.dart';
import 'messaging_labels.dart';

/// Who is in a group, and who may take whom out.
///
/// A remove control appears only beside people the signed-in person outranks,
/// which is the rule from [MessagingRules]: a manager can remove a lead or a
/// developer, a lead can remove a developer, and nobody can remove their own
/// rank or above. Everybody can leave. The security rules decide the same thing
/// from the two people's real roles, so this screen is the polite layer and not
/// the only one.
class GroupMembersScreen extends ConsumerWidget {
  const GroupMembersScreen({super.key, required this.conversationId});

  final String conversationId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final me = ref.watch(currentUserProvider);
    final inbox = ref.watch(conversationsProvider);
    final directory = ref.watch(directoryProvider).value ?? const [];
    final people = peopleById(directory);

    final conversation = inbox.value
        ?.where((c) => c.id == conversationId)
        .firstOrNull;

    if (me == null || conversation == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Members')),
        body: inbox.hasValue
            ? const EmptyState(
                icon: Icons.lock_outline,
                headline: 'You are not in this group',
                body: 'You were removed from it, or it no longer exists.',
              )
            : const Center(
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

    // Highest role first, then by name, so who can act on whom reads top down.
    final members =
        [
          for (final id in conversation.memberIds)
            people[id] ??
                DirectoryEntry(
                  id: id,
                  displayName: 'A teammate',
                  role: UserRole.developer,
                ),
        ]..sort((a, b) {
          final byRank = b.role.rank.compareTo(a.role.rank);
          if (byRank != 0) return byRank;
          return a.displayName.toLowerCase().compareTo(
            b.displayName.toLowerCase(),
          );
        });

    return Scaffold(
      appBar: AppBar(title: Text(conversation.name)),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(
          Tokens.space4,
          Tokens.space2,
          Tokens.space4,
          Tokens.space7,
        ),
        children: [
          Panel(
            title: 'Members',
            padding: EdgeInsets.zero,
            trailing: Padding(
              padding: const EdgeInsets.only(right: Tokens.space1),
              child: Text('${members.length}', style: AppType.data),
            ),
            child: Column(
              children: [
                for (var i = 0; i < members.length; i++) ...[
                  if (i > 0) const Divider(height: Tokens.hairline),
                  _MemberRow(
                    person: members[i],
                    isMe: members[i].id == me.id,
                    canRemove:
                        members[i].id != me.id &&
                        MessagingRules.canRemove(
                          actorId: me.id,
                          actorRole: me.role,
                          targetId: members[i].id,
                          targetRole: members[i].role,
                        ),
                    onRemove: () => _confirmRemoval(
                      context,
                      ref,
                      conversation: conversation,
                      person: members[i],
                      leaving: false,
                    ),
                    onLeave: () => _confirmRemoval(
                      context,
                      ref,
                      conversation: conversation,
                      person: members[i],
                      leaving: true,
                    ),
                  ),
                ],
              ],
            ),
          ),
          if (MessagingRules.canAddMembers(me.role)) ...[
            const SizedBox(height: Tokens.space4),
            OutlinedButton.icon(
              onPressed: () => _addPeople(
                context,
                ref,
                conversation: conversation,
                directory: directory,
              ),
              icon: const Icon(Icons.person_add_alt_outlined),
              label: const Text('Add people'),
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _confirmRemoval(
    BuildContext context,
    WidgetRef ref, {
    required Conversation conversation,
    required DirectoryEntry person,
    required bool leaving,
  }) async {
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    final repository = ref.read(messagingRepositoryProvider);

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          leaving ? 'Leave this group?' : 'Remove ${person.displayName}?',
          style: AppType.heading,
        ),
        content: Text(
          leaving
              ? 'You stop seeing its messages. A lead or manager can add you '
                    'back.'
              : '${person.displayName} stops seeing this group\'s messages.',
          style: AppType.bodyMuted,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Keep'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(leaving ? 'Leave' : 'Remove'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    try {
      await repository.removeMember(
        conversationId: conversation.id,
        userId: person.id,
      );
      if (leaving) {
        navigator.popUntil(
          (route) => route.settings.name == Routes.messages || route.isFirst,
        );
      }
    } catch (error) {
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            describeMessagingFailure(
              error,
              whenFailed: leaving
                  ? 'You are still in the group.'
                  : '${person.displayName} is still in the group.',
            ),
          ),
        ),
      );
    }
  }

  Future<void> _addPeople(
    BuildContext context,
    WidgetRef ref, {
    required Conversation conversation,
    required List<DirectoryEntry> directory,
  }) async {
    final messenger = ScaffoldMessenger.of(context);
    final repository = ref.read(messagingRepositoryProvider);

    final candidates = [
      for (final entry in directory)
        if (!conversation.hasMember(entry.id)) entry,
    ];

    final chosen = await showDialog<DirectoryEntry>(
      context: context,
      builder: (context) => SimpleDialog(
        title: Text('Add to ${conversation.name}', style: AppType.heading),
        children: candidates.isEmpty
            ? [
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: Tokens.space5,
                    vertical: Tokens.space3,
                  ),
                  child: Text(
                    'Everyone who is listed is already in this group.',
                    style: AppType.bodyMuted,
                  ),
                ),
              ]
            : [
                for (final person in candidates)
                  SimpleDialogOption(
                    onPressed: () => Navigator.of(context).pop(person),
                    child: Text(
                      '${person.displayName} · ${person.role.label}',
                      style: AppType.body,
                    ),
                  ),
              ],
      ),
    );
    if (chosen == null) return;

    try {
      await repository.addMember(
        conversationId: conversation.id,
        userId: chosen.id,
      );
    } catch (error) {
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            describeMessagingFailure(
              error,
              whenFailed: '${chosen.displayName} was not added.',
            ),
          ),
        ),
      );
    }
  }
}

class _MemberRow extends StatelessWidget {
  const _MemberRow({
    required this.person,
    required this.isMe,
    required this.canRemove,
    required this.onRemove,
    required this.onLeave,
  });

  final DirectoryEntry person;
  final bool isMe;
  final bool canRemove;
  final VoidCallback onRemove;
  final VoidCallback onLeave;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: Tokens.space4,
        vertical: Tokens.space2,
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isMe ? '${person.displayName} (you)' : person.displayName,
                  style: AppType.bodyStrong,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(person.role.label, style: AppType.bodyMuted),
              ],
            ),
          ),
          if (isMe)
            TextButton(onPressed: onLeave, child: const Text('Leave'))
          else if (canRemove)
            IconButton(
              onPressed: onRemove,
              icon: const Icon(Icons.person_remove_outlined, size: 20),
              tooltip: 'Remove ${person.displayName}',
              color: Tokens.slate,
            ),
        ],
      ),
    );
  }
}
