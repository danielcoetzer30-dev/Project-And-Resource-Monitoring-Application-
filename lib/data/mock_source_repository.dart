import 'dart:async';

import '../core/errors/exceptions.dart';
import '../models/app_user.dart';
import '../models/ingestion_source.dart';
import 'dto/source_dto.dart';
import 'source_repository.dart';

/// An in-memory [SourceRepository], for tests and for running with no backend.
///
/// Applies the same two refusals as the real one — role, then validity — so a
/// test that passes here cannot rely on something Firestore would reject.
class MockSourceRepository implements SourceRepository {
  MockSourceRepository({
    this.author,
    List<IngestionSource> initial = const [],
  }) {
    _sources.addAll(initial);
  }

  /// Who writes are made as. Null stands for signed out, which cannot write.
  final AppUser? author;

  final _sources = <IngestionSource>[];
  final _changed = StreamController<List<IngestionSource>>.broadcast();

  /// What is stored, for a test to assert on.
  List<IngestionSource> get sources => List.unmodifiable(_sources);

  @override
  Stream<List<IngestionSource>> watch() {
    // Stream.multi, not async*: a listener gets the current value at once and
    // every change after it, which is how Firestore's snapshots() behaves.
    return Stream<List<IngestionSource>>.multi((controller) {
      controller.add(List.unmodifiable(_sources));
      final subscription = _changed.stream.listen(
        controller.add,
        onError: controller.addError,
      );
      controller.onCancel = subscription.cancel;
    });
  }

  @override
  Future<void> connect(IngestionSource source) async {
    _refuseUnlessPermitted();

    final problem = SourceRules.problemWith(source);
    if (problem != null) throw ValidationException(problem);

    final index = _sources.indexWhere((s) => s.id == source.id);
    if (index >= 0 && source.id.isNotEmpty) {
      _sources[index] = source;
    } else {
      // copyWith, not a hand-built copy: this used to rebuild the source
      // field by field and dropped squadId, so every source added through the
      // mock arrived with no squad — which the real repository does not do,
      // and which is the one way a mock can make a passing test worthless.
      _sources.add(
        source.id.isEmpty
            ? source.copyWith(id: 'mock-${_sources.length + 1}')
            : source,
      );
    }

    _emit();
  }

  @override
  Future<void> setEnabled({
    required String sourceId,
    required bool enabled,
  }) async {
    _refuseUnlessPermitted();

    final index = _sources.indexWhere((s) => s.id == sourceId);
    if (index < 0) return;

    // Same bug as in connect above: this dropped squadId, so pausing a source
    // and resuming it detached it from its squad. The real repository updates
    // one field and cannot do that.
    _sources[index] = _sources[index].copyWith(isEnabled: enabled);

    _emit();
  }

  @override
  Future<void> disconnect(String sourceId) async {
    _refuseUnlessPermitted();
    _sources.removeWhere((s) => s.id == sourceId);
    _emit();
  }

  void _emit() {
    if (!_changed.isClosed) _changed.add(List.unmodifiable(_sources));
  }

  void _refuseUnlessPermitted() {
    if (author == null) {
      throw const AuthException('Sign in to change connected sources.');
    }
    if (!author!.canChangeSettings) {
      throw const PermissionException(
        'Only leads and managers can change connected sources.',
      );
    }
  }

  void dispose() => _changed.close();
}
