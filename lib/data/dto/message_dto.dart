import 'package:cloud_firestore/cloud_firestore.dart';

import '../../models/app_user.dart';
import '../../models/message.dart';

abstract final class MessageDto {
  /// Longest sender name the security rules accept.
  static const maxSenderNameLength = 80;

  static Message fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? <String, dynamic>{};
    final name = data['senderName'] as String? ?? '';

    return Message(
      id: doc.id,
      body: data['body'] as String? ?? '',
      senderId: data['senderId'] as String? ?? '',
      senderName: name.isEmpty ? 'A teammate' : name,
      // Null while the write is pending on this device; shown as "Sending…"
      // rather than with a time, so the fallback is never displayed as real.
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      isPending: doc.metadata.hasPendingWrites,
    );
  }

  /// The map for a new message. Exactly these four fields: the security rules
  /// refuse a message carrying anything else.
  static Map<String, dynamic> toNewMap({
    required String body,
    required AppUser sender,
  }) {
    final name = sender.displayName;

    return {
      'body': body,
      'senderId': sender.id,
      'senderName': name.length > maxSenderNameLength
          ? name.substring(0, maxSenderNameLength)
          : name,
      'createdAt': FieldValue.serverTimestamp(),
    };
  }
}
