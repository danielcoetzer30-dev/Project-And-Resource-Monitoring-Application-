import 'package:cloud_firestore/cloud_firestore.dart';

import '../../models/squad.dart';

/// Converts between a Firestore document and a Squad.
///
/// DTOs exist so Firestore types stay out of the models. Nothing in lib/models
/// imports cloud_firestore, which is what lets the domain be tested without a
/// backend and swapped to a different one later.

abstract final class SquadDto {
  static Squad fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? <String, dynamic>{};
    return Squad(
      id: doc.id,
      name: data['name'] as String? ?? 'Unnamed squad',
      headcount: (data['headcount'] as num?)?.toInt() ?? 0,
      capacityUsed: (data['capacityUsed'] as num?)?.toDouble() ?? 0.0,
      activeProjectCount: (data['activeProjectCount'] as num?)?.toInt() ?? 0,
      velocityTrend: (data['velocityTrend'] as num?)?.toDouble() ?? 0.0,
    );
  }

  static Map<String, dynamic> toMap(Squad squad) {
    return {
      'name': squad.name,
      'headcount': squad.headcount,
      'capacityUsed': squad.capacityUsed,
      'activeProjectCount': squad.activeProjectCount,
      'velocityTrend': squad.velocityTrend,
      'updatedAt': FieldValue.serverTimestamp(),
    };
  }
}
