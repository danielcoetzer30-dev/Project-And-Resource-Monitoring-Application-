import 'package:test/test.dart';

import 'package:keel/services/ingestion/firestore_rest.dart';

/// Ingestion and `tool/seed_firestore.js` write the same collections, so they
/// have to agree on how a value is spelled. A mismatch here would not fail
/// loudly — it would write a second, differently shaped document that the app
/// reads as missing data.
void main() {
  group('encoding matches what the app reads back', () {
    test('an integer is a string, as Firestore requires', () {
      // The REST API takes integerValue as a string. Sending a number is
      // accepted and silently stored as a double, which then arrives in the
      // app as 11.0 where a day count was expected.
      expect(FirestoreRest.encode(11), {'integerValue': '11'});
      expect(FirestoreRest.encode(0.94), {'doubleValue': 0.94});
    });

    test('a date goes out as UTC', () {
      final local = DateTime.utc(2026, 10, 14, 6, 30).toLocal();

      final encoded = FirestoreRest.encode(local);

      expect(encoded['timestampValue'], '2026-10-14T06:30:00.000Z');
    });

    test('a seam segment survives a round trip', () {
      const segment = {
        'state': 'atRisk',
        'periodLabel': '12 Jul',
        'flagged': true,
      };

      final encoded = FirestoreRest.encodeFields({
        'seam': [segment],
      });
      final decoded = FirestoreRest.decodeFields(encoded);

      expect(decoded['seam'], [segment]);
    });

    test('a whole project document round trips unchanged', () {
      final original = <String, dynamic>{
        'name': 'Ledger rebuild',
        'score': 28.0,
        'openSignals': 3,
        'budgetBurn': 0.94,
        'scheduleDaysRemaining': 11,
        'velocityRatio': 0.62,
        'updatedAt': DateTime.utc(2026, 10, 14),
        'factors': [
          {'name': 'Budget burn', 'value': 18.0, 'weight': 0.25},
        ],
      };

      final roundTripped = FirestoreRest.decodeFields(
        FirestoreRest.encodeFields(original),
      );

      expect(roundTripped, original);
    });

    test('null is a null, not a missing field', () {
      // A forecast field that cannot be computed means "cannot say". Dropping
      // it instead would leave yesterday's answer in place.
      final decoded = FirestoreRest.decodeFields(
        FirestoreRest.encodeFields({'budgetRunsOutInDays': null}),
      );

      expect(decoded.containsKey('budgetRunsOutInDays'), isTrue);
      expect(decoded['budgetRunsOutInDays'], isNull);
    });
  });
}
