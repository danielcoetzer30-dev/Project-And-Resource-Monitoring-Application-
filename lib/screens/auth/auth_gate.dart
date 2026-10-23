import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app_shell.dart';
import '../../state/auth_notifier.dart';
import '../../state/providers.dart';
import 'sign_in_screen.dart';
import 'splash_screen.dart';

/// Decides whether to show the app or the sign-in screen.
///
/// The app's entry point. Project data is scoped to the signed-in user's
/// organisation and the security rules check membership on every read, so
/// there is nothing to show before somebody signs in.
class AuthGate extends ConsumerWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(authNotifierProvider);

    return switch (state) {
      // Only the launch wait gets the splash: there is no form to preserve
      // yet, and the session has to be restored before anything can be shown.
      AuthChecking() => const SplashScreen(),

      // Busy deliberately keeps the form on screen rather than replacing it
      // with the splash. Swapping it out destroys the screen's State, and
      // with it both what was typed and the error that was about to be
      // shown, which is how every refused sign-in came back as an empty
      // form and no message at all. The form has its own spinner in the
      // button and disables itself while a request is in flight.
      AuthBusy() => _form(ref),

      SignedOut(:final failure) => _form(ref, error: failure?.message),

      SignedIn() => const AppShell(),
    };
  }

  /// The sign-in form, wired to the notifier.
  ///
  /// One builder for both states, so the widget is the same type in the same
  /// position and Flutter keeps its State across the change.
  Widget _form(WidgetRef ref, {String? error}) {
    return SignInScreen(
      initialError: error,
      onSubmit:
          ({
            required bool isRegistering,
            required String email,
            required String password,
            required String displayName,
            required String orgId,
          }) {
            final notifier = ref.read(authNotifierProvider.notifier);
            return isRegistering
                ? notifier.register(
                    email: email,
                    password: password,
                    displayName: displayName,
                    orgId: orgId,
                  )
                : notifier.signIn(email: email, password: password);
          },
    );
  }
}
