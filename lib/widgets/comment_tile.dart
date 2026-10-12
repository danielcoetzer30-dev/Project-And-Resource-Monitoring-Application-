import 'package:flutter/material.dart';

import '../models/comment.dart';
import '../theme/tokens.dart';
import '../theme/typography.dart';
import 'dashboard/dashboard_format.dart';

/// One comment in a signal's discussion.
///
/// [onDelete] is given only for the signed-in user's own comments, so the
/// control is simply absent on everyone else's rather than present and refused.
class CommentTile extends StatelessWidget {
  const CommentTile({super.key, required this.comment, this.onDelete});

  final Comment comment;
  final VoidCallback? onDelete;

  @override
  Widget build(BuildContext context) {
    // A comment written offline says so in words, not just by looking dimmer.
    final when = comment.isPending ? 'Sending…' : agoLabel(comment.createdAt);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                comment.authorName,
                style: AppType.bodyStrong,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            Text(when, style: AppType.data),
            if (onDelete != null)
              IconButton(
                onPressed: onDelete,
                icon: const Icon(Icons.delete_outline, size: 18),
                tooltip: 'Delete comment',
                color: Tokens.slate,
                visualDensity: VisualDensity.compact,
              ),
          ],
        ),
        const SizedBox(height: Tokens.space1),
        Text(comment.body, style: AppType.body),
      ],
    );
  }
}
