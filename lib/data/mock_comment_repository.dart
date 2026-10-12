import 'dart:async';

import '../core/errors/exceptions.dart';
import '../models/app_user.dart';
import '../models/comment.dart';
import 'comment_repository.dart';

/// An in-memory [CommentRepository], for tests and for running the app with no
/// backend.
///
/// Applies the same [CommentRules] as the real one, so a test that passes here
/// cannot be relying on something Firestore would refuse.
class MockCommentRepository implements CommentRepository {
  MockCommentRepository({
    required this.author,
    Map<String, List<Comment>> initial = const {},
  }) {
    for (final entry in initial.entries) {
      _threads[entry.key] = [...entry.value];
    }
  }

  /// Who [add] writes as.
  final AppUser author;

  final _threads = <String, List<Comment>>{};
  final _changed = StreamController<String>.broadcast();
  var _nextId = 0;

  List<Comment> _thread(String signalId) =>
      List.unmodifiable(_threads[signalId] ?? const <Comment>[]);

  @override
  Stream<List<Comment>> watch(String signalId) {
    late StreamController<List<Comment>> controller;
    StreamSubscription<String>? subscription;

    controller = StreamController<List<Comment>>(
      onListen: () {
        controller.add(_thread(signalId));
        subscription = _changed.stream
            .where((id) => id == signalId)
            .listen((_) => controller.add(_thread(signalId)));
      },
      onCancel: () => subscription?.cancel(),
    );

    return controller.stream;
  }

  @override
  Future<void> add({required String signalId, required String body}) async {
    final text = body.trim();
    if (CommentRules.problemWith(text) != null) {
      throw const ParseException('That comment cannot be posted.');
    }

    (_threads[signalId] ??= []).add(
      Comment(
        id: 'mock-${_nextId++}',
        body: text,
        authorId: author.id,
        authorName: author.displayName,
        createdAt: DateTime.now(),
      ),
    );
    _changed.add(signalId);
  }

  @override
  Future<void> delete({
    required String signalId,
    required String commentId,
  }) async {
    final thread = _threads[signalId];
    final index = thread?.indexWhere((c) => c.id == commentId) ?? -1;
    if (thread == null || index < 0) return;

    // The real rules refuse this for anyone but the author; match them.
    if (thread[index].authorId != author.id) {
      throw const PermissionException('Only the author can delete a comment.');
    }

    thread.removeAt(index);
    _changed.add(signalId);
  }

  void dispose() => _changed.close();
}
