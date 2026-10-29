import 'package:flutter_test/flutter_test.dart';

import 'package:prahm/models/member_search.dart';

/// Finding a person on the members screen.
///
/// Only a name and a role are searchable, which is the point worth pinning:
/// there is nothing else on a roster to search, and a search that could reach
/// an hours figure or an activity count would mean one had been stored.
void main() {
  bool find(String query, {String name = 'John Smith', String role = 'lead'}) =>
      MemberSearch.matches(name: name, role: role, query: query);

  test('an empty query matches everyone, so the list starts complete', () {
    expect(find(''), isTrue);
    expect(find('   '), isTrue);
  });

  group('plain typing', () {
    test('matches anywhere in the name, ignoring capitals', () {
      expect(find('john'), isTrue);
      expect(find('JOHN'), isTrue);
      expect(find('smith'), isTrue);
      expect(find('n sm'), isTrue);
    });

    test('matches the role', () {
      expect(find('lead'), isTrue);
      expect(find('manager'), isFalse);
    });

    test('does not match someone unrelated', () {
      expect(find('patel'), isFalse);
    });
  });

  group('wildcards', () {
    test('* stands for any run of characters', () {
      expect(find('jo*', name: 'John Smith'), isTrue);
      expect(find('jo*', name: 'Joanne Botha'), isTrue);
      expect(find('jo*n', name: 'John Smith'), isTrue);
      expect(find('zz*', name: 'John Smith'), isFalse);
    });

    test('? stands for exactly one character', () {
      expect(find('?ara', name: 'Sara Nkosi'), isTrue);
      expect(find('?ara', name: 'Kara Jones'), isTrue);
      expect(find('?ara', name: 'Ara Mthembu'), isFalse);
    });

    test('a wildcard query is not also matched by containment', () {
      // Once somebody types a wildcard they have said what they mean, so the
      // forgiving paths below are skipped and the pattern decides.
      expect(find('*xyz*', name: 'John Smith'), isFalse);
    });
  });

  group('close spelling', () {
    test('forgives a letter or two in a typed name', () {
      expect(find('smyth', name: 'Jane Smith'), isTrue);
      expect(find('smiht', name: 'Jane Smith'), isTrue);
    });

    test('forgives two letters typed the wrong way round', () {
      // The commonest typing mistake, and the reason the distance here
      // counts a swap as one mistake rather than two. Plain edit distance
      // would put this just outside the tolerance a short query is given.
      expect(find('jhon', name: 'John Smith'), isTrue);
      expect(find('jhon', name: 'Joanne Botha'), isFalse);
    });

    test('matches the start of a longer name', () {
      // So typing part of a surname still finds it without a wildcard.
      expect(find('nkos', name: 'Sipho Nkosana'), isTrue);
    });

    test('very short queries are left to containment', () {
      // At one or two letters, one wrong character would match almost
      // everybody, which is worse than finding nothing.
      expect(find('jo', name: 'John Smith'), isTrue);
      expect(find('xy', name: 'John Smith'), isFalse);
    });

    test('still refuses a name that is genuinely different', () {
      expect(find('mthembu', name: 'John Smith'), isFalse);
    });
  });
}
