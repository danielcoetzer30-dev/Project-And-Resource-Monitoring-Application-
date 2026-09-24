import 'package:cloud_firestore/cloud_firestore.dart';

import '../../models/health_state.dart';
import '../../models/signal.dart';

abstract final class SignalDto {
  static Signal fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? <String, dynamic>{};
    return Signal(
      id: doc.id,
      title: data['title'] as String? ?? '',
      // Falls back to a readable string rather than an empty one: a signal
      // with no reasoning is the exact thing this field exists to prevent.
      because: data['because'] as String? ?? 'No reasoning recorded.',
      severity: HealthState.fromName(data['severity'] as String?),
      projectId: data['projectId'] as String? ?? '',
      raisedAt: (data['raisedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      infrastructureRelated: data['infrastructureRelated'] as bool? ?? false,
    );
  }

  static Map<String, dynamic> toMap(Signal signal) {
    return {
      'title': signal.title,
      'because': signal.because,
      'severity': signal.severity.name,
      'projectId': signal.projectId,
      'raisedAt': Timestamp.fromDate(signal.raisedAt),
      'infrastructureRelated': signal.infrastructureRelated,
    };
  }
}
