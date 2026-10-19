import 'package:cloud_firestore/cloud_firestore.dart';

import '../../models/app_user.dart';
import '../../models/conversation.dart';

abstract final class ConversationDto {
  static Conversation fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? <String, dynamic>{};
    final lastMessageAt = (data['lastMessageAt'] as Timestamp?)?.toDate();
    final createdAt = (data['createdAt'] as Timestamp?)?.toDate();

    return Conversation(
      id: doc.id,
      kind: ConversationKind.fromName(data['kind'] as String?),
      name: data['name'] as String? ?? '',
      memberIds: (data['memberIds'] as List? ?? const [])
          .whereType<String>()
          .toList(),
      createdBy: data['createdBy'] as String? ?? '',
      // Both are null while a write is still pending on this device, so the
      // fallback is only ever used for a conversation made a moment ago.
      lastActivity: lastMessageAt ?? createdAt ?? DateTime.now(),
    );
  }

  /// A new direct conversation. [firstId] and [secondId] are already in sorted
  /// order, matching [Conversation.directIdFor], which the rules check.
  static Map<String, dynamic> toNewDirect({
    required AppUser creator,
    required String firstId,
    required String secondId,
  }) {
    return {
      'kind': ConversationKind.direct.name,
      'memberIds': [firstId, secondId],
      'createdBy': creator.id,
      'createdAt': FieldValue.serverTimestamp(),
      'lastMessageAt': FieldValue.serverTimestamp(),
    };
  }

  /// A new group, with its creator as the only member. Everyone else is added
  /// one at a time afterwards, because the rules can check one person's
  /// organisation per write but cannot loop over a list.
  static Map<String, dynamic> toNewGroup({
    required AppUser creator,
    required String name,
  }) {
    return {
      'kind': ConversationKind.group.name,
      'name': name,
      'memberIds': [creator.id],
      'createdBy': creator.id,
      'createdAt': FieldValue.serverTimestamp(),
      'lastMessageAt': FieldValue.serverTimestamp(),
    };
  }
}
