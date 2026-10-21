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
      // The splash covers both: restoring a session on launch, and the moment
      // after credentials are submitted while the user document is read. They
      // are the same wait from the person's point of view, so they look the
      // same, and only the line underneath differs.
      AuthChecking() => const SplashScreen(),
      AuthBusy() => const SplashScreen(message: 'Signing you in'),
      SignedOut() => SignInScreen(
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
      ),
      SignedIn() => const AppShell(),
    };
  }
}
