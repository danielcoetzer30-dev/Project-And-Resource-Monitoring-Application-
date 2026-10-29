import 'squad.dart';

/// What may be saved when a squad is created or renamed, in one place so the
/// app, the mock and the security rules agree.
///
/// `firestore.rules` repeats these limits. If you change one, change both.
///
/// A person states two things about a squad: what it is called and how many
/// people it says it has. Everything else a squad card shows — capacity
/// committed, velocity, active projects — is measured, not stated, and is
/// written by ingestion. A new squad starts with those at zero, and the rules
/// refuse a client that tries to start one anywhere else, so nobody can create
/// a squad that arrives already looking healthy.
abstract final class SquadRules {
  static const maxName = 60;
  static const maxHeadcount = 99;

  /// Null when [raw] is an acceptable name.
  static String? nameProblem(String raw) {
    final name = raw.trim();
    if (name.isEmpty) return 'Give the squad a name';
    if (name.length > maxName) return 'Keep the name under $maxName characters';
    return null;
  }

  /// Null when [raw] is acceptable. Empty means "not stated" and is read as
  /// zero by [parseHeadcount].
  static String? headcountProblem(String raw) {
    final text = raw.trim();
    if (text.isEmpty) return null;

    final value = int.tryParse(text);
    if (value == null) return 'Use a whole number';
    if (value < 0) return 'Cannot be negative';
    if (value > maxHeadcount) return 'Keep it at $maxHeadcount or fewer';
    return null;
  }

  static int parseHeadcount(String raw) => int.tryParse(raw.trim()) ?? 0;

  /// Whether another squad already has this name, ignoring capitals and
  /// spaces at the ends. [exceptId] is the squad being renamed, which is
  /// allowed to keep its own name.
  static bool nameTaken(
    String raw,
    Iterable<Squad> squads, {
    String? exceptId,
  }) {
    final wanted = raw.trim().toLowerCase();
    return squads.any(
      (s) => s.id != exceptId && s.name.trim().toLowerCase() == wanted,
    );
  }
}
