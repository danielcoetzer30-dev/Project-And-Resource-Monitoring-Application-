import 'package:flutter_test/flutter_test.dart';

import 'package:prahm/core/errors/exceptions.dart';
import 'package:prahm/data/mock_comment_repository.dart';
import 'package:prahm/models/comment.dart';

import '../support/fake_auth_repository.dart';

/// Covers the behaviour the thread screen relies on. Runs against the in-memory
/// repository, which applies the same rules as the Firestore one.
void main() {
  final me = FakeAuthRepository.demoUser;
  late MockCommentRepository repo;

  Comment someoneElses() => Comment(
    id: 'theirs',
    body: 'The vendor says the fix ships on Friday.',
    authorId: 'someone-else',
    authorName: 'Naledi',
    createdAt: DateTime(2026, 10, 8, 9),
  );

  setUp(() => repo = MockCommentRepository(author: me));
  tearDown(() => repo.dispose());

  test('a thread reads oldest first', () async {
    await repo.add(signalId: 'a', body: 'first');
    await repo.add(signalId: 'a', body: 'second');

    final thread = await repo.watch('a').first;

    expect(thread.map((c) => c.body), ['first', 'second']);
  });

  test('threads belong to their own signal', () async {
    await repo.add(signalId: 'a', body: 'about a');
    await repo.add(signalId: 'b', body: 'about b');

    expect((await repo.watch('a').first).map((c) => c.body), ['about a']);
    expect((await repo.watch('b').first).map((c) => c.body), ['about b']);
    expect(await repo.watch('c').first, isEmpty);
  });

  test('a comment is written as the signed-in user, and trimmed', () async {
    await repo.add(signalId: 'a', body: '  padded  ');

    final comment = (await repo.watch('a').first).single;

    expect(comment.body, 'padded');
    expect(comment.authorId, me.id);
    expect(comment.authorName, me.displayName);
  });

  test('an open thread hears about a new comment', () async {
    final emitted = <List<Comment>>[];
    final subscription = repo.watch('a').listen(emitted.add);
    await pumpEventQueue();

    await repo.add(signalId: 'a', body: 'hello');
    await pumpEventQueue();
    await subscription.cancel();

    expect(emitted.map((t) => t.length), [0, 1]);
  });

  test('a blank or oversized comment is refused', () async {
    await expectLater(
      repo.add(signalId: 'a', body: '   '),
      throwsA(isA<ParseException>()),
    );
    await expectLater(
      repo.add(signalId: 'a', body: 'a' * (CommentRules.maxLength + 1)),
      throwsA(isA<ParseException>()),
    );
    expect(await repo.watch('a').first, isEmpty);
  });

  test('an author can delete their own comment', () async {
    await repo.add(signalId: 'a', body: 'mine');
    final id = (await repo.watch('a').first).single.id;

    await repo.delete(signalId: 'a', commentId: id);

    expect(await repo.watch('a').first, isEmpty);
  });

  test('nobody can delete someone else\'s comment', () async {
    final shared = MockCommentRepository(
      author: me,
      initial: {
        'a': [someoneElses()],
      },
    );
    addTearDown(shared.dispose);

    await expectLater(
      shared.delete(signalId: 'a', commentId: 'theirs'),
      throwsA(isA<PermissionException>()),
    );
    expect(await shared.watch('a').first, hasLength(1));
  });
}
