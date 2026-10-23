import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/errors/failure.dart';
import '../data/auth_repository.dart';
import '../models/app_user.dart';
import 'providers.dart';

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
  /// Set by [build] from the provider, so the repository can be overridden in
  /// tests without constructing the notifier by hand.
  late final AuthRepository _repository = ref.read(authRepositoryProvider);

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

  /// Signs in, and rethrows what went wrong.
  ///
  /// The failure is put on the state *and* rethrown, which looks redundant
  /// and is not. The state is what the gate renders from; the throw is what
  /// the sign-in screen catches to show the message beside the form.
  ///
  /// This used to only set the state. Nothing read `SignedOut.failure`, and
  /// the screen's error display only ever worked when the callback threw, so
  /// a refused sign-in returned normally, the gate rebuilt the form from
  /// scratch, and the person saw the same empty screen with no explanation.
  /// Every wrong password, every expired account, every unreachable network
  /// looked identical: nothing happened.
  Future<void> signIn({required String email, required String password}) async {
    state = const AuthBusy();
    try {
      final user = await _repository.signIn(email: email, password: password);
      state = SignedIn(user);
    } catch (error) {
      state = SignedOut(failure: failureFromException(error));
      rethrow;
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
      // Rethrown for the same reason signIn rethrows: the screen shows the
      // message, the gate renders the state.
      state = SignedOut(failure: failureFromException(error));
      rethrow;
    }
  }

  /// Asks for a reset email.
  ///
  /// Does not touch [state]: the session is unchanged by asking, and flipping
  /// to [AuthBusy] would send the gate back to the spinner and take the reset
  /// screen off the stack mid-request.
  Future<void> sendPasswordReset({required String email}) {
    return _repository.sendPasswordReset(email: email);
  }

  Future<void> signOut() async {
    await _repository.signOut();
    state = const SignedOut();
  }
}

/// The signed-in person, or null when signed out.
///
/// Screens read this rather than pattern-matching on [AuthState], so the role
/// checks below all come from one place.
final currentUserProvider = Provider<AppUser?>((ref) {
  final authState = ref.watch(authNotifierProvider);
  return authState is SignedIn ? authState.user : null;
});

/// Returns true if the logged-in user is a Manager.
final isManagerProvider = Provider<bool>((ref) {
  final user = ref.watch(currentUserProvider);
  return user?.isManager ?? false;
});

/// Returns true if the logged-in user is a Lead.
final isLeadProvider = Provider<bool>((ref) {
  final user = ref.watch(currentUserProvider);
  return user?.isLead ?? false;
});

/// Returns true if the logged-in user is allowed to edit settings/weights.
final canChangeSettingsProvider = Provider<bool>((ref) {
  final user = ref.watch(currentUserProvider);
  return user?.canChangeSettings ?? false;
});
