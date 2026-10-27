import 'package:flutter_test/flutter_test.dart';
import 'package:prahm/data/dto/project_dto.dart';
import 'package:prahm/models/health_state.dart';

void main() {
  // These arrays are parsed inside the projects listener, where a throw is
  // not caught by the stream's onError and would leave every screen stale.
  group('nested arrays on a project document', () {
    test('a well-formed factor is read in full', () {
      final factors = ProjectDto.factorsFrom([
        {'name': 'Budget burn', 'value': 18, 'weight': 0.25, 'detail': 'tight'},
      ]);

      expect(factors, hasLength(1));
      expect(factors.single.name, 'Budget burn');
      expect(factors.single.value, 18);
      expect(factors.single.weight, 0.25);
      expect(factors.single.detail, 'tight');
    });

    test('an entry that is not a map is skipped, not thrown on', () {
      final factors = ProjectDto.factorsFrom([
        'hand-edited in the console',
        {'name': 'Task velocity', 'value': 31, 'weight': 0.25},
        42,
        null,
      ]);

      expect(factors, hasLength(1));
      expect(factors.single.name, 'Task velocity');
    });

    test('a well-formed seam segment is read in full', () {
      final seam = ProjectDto.seamFrom([
        {'state': 'watch', 'periodLabel': 'Wk 3', 'flagged': true},
      ]);

      expect(seam, hasLength(1));
      expect(seam.single.state, HealthState.watch);
      expect(seam.single.periodLabel, 'Wk 3');
      expect(seam.single.flagged, isTrue);
    });

    test('a malformed seam segment is skipped', () {
      final seam = ProjectDto.seamFrom([
        {'state': 'onTrack', 'periodLabel': 'Wk 1'},
        ['not', 'a', 'map'],
      ]);

      expect(seam, hasLength(1));
      expect(seam.single.periodLabel, 'Wk 1');
    });

    test('an empty array yields no entries', () {
      expect(ProjectDto.factorsFrom(const []), isEmpty);
      expect(ProjectDto.seamFrom(const []), isEmpty);
    });
  });
}
