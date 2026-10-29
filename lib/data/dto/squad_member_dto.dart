import 'package:cloud_firestore/cloud_firestore.dart';

import '../../models/squad_member.dart';

/// Converts between a Firestore document and a [SquadPlacement].
///
/// A squad id and a list of project ids, and nothing else: the name and role a
/// roster shows are read from the directory, so this collection cannot become
/// a second place a person's details accumulate. The security rules refuse a
/// document carrying anything else.
abstract final class SquadMemberDto {
  static SquadPlacement fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? <String, dynamic>{};

    final ids = data['projectIds'];

    return SquadPlacement(
      userId: doc.id,
      squadId: data['squadId'] as String? ?? '',
      projectIds: ids is List ? ids.whereType<String>().toList() : const [],
    );
  }

  static Map<String, dynamic> toMap(SquadPlacement placement) {
    // The list is left out when empty. The write replaces the whole document,
    // so leaving it out clears any earlier projects, and a plain move still
    // looks exactly like it did before projects existed.
    return {
      'squadId': placement.squadId,
      if (placement.projectIds.isNotEmpty) 'projectIds': placement.projectIds,
    };
  }
}
