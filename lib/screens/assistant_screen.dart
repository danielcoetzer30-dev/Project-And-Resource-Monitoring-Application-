import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/chat_message.dart';
import '../routing/routes.dart';
import '../state/assistant_notifier.dart';
import '../state/providers.dart';
import '../theme/tokens.dart';
import '../theme/typography.dart';
import '../widgets/empty_state.dart';

/// Ask questions about the current data.
///
/// Read-only by design, like the rest of the app. It explains what is on the
/// dashboard; it cannot change a score, and there is nothing here that writes.
class AssistantScreen extends ConsumerStatefulWidget {
  const AssistantScreen({super.key});

  @override
  ConsumerState<AssistantScreen> createState() => _AssistantScreenState();
}

class _AssistantScreenState extends ConsumerState<AssistantScreen> {
  final _input = TextEditingController();
  final _scroll = ScrollController();

  @override
  void dispose() {
    _input.dispose();
    _scroll.dispose();
    super.dispose();
  }

  void _send([String? preset]) {
    final text = preset ?? _input.text;
    if (text.trim().isEmpty) return;

    _input.clear();
    ref.read(assistantProvider.notifier).send(text);

    // Let the new message build before scrolling to it.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scroll.hasClients) return;
      _scroll.animateTo(
        _scroll.position.maxScrollExtent,
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOut,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(assistantProvider);

    if (!state.isConfigured) return const _NeedsKey();

    return Column(
      children: [
        Expanded(
          child: state.isEmpty
              ? _Suggestions(onPick: _send)
              : ListView.builder(
                  controller: _scroll,
                  padding: const EdgeInsets.fromLTRB(
                    Tokens.space4,
                    Tokens.space4,
                    Tokens.space4,
                    Tokens.space2,
                  ),
                  itemCount: state.messages.length + (state.isWaiting ? 1 : 0),
                  itemBuilder: (context, i) {
                    if (i == state.messages.length) return const _Thinking();
                    return _Bubble(message: state.messages[i]);
                  },
                ),
        ),
        _Composer(controller: _input, enabled: !state.isWaiting, onSend: _send),
      ],
    );
  }
}

class _Bubble extends StatelessWidget {
  const _Bubble({required this.message});

  final ChatMessage message;

  @override
  Widget build(BuildContext context) {
    final isUser = message.isUser;

    final background = isUser
        ? Tokens.beacon.withValues(alpha: 0.14)
        : Tokens.seam;
    final border = message.isError
        ? Tokens.flare.withValues(alpha: 0.35)
        : isUser
        ? Tokens.beacon.withValues(alpha: 0.3)
        : Tokens.rule;

    return Padding(
      padding: const EdgeInsets.only(bottom: Tokens.space3),
      child: Row(
        mainAxisAlignment: isUser
            ? MainAxisAlignment.end
            : MainAxisAlignment.start,
        children: [
          Flexible(
            child: Container(
              padding: const EdgeInsets.symmetric(
                horizontal: Tokens.space3,
                vertical: Tokens.space3,
              ),
              decoration: BoxDecoration(
                color: message.isError
                    ? Tokens.flare.withValues(alpha: 0.10)
                    : background,
                borderRadius: BorderRadius.circular(Tokens.radiusMd),
                border: Border.all(color: border),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (message.isError) ...[
                    const Icon(
                      Icons.error_outline,
                      size: 15,
                      color: Tokens.flare,
                    ),
                    const SizedBox(width: Tokens.space2),
                  ],
                  Flexible(
                    child: Text(
                      message.text,
                      style: AppType.body.copyWith(
                        color: message.isError ? Tokens.flare : Tokens.chalk,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Thinking extends StatelessWidget {
  const _Thinking();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: Tokens.space3),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: Tokens.space3,
              vertical: Tokens.space3,
            ),
            decoration: BoxDecoration(
              color: Tokens.seam,
              borderRadius: BorderRadius.circular(Tokens.radiusMd),
              border: Border.all(color: Tokens.rule),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const SizedBox(
                  width: 12,
                  height: 12,
                  child: CircularProgressIndicator(
                    strokeWidth: 1.5,
                    color: Tokens.slate,
                  ),
                ),
                const SizedBox(width: Tokens.space3),
                Text('Reading the data', style: AppType.bodyMuted),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Suggestions extends StatelessWidget {
  const _Suggestions({required this.onPick});

  final void Function(String) onPick;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(Tokens.space4),
      children: [
        const SizedBox(height: Tokens.space5),
        Icon(Icons.forum_outlined, size: 28, color: Tokens.slate),
        const SizedBox(height: Tokens.space4),
        Text(
          'Ask about your projects',
          style: AppType.heading,
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: Tokens.space2),
        Text(
          'It reads the same data the dashboard shows, and explains the '
          'reasoning behind a score rather than just repeating the number.',
          style: AppType.bodyMuted,
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: Tokens.space5),
        for (final suggestion in assistantSuggestions)
          Padding(
            padding: const EdgeInsets.only(bottom: Tokens.space2),
            child: InkWell(
              onTap: () => onPick(suggestion),
              borderRadius: BorderRadius.circular(Tokens.radiusSm),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(Tokens.space3),
                decoration: BoxDecoration(
                  color: Tokens.seam,
                  borderRadius: BorderRadius.circular(Tokens.radiusSm),
                  border: Border.all(color: Tokens.rule),
                ),
                child: Text(suggestion, style: AppType.body),
              ),
            ),
          ),
      ],
    );
  }
}

/// Shown when no API key has been saved.
class _NeedsKey extends ConsumerWidget {
  const _NeedsKey();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return EmptyState(
      icon: Icons.key_outlined,
      headline: 'Add an API key to use the assistant',
      body:
          'The assistant uses your own Anthropic API key, kept on this '
          'device. Nothing is shared with the rest of your team.',
      actionLabel: 'Add a key',
      onAction: () async {
        await Navigator.of(context).pushNamed(Routes.apiKey);
        await ref.read(assistantProvider.notifier).refreshConfiguration();
      },
    );
  }
}

class _Composer extends StatelessWidget {
  const _Composer({
    required this.controller,
    required this.enabled,
    required this.onSend,
  });

  final TextEditingController controller;
  final bool enabled;
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
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Expanded(
              child: TextField(
                controller: controller,
                enabled: enabled,
                style: AppType.body,
                minLines: 1,
                maxLines: 4,
                textInputAction: TextInputAction.send,
                onSubmitted: (_) => onSend(),
                decoration: InputDecoration(
                  hintText: enabled ? 'Ask about your projects' : 'Thinking…',
                  hintStyle: AppType.bodyMuted,
                  filled: true,
                  fillColor: Tokens.seam,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: Tokens.space3,
                    vertical: Tokens.space3,
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(Tokens.radiusSm),
                    borderSide: const BorderSide(color: Tokens.rule),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(Tokens.radiusSm),
                    borderSide: const BorderSide(color: Tokens.rule),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(Tokens.radiusSm),
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
              onPressed: enabled ? onSend : null,
              icon: const Icon(Icons.arrow_upward),
              tooltip: 'Send',
              style: IconButton.styleFrom(
                backgroundColor: enabled ? Tokens.beacon : Tokens.rule,
                foregroundColor: enabled ? Tokens.shaft : Tokens.slate,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(Tokens.radiusSm),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
