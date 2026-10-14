import 'package:test/test.dart';

import 'package:keel/models/health_state.dart';
import 'package:keel/models/project.dart';
import 'package:keel/models/seam_segment.dart';
import 'package:keel/services/health_scoring/health_score_engine.dart';
import 'package:keel/services/ingestion/anonymiser.dart';
import 'package:keel/services/ingestion/ingestion_service.dart';
import 'package:keel/services/signal_engine.dart';

/// Guards the property that makes server-side ingestion possible at all: the
/// scoring and anonymising path must compile and run without Flutter, because
/// a scheduled job has no Flutter engine to run under.
///
/// This file is deliberately a `package:test` test rather than a
/// `flutter_test` one. If someone reintroduces a Flutter import anywhere in
/// the chain below, this stops compiling — which is the warning.
void main() {
  test('scoring and ingestion run without Flutter', () {
    expect(HealthState.fromScore(28), HealthState.critical);
    expect(HealthState.fromScore(80), HealthState.onTrack);

    // Named so the imports above are load-bearing rather than decorative.
    const anonymiser = Anonymiser(squadOfAuthor: {});
    expect(anonymiser.minimumContributors, greaterThanOrEqualTo(2));
    expect(HealthScoreEngine.standard(), isA<HealthScoreEngine>());
    expect(const SignalEngine(), isA<SignalEngine>());
    expect(
      const SeamSegment(state: HealthState.watch, periodLabel: '12 Jul').state,
      HealthState.watch,
    );
    expect(IngestionService, isNotNull);
    expect(HealthFactor, isNotNull);
  });
}
