import 'package:cloud_firestore/cloud_firestore.dart';

import '../../models/app_user.dart';
import '../../models/comment.dart';

abstract final class CommentDto {
  /// Longest author name the security rules accept.
  static const maxAuthorNameLength = 80;

  static Comment fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? <String, dynamic>{};
    final name = data['authorName'] as String? ?? '';

    return Comment(
      id: doc.id,
      body: data['body'] as String? ?? '',
      authorId: data['authorId'] as String? ?? '',
      authorName: name.isEmpty ? 'A teammate' : name,
      // The server timestamp is null while a write is still pending on this
      // device. The comment is then shown as "Sending…" rather than with a
      // time, so the fallback is never displayed as if it were real.
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      isPending: doc.metadata.hasPendingWrites,
    );
  }

  /// The map for a new comment. Exactly these four fields: the security rules
  /// refuse a comment carrying anything else.
  static Map<String, dynamic> toNewMap({
    required String body,
    required AppUser author,
  }) {
    final name = author.displayName;

    return {
      'body': body,
      'authorId': author.id,
      'authorName': name.length > maxAuthorNameLength
          ? name.substring(0, maxAuthorNameLength)
          : name,
      'createdAt': FieldValue.serverTimestamp(),
    };
  }
}
