import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/directory_entry.dart';
import '../../models/messaging_rules.dart';
import '../../routing/app_router.dart';
import '../../routing/routes.dart';
import '../../state/auth_notifier.dart';
import '../../state/providers.dart';
import '../../theme/tokens.dart';
import '../../theme/typography.dart';
import '../../widgets/message_composer.dart';
import '../../widgets/panel.dart';
import 'messaging_labels.dart';

/// Name a group and choose who is in it.
///
/// Reached only by leads and managers: the router shows everyone else a
/// "no permission" page, and the security rules refuse the write regardless.
class NewGroupScreen extends ConsumerStatefulWidget {
  const NewGroupScreen({super.key});

  @override
  ConsumerState<NewGroupScreen> createState() => _NewGroupScreenState();
}

class _NewGroupScreenState extends ConsumerState<NewGroupScreen> {
  final _name = TextEditingController();
  final _selected = <String>{};
  var _creating = false;

  /// The creator takes one place, so this many others fit.
  static const _maxOthers = MessagingRules.maxGroupSize - 1;

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  Future<void> _create() async {
    if (_creating || MessagingRules.problemWithGroupName(_name.text) != null) {
      return;
    }
    setState(() => _creating = true);

    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);

    try {
      final id = await ref
          .read(messagingRepositoryProvider)
          .createGroup(name: _name.text, memberIds: _selected.toList());
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
              whenFailed:
                  'The group was not set up completely. Check your '
                  'messages before trying again.',
            ),
          ),
        ),
      );
      if (mounted) setState(() => _creating = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final me = ref.watch(currentUserProvider);
    final people = [
      for (final entry
          in ref.watch(directoryProvider).value ?? const <DirectoryEntry>[])
        if (entry.id != me?.id) entry,
    ];

    return Scaffold(
      appBar: AppBar(title: const Text('New group')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(
          Tokens.space4,
          Tokens.space2,
          Tokens.space4,
          Tokens.space7,
        ),
        children: [
          ValueListenableBuilder<TextEditingValue>(
            valueListenable: _name,
            builder: (context, value, _) {
              final canCreate =
                  !_creating &&
                  MessagingRules.problemWithGroupName(value.text) == null;

              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  TextField(
                    controller: _name,
                    style: AppType.body,
                    maxLength: MessagingRules.maxGroupNameLength,
                    textCapitalization: TextCapitalization.sentences,
                    decoration: messagingInputDecoration('Group name'),
                  ),
                  const SizedBox(height: Tokens.space3),
                  Panel(
                    title: 'Add people',
                    padding: EdgeInsets.zero,
                    trailing: Padding(
                      padding: const EdgeInsets.only(right: Tokens.space1),
                      child: Text('${_selected.length}', style: AppType.data),
                    ),
                    child: people.isEmpty
                        ? Padding(
                            padding: const EdgeInsets.all(Tokens.space4),
                            child: Text(
                              'Nobody else is listed yet. You can create the '
                              'group now and add people once they have signed in.',
                              style: AppType.bodyMuted,
                            ),
                          )
                        : Column(
                            children: [
                              for (var i = 0; i < people.length; i++) ...[
                                if (i > 0)
                                  const Divider(height: Tokens.hairline),
                                CheckboxListTile(
                                  value: _selected.contains(people[i].id),
                                  title: Text(
                                    people[i].displayName,
                                    style: AppType.bodyStrong,
                                  ),
                                  subtitle: Text(
                                    people[i].role.label,
                                    style: AppType.bodyMuted,
                                  ),
                                  controlAffinity:
                                      ListTileControlAffinity.leading,
                                  // Once the group is full, only people
                                  // already chosen can be changed.
                                  onChanged:
                                      !_selected.contains(people[i].id) &&
                                          _selected.length >= _maxOthers
                                      ? null
                                      : (checked) => setState(() {
                                          if (checked ?? false) {
                                            _selected.add(people[i].id);
                                          } else {
                                            _selected.remove(people[i].id);
                                          }
                                        }),
                                ),
                              ],
                            ],
                          ),
                  ),
                  const SizedBox(height: Tokens.space5),
                  FilledButton(
                    onPressed: canCreate ? _create : null,
                    style: FilledButton.styleFrom(
                      backgroundColor: Tokens.beacon,
                      foregroundColor: Tokens.shaft,
                      padding: const EdgeInsets.symmetric(
                        vertical: Tokens.space4,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(Tokens.radiusSm),
                      ),
                    ),
                    child: Text(
                      _creating ? 'Creating…' : 'Create group',
                      style: AppType.bodyStrong.copyWith(
                        color: canCreate ? Tokens.shaft : Tokens.slate,
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}
