import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:prahm/core/errors/exceptions.dart';
import 'package:prahm/data/comment_repository.dart';
import 'package:prahm/data/mock_comment_repository.dart';
import 'package:prahm/models/comment.dart';
import 'package:prahm/models/health_state.dart';
import 'package:prahm/models/signal.dart';
import 'package:prahm/screens/signal_thread_screen.dart';
import 'package:prahm/state/providers.dart';

import '../support/fake_auth_repository.dart';

/// The discussion on a signal: reading it, adding to it, and what happens when
/// that goes wrong.
///
/// Runs against the in-memory repository, so it needs no Firebase.
void main() {
  final signal = Signal(
    id: 'ledger-overall',
    title: 'Ledger rebuild is trending toward failure',
    because: 'The composite health score is 31 out of 100, which is critical.',
    severity: HealthState.critical,
    projectId: 'ledger',
    raisedAt: DateTime.now().subtract(const Duration(hours: 2)),
  );

  Widget thread(CommentRepository repository) {
    return ProviderScope(
      overrides: [
        authRepositoryProvider.overrideWithValue(FakeAuthRepository()),
        commentRepositoryProvider.overrideWithValue(repository),
      ],
      child: MaterialApp(
        home: SignalThreadScreen(signal: signal, projectName: 'Ledger rebuild'),
      ),
    );
  }

  MockCommentRepository repoWith(List<Comment> comments) {
    final repository = MockCommentRepository(
      author: FakeAuthRepository.demoUser,
      initial: {signal.id: comments},
    );
    addTearDown(repository.dispose);
    return repository;
  }

  Comment comment({
    required String id,
    required String body,
    required String authorId,
    required String authorName,
  }) => Comment(
    id: id,
    body: body,
    authorId: authorId,
    authorName: authorName,
    createdAt: DateTime.now().subtract(const Duration(hours: 1)),
  );

  Future<void> type(WidgetTester tester, String text) async {
    await tester.enterText(find.byType(TextField), text);
    await tester.pump();
  }

  IconButton sendButton(WidgetTester tester) => tester.widget<IconButton>(
    find.widgetWithIcon(IconButton, Icons.arrow_upward),
  );

  testWidgets('keeps the reasoning at the top of the discussion', (
    tester,
  ) async {
    await tester.pumpWidget(thread(repoWith(const [])));
    await tester.pumpAndSettle();

    // The warning and why it fired are what the conversation is about.
    expect(find.text(signal.title), findsOneWidget);
    expect(find.text(signal.because), findsOneWidget);
  });

  testWidgets('an empty thread invites a first comment', (tester) async {
    await tester.pumpWidget(thread(repoWith(const [])));
    await tester.pumpAndSettle();

    expect(find.textContaining('Nobody has said anything yet'), findsOneWidget);
  });

  testWidgets('shows what has been said, with who said it', (tester) async {
    await tester.pumpWidget(
      thread(
        repoWith([
          comment(
            id: 'c1',
            body: 'The vendor says the fix ships on Friday.',
            authorId: 'someone-else',
            authorName: 'Naledi',
          ),
        ]),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      find.text('The vendor says the fix ships on Friday.'),
      findsOneWidget,
    );
    expect(find.text('Naledi'), findsOneWidget);
    expect(find.textContaining('Nobody has said anything yet'), findsNothing);
  });

  testWidgets('posting adds the comment, trimmed, and clears the box', (
    tester,
  ) async {
    await tester.pumpWidget(thread(repoWith(const [])));
    await tester.pumpAndSettle();

    await type(tester, '  Generator was down on Tuesday  ');
    await tester.tap(find.byTooltip('Post comment'));
    await tester.pumpAndSettle();

    expect(find.text('Generator was down on Tuesday'), findsOneWidget);
    expect(find.text(FakeAuthRepository.demoUser.displayName), findsOneWidget);
    expect(
      tester.widget<TextField>(find.byType(TextField)).controller!.text,
      '',
    );
  });

  testWidgets('a blank comment cannot be sent', (tester) async {
    await tester.pumpWidget(thread(repoWith(const [])));
    await tester.pumpAndSettle();

    expect(sendButton(tester).onPressed, isNull);

    await type(tester, '   ');
    expect(sendButton(tester).onPressed, isNull);

    await type(tester, 'Something');
    expect(sendButton(tester).onPressed, isNotNull);
  });

  testWidgets('says how far over the limit a comment is, in words', (
    tester,
  ) async {
    await tester.pumpWidget(thread(repoWith(const [])));
    await tester.pumpAndSettle();

    await type(tester, 'a' * (CommentRules.maxLength - 50));
    expect(
      find.text(
        '${CommentRules.maxLength - 50} of ${CommentRules.maxLength} characters',
      ),
      findsOneWidget,
    );
    expect(sendButton(tester).onPressed, isNotNull);

    await type(tester, 'a' * (CommentRules.maxLength + 3));
    expect(
      find.text('3 over the ${CommentRules.maxLength} character limit'),
      findsOneWidget,
    );
    expect(sendButton(tester).onPressed, isNull);
  });

  testWidgets('you can delete your own comment and nobody else\'s', (
    tester,
  ) async {
    await tester.pumpWidget(
      thread(
        repoWith([
          comment(
            id: 'theirs',
            body: 'The vendor says the fix ships on Friday.',
            authorId: 'someone-else',
            authorName: 'Naledi',
          ),
          comment(
            id: 'mine',
            body: 'I have moved the demo to Monday.',
            authorId: FakeAuthRepository.demoUser.id,
            authorName: FakeAuthRepository.demoUser.displayName,
          ),
        ]),
      ),
    );
    await tester.pumpAndSettle();

    // The control is absent on other people's comments, not just refused.
    expect(find.byIcon(Icons.delete_outline), findsOneWidget);

    await tester.tap(find.byIcon(Icons.delete_outline));
    await tester.pumpAndSettle();
    expect(find.text('Delete this comment?'), findsOneWidget);

    await tester.tap(find.text('Delete'));
    await tester.pumpAndSettle();

    expect(find.text('I have moved the demo to Monday.'), findsNothing);
    expect(
      find.text('The vendor says the fix ships on Friday.'),
      findsOneWidget,
    );
  });

  testWidgets('keeping a comment at the prompt leaves it in place', (
    tester,
  ) async {
    await tester.pumpWidget(
      thread(
        repoWith([
          comment(
            id: 'mine',
            body: 'I have moved the demo to Monday.',
            authorId: FakeAuthRepository.demoUser.id,
            authorName: FakeAuthRepository.demoUser.displayName,
          ),
        ]),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.delete_outline));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Keep it'));
    await tester.pumpAndSettle();

    expect(find.text('I have moved the demo to Monday.'), findsOneWidget);
  });

  testWidgets('a refused comment says so and gives the words back', (
    tester,
  ) async {
    await tester.pumpWidget(thread(_RefusingCommentRepository()));
    await tester.pumpAndSettle();

    await type(tester, 'Hello team');
    await tester.tap(find.byTooltip('Post comment'));
    await tester.pumpAndSettle();

    expect(
      find.text('Your comment did not send. Your account cannot comment here.'),
      findsOneWidget,
    );
    // A failed send must never cost someone what they wrote.
    expect(
      tester.widget<TextField>(find.byType(TextField)).controller!.text,
      'Hello team',
    );
  });
}

/// A repository whose backend refuses every write, as the security rules would
/// for an account that is not allowed to comment.
class _RefusingCommentRepository implements CommentRepository {
  @override
  Stream<List<Comment>> watch(String signalId) => Stream.value(const []);

  @override
  Future<void> add({required String signalId, required String body}) async {
    throw const PermissionException('The backend refused this comment.');
  }

  @override
  Future<void> delete({
    required String signalId,
    required String commentId,
  }) async {}
}
