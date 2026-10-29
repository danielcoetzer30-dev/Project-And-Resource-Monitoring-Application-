/// Finds people by a typed query, forgivingly.
///
/// Three ways to match, tried in order:
///  - Wildcards: `*` is any run of characters and `?` is any one character,
///    so `jo*` finds John and Joanne, and `?ara` finds Sara and Kara.
///  - Containment: the query appears anywhere in the name or role.
///  - Close spelling: a word in the name is within a letter or two of the
///    query (or of the start of the word), so `jhon` still finds John.
///
/// Only a name and a role are searched. There is nothing else on a roster.
abstract final class MemberSearch {
  static bool matches({
    required String name,
    required String role,
    required String query,
  }) {
    final q = query.trim().toLowerCase();
    if (q.isEmpty) return true;

    final n = name.toLowerCase();
    final r = role.toLowerCase();

    if (q.contains('*') || q.contains('?')) {
      final pattern = _wildcard(q);
      return pattern.hasMatch(n) || pattern.hasMatch(r);
    }

    if (n.contains(q) || r.contains(q)) return true;

    // Closeness is measured per word, so "smith" can match "Jane Smyth".
    // Very short queries are left to containment, where one wrong letter
    // would match nearly everyone.
    if (q.length < 3) return false;
    final allowed = q.length <= 4 ? 1 : 2;
    for (final word in n.split(RegExp(r'\s+'))) {
      if (word.isEmpty) continue;
      if (_distance(q, word) <= allowed) return true;
      if (word.length > q.length &&
          _distance(q, word.substring(0, q.length)) <= allowed) {
        return true;
      }
    }
    return false;
  }

  /// Turns `jo*n?` into a pattern that matches anywhere in the text.
  static RegExp _wildcard(String query) {
    final buffer = StringBuffer();
    for (final rune in query.runes) {
      final char = String.fromCharCode(rune);
      buffer.write(switch (char) {
        '*' => '.*',
        '?' => '.',
        _ => RegExp.escape(char),
      });
    }
    return RegExp(buffer.toString());
  }

  /// Number of typing mistakes between [a] and [b]: a letter inserted,
  /// removed, replaced, or two adjacent letters typed the wrong way round.
  ///
  /// The transposition is why this is not plain edit distance. Swapping two
  /// letters is the most common typing mistake there is, and counting `jhon`
  /// as two mistakes away from `john` would put it outside the tolerance a
  /// four-letter query is given, so the one typo people actually make would
  /// be the one the search did not forgive.
  static int _distance(String a, String b) {
    var beforePrevious = <int>[];
    var previous = List<int>.generate(b.length + 1, (i) => i);
    for (var i = 1; i <= a.length; i++) {
      final current = List<int>.filled(b.length + 1, 0)..[0] = i;
      for (var j = 1; j <= b.length; j++) {
        final cost = a[i - 1] == b[j - 1] ? 0 : 1;
        var best = [
          previous[j] + 1,
          current[j - 1] + 1,
          previous[j - 1] + cost,
        ].reduce((x, y) => x < y ? x : y);

        if (i > 1 &&
            j > 1 &&
            a[i - 1] == b[j - 2] &&
            a[i - 2] == b[j - 1]) {
          final transposed = beforePrevious[j - 2] + 1;
          if (transposed < best) best = transposed;
        }

        current[j] = best;
      }
      beforePrevious = previous;
      previous = current;
    }
    return previous[b.length];
  }
}
