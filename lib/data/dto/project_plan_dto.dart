import 'package:cloud_firestore/cloud_firestore.dart';

import '../../models/project_plan.dart';

/// Converts between a Firestore document and a [ProjectPlan].
///
/// Every field here is one a person typed. Nothing ingestion produces is
/// written back, so a scoring run and a lead editing a budget cannot
/// overwrite each other.
abstract final class ProjectPlanDto {
  static ProjectPlan fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? <String, dynamic>{};

    return ProjectPlan(
      projectId: doc.id,
      name: data['name'] as String? ?? '',
      client: data['client'] as String? ?? '',
      squadId: data['squadId'] as String? ?? '',
      budgetTotal: (data['budgetTotal'] as num?)?.toDouble() ?? 0,
      budgetSpent: (data['budgetSpent'] as num?)?.toDouble() ?? 0,
      startDate: (data['startDate'] as Timestamp?)?.toDate(),
      endDate: (data['endDate'] as Timestamp?)?.toDate(),
      weeklyHours: (data['weeklyHours'] as num?)?.toDouble() ?? 0,
      // Absent means active. A plan written before archiving existed should
      // keep being scored, not quietly disappear.
      isArchived: data['isArchived'] as bool? ?? false,
    );
  }

  static Map<String, dynamic> toMap(ProjectPlan plan) {
    return {
      'name': plan.name.trim(),
      'client': plan.client.trim(),
      'squadId': plan.squadId,
      'budgetTotal': plan.budgetTotal,
      'budgetSpent': plan.budgetSpent,
      // Null is written rather than omitted: a date cleared on purpose has to
      // reach the document, or the old one stands and the forecast keeps
      // using a schedule nobody believes any more.
      'startDate': plan.startDate == null
          ? null
          : Timestamp.fromDate(plan.startDate!),
      'endDate': plan.endDate == null
          ? null
          : Timestamp.fromDate(plan.endDate!),
      'weeklyHours': plan.weeklyHours,
      'isArchived': plan.isArchived,
    };
  }
}
