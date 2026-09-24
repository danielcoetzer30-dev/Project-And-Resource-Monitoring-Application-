import 'package:cloud_firestore/cloud_firestore.dart';

import '../../models/health_state.dart';
import '../../models/project.dart';
import '../../widgets/health_seam.dart';

abstract final class ProjectDto {
  static Project fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? <String, dynamic>{};

    final factorList = data['factors'] as List<dynamic>? ?? const [];
    final seamList = data['seam'] as List<dynamic>? ?? const [];

    return Project(
      id: doc.id,
      name: data['name'] as String? ?? 'Unnamed project',
      client: data['client'] as String? ?? '',
      squadId: data['squadId'] as String? ?? '',
      score: (data['score'] as num?)?.toDouble() ?? 0,
      factors: factorList
          .map((item) => _factorFromMap(item as Map<String, dynamic>))
          .toList(),
      seam: seamList
          .map((item) => _segmentFromMap(item as Map<String, dynamic>))
          .toList(),
      openSignals: (data['openSignals'] as num?)?.toInt() ?? 0,
      budgetBurn: (data['budgetBurn'] as num?)?.toDouble() ?? 0,
      scheduleDaysRemaining:
          (data['scheduleDaysRemaining'] as num?)?.toInt() ?? 0,
      loadSheddingHoursLost:
          (data['loadSheddingHoursLost'] as num?)?.toDouble() ?? 0,
    );
  }

  static Map<String, dynamic> toMap(Project project) {
    return {
      'name': project.name,
      'client': project.client,
      'squadId': project.squadId,
      'score': project.score,
      'factors': project.factors.map(_factorToMap).toList(),
      'seam': project.seam.map(_segmentToMap).toList(),
      'openSignals': project.openSignals,
      'budgetBurn': project.budgetBurn,
      'scheduleDaysRemaining': project.scheduleDaysRemaining,
      'loadSheddingHoursLost': project.loadSheddingHoursLost,
      'updatedAt': FieldValue.serverTimestamp(),
    };
  }

  // --- Nested types ---------------------------------------------------------
  // Factors and seam segments are stored inline on the project document rather
  // than as subcollections. They are always read together with the project and
  // never queried on their own, so a subcollection would cost extra reads for
  // no benefit.

  static HealthFactor _factorFromMap(Map<String, dynamic> map) {
    return HealthFactor(
      name: map['name'] as String? ?? '',
      value: (map['value'] as num?)?.toDouble() ?? 0,
      weight: (map['weight'] as num?)?.toDouble() ?? 0,
      detail: map['detail'] as String? ?? '',
    );
  }

  static Map<String, dynamic> _factorToMap(HealthFactor factor) {
    return {
      'name': factor.name,
      'value': factor.value,
      'weight': factor.weight,
      'detail': factor.detail,
    };
  }

  static SeamSegment _segmentFromMap(Map<String, dynamic> map) {
    return SeamSegment(
      state: HealthState.fromName(map['state'] as String?),
      periodLabel: map['periodLabel'] as String? ?? '',
      flagged: map['flagged'] as bool? ?? false,
    );
  }

  static Map<String, dynamic> _segmentToMap(SeamSegment segment) {
    return {
      'state': segment.state.name,
      'periodLabel': segment.periodLabel,
      'flagged': segment.flagged,
    };
  }
}
