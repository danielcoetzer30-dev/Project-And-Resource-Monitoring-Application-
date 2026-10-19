import 'package:flutter/material.dart';

import '../models/message.dart';
import '../theme/tokens.dart';
import '../theme/typography.dart';
import 'dashboard/dashboard_format.dart';

/// One message in a conversation.
class MessageTile extends StatelessWidget {
  const MessageTile({super.key, required this.message, required this.isMine});

  final Message message;

  /// True for the signed-in person's own messages, which read "You" rather
  /// than repeating their name back to them.
  final bool isMine;

  @override
  Widget build(BuildContext context) {
    // A message sent offline says so in words, not just by looking dimmer.
    final when = message.isPending ? 'Sending…' : agoLabel(message.createdAt);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                isMine ? 'You' : message.senderName,
                style: AppType.bodyStrong.copyWith(
                  color: isMine ? Tokens.beacon : Tokens.chalk,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            Text(when, style: AppType.data),
          ],
        ),
        const SizedBox(height: Tokens.space1),
        Text(message.body, style: AppType.body),
      ],
    );
  }
}
