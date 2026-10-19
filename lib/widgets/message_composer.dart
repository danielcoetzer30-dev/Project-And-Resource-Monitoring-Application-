import 'package:flutter/material.dart';

import '../models/messaging_rules.dart';
import '../theme/tokens.dart';
import '../theme/typography.dart';

/// The field styling messaging screens share with the rest of the app's forms.
InputDecoration messagingInputDecoration(String hint) {
  OutlineInputBorder border(Color color, [double width = 1]) {
    return OutlineInputBorder(
      borderRadius: BorderRadius.circular(Tokens.radiusSm),
      borderSide: BorderSide(color: color, width: width),
    );
  }

  return InputDecoration(
    hintText: hint,
    hintStyle: AppType.bodyMuted,
    filled: true,
    fillColor: Tokens.seam,
    contentPadding: const EdgeInsets.symmetric(
      horizontal: Tokens.space3,
      vertical: Tokens.space3,
    ),
    border: border(Tokens.rule),
    enabledBorder: border(Tokens.rule),
    focusedBorder: border(Tokens.beacon, 1.5),
  );
}

/// The box a message is written in.
///
/// The send button stays off until the message can actually be sent, and the
/// character count appears only near the limit, stated in words so it never
/// relies on colour alone.
class MessageComposer extends StatelessWidget {
  const MessageComposer({
    super.key,
    required this.controller,
    required this.onSend,
    this.hint = 'Write a message',
  });

  final TextEditingController controller;
  final VoidCallback onSend;
  final String hint;

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
            final length = MessagingRules.lengthOf(value.text);
            final canSend =
                MessagingRules.problemWithMessage(value.text) == null;
            final limit = MessagingRules.maxMessageLength;
            final nearLimit = length >= limit * 0.9;

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
                        decoration: messagingInputDecoration(hint),
                      ),
                    ),
                    const SizedBox(width: Tokens.space2),
                    IconButton(
                      onPressed: canSend ? onSend : null,
                      icon: const Icon(Icons.arrow_upward),
                      tooltip: 'Send message',
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
                if (nearLimit) ...[
                  const SizedBox(height: Tokens.space1),
                  Text(
                    length > limit
                        ? '${length - limit} over the $limit character limit'
                        : '$length of $limit characters',
                    style: AppType.data.copyWith(
                      color: length > limit ? Tokens.ember : Tokens.slate,
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
