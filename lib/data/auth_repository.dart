import '../models/app_user.dart';

/// Sign-in, as an interface.
///
/// The rest of the app depends on this and not on Firebase, so auth can be
/// faked in tests and replaced later without touching a screen.
abstract interface class AuthRepository {
  /// Emits the current user, or null when signed out. Emits immediately on
  /// listen so the app can decide what to show without waiting.
  Stream<AppUser?> watchCurrentUser();

  /// The user right now, without waiting for the stream.
  AppUser? get currentUser;

  Future<AppUser> signIn({required String email, required String password});

  Future<AppUser> register({
    required String email,
    required String password,
    required String displayName,
    required String orgId,
  });

  /// Sends a password reset email.
  ///
  /// Deliberately does not report whether the address has an account. Saying
  /// "no account uses that email" to anybody who asks turns a reset form into
  /// a way of finding out who is registered, so the screen says the same thing
  /// either way and this method completes either way.
  Future<void> sendPasswordReset({required String email});

  Future<void> signOut();
}
