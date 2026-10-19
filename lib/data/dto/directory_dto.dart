import 'package:cloud_firestore/cloud_firestore.dart';

import '../../models/app_user.dart';
import '../../models/directory_entry.dart';

abstract final class DirectoryDto {
  static DirectoryEntry fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? <String, dynamic>{};
    final name = data['displayName'] as String? ?? '';

    return DirectoryEntry(
      id: doc.id,
      displayName: name.isEmpty ? 'A teammate' : name,
      role: UserRole.fromName(data['role'] as String? ?? 'developer'),
    );
  }

  /// A person's own entry. Exactly these two fields: the security rules refuse
  /// anything else, and refuse a role that differs from the one on the
  /// person's real `users` document.
  static Map<String, dynamic> toMap(AppUser user) {
    return {'displayName': user.displayName, 'role': user.role.name};
  }
}
