import 'package:flutter_test/flutter_test.dart';

import 'package:keel/models/comment.dart';

/// The posting rules are repeated in `firestore.rules`. These pin the client
/// side of them, so the app never offers to send something the backend would
/// refuse, and never refuses something it would accept.
void main() {
  group('CommentRules', () {
    test('a blank comment cannot be posted', () {
      expect(CommentRules.problemWith(''), isNotNull);
      expect(CommentRules.problemWith('   \n  '), isNotNull);
    });

    test('an ordinary comment can be posted', () {
      expect(
        CommentRules.problemWith('Generator was down on Tuesday.'),
        isNull,
      );
    });

    test('the limit is inclusive', () {
      expect(CommentRules.problemWith('a' * CommentRules.maxLength), isNull);
      expect(
        CommentRules.problemWith('a' * (CommentRules.maxLength + 1)),
        isNotNull,
      );
    });

    test('surrounding whitespace does not count towards the limit', () {
      final padded = '  ${'a' * CommentRules.maxLength}  ';

      expect(CommentRules.lengthOf(padded), CommentRules.maxLength);
      expect(CommentRules.problemWith(padded), isNull);
    });

    test('length counts characters, not UTF-16 code units', () {
      // Each of these is one character but two code units. Counting code units
      // would refuse a comment the backend accepts.
      final emoji = '😀' * CommentRules.maxLength;

      expect(emoji.length, CommentRules.maxLength * 2);
      expect(CommentRules.lengthOf(emoji), CommentRules.maxLength);
      expect(CommentRules.problemWith(emoji), isNull);
    });

    test('the message says what to do', () {
      expect(CommentRules.problemWith(''), 'Write something first.');
      expect(
        CommentRules.problemWith('a' * (CommentRules.maxLength + 1)),
        contains('${CommentRules.maxLength}'),
      );
    });
  });
}
