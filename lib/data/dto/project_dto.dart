import 'package:cloud_firestore/cloud_firestore.dart';

import '../../models/health_state.dart';
import '../../models/project.dart';
import '../../models/seam_segment.dart';

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
      factors: factorsFrom(factorList),
      seam: seamFrom(seamList),
      openSignals: (data['openSignals'] as num?)?.toInt() ?? 0,
      budgetBurn: (data['budgetBurn'] as num?)?.toDouble() ?? 0,
      scheduleDaysRemaining:
          (data['scheduleDaysRemaining'] as num?)?.toInt() ?? 0,
      loadSheddingHoursLost:
          (data['loadSheddingHoursLost'] as num?)?.toDouble() ?? 0,
      // Default to 0 and 1 rather than guessing. A document written before
      // these existed produces no forecast instead of a wrong one.
      scheduleTotalDays: (data['scheduleTotalDays'] as num?)?.toInt() ?? 0,
      velocityRatio: (data['velocityRatio'] as num?)?.toDouble() ?? 1,
      isArchived: data['isArchived'] as bool? ?? false,
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
      'scheduleTotalDays': project.scheduleTotalDays,
      'velocityRatio': project.velocityRatio,
      'isArchived': project.isArchived,
      'updatedAt': FieldValue.serverTimestamp(),
    };
  }

  // --- Nested types ---------------------------------------------------------
  // Factors and seam segments are stored inline on the project document rather
  // than as subcollections. They are always read together with the project and
  // never queried on their own, so a subcollection would cost extra reads for
  // no benefit.

  /// Factors from a stored array, skipping anything that is not a map.
  ///
  /// Every scalar above falls back to a default rather than throwing, and
  /// these do the same, because the cost of throwing here is not one bad
  /// field. This runs inside the projects listener, where an exception is not
  /// caught by the stream's onError: it would leave the whole collection
  /// unparsed and every screen silently stale. A document hand-edited in the
  /// Firebase console is enough to produce one.
  static List<HealthFactor> factorsFrom(List<dynamic> items) {
    return [
      for (final item in items)
        if (item is Map<String, dynamic>) _factorFromMap(item),
    ];
  }

  /// Seam segments from a stored array. See [factorsFrom] on why it skips
  /// rather than throws.
  static List<SeamSegment> seamFrom(List<dynamic> items) {
    return [
      for (final item in items)
        if (item is Map<String, dynamic>) _segmentFromMap(item),
    ];
  }

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
