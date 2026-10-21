import 'package:cloud_firestore/cloud_firestore.dart';

import '../../models/squad_member.dart';

/// Converts between a Firestore document and a [SquadPlacement].
///
/// One field, and that is the point: the name and role a roster shows are read
/// from the directory, so this collection cannot become a second place a
/// person's details accumulate. The security rules refuse a document carrying
/// anything else.
abstract final class SquadMemberDto {
  static SquadPlacement fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? <String, dynamic>{};

    return SquadPlacement(
      userId: doc.id,
      squadId: data['squadId'] as String? ?? '',
    );
  }

  static Map<String, dynamic> toMap(SquadPlacement placement) {
    return {'squadId': placement.squadId};
  }
}
