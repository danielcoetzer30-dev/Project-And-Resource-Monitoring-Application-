import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/errors/failure.dart';
import '../data/auth_repository.dart';
import '../models/app_user.dart';

/// Where the session currently stands.
sealed class AuthState {
  const AuthState();
}

/// Checking for an existing session on launch.
class AuthChecking extends AuthState {
  const AuthChecking();
}

class SignedOut extends AuthState {
  const SignedOut({this.failure});

  /// Set when the last attempt failed, so the screen can say why.
  final Failure? failure;
}

class SignedIn extends AuthState {
  const SignedIn(this.user);

  final AppUser user;
}

/// A sign-in or registration is in flight.
class AuthBusy extends AuthState {
  const AuthBusy();
}

/// Owns the session.
///
/// Screens read this rather than touching the auth repository, so there is one
/// place that knows whether somebody is signed in and exactly one path in and
/// out of that state.
class AuthNotifier extends Notifier<AuthState> {
  AuthNotifier(this._repository);

  final AuthRepository _repository;

  @override
  AuthState build() {
    // Follow the repository's own stream, so a session expiring elsewhere is
    // reflected here without the app having to poll.
    final subscription = _repository.watchCurrentUser().listen((user) {
      state = user == null ? const SignedOut() : SignedIn(user);
    });

    ref.onDispose(subscription.cancel);

    final current = _repository.currentUser;
    return current == null ? const AuthChecking() : SignedIn(current);
  }

  Future<void> signIn({required String email, required String password}) async {
    state = const AuthBusy();
    try {
      final user = await _repository.signIn(email: email, password: password);
      state = SignedIn(user);
    } catch (error) {
      state = SignedOut(failure: failureFromException(error));
    }
  }

  Future<void> register({
    required String email,
    required String password,
    required String displayName,
    required String orgId,
  }) async {
    state = const AuthBusy();
    try {
      final user = await _repository.register(
        email: email,
        password: password,
        displayName: displayName,
        orgId: orgId,
      );
      state = SignedIn(user);
    } catch (error) {
      state = SignedOut(failure: failureFromException(error));
    }
  }

  Future<void> signOut() async {
    await _repository.signOut();
    state = const SignedOut();
  }
}
