import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app_shell.dart';
import '../../state/auth_notifier.dart';
import '../../state/providers.dart';
import '../../theme/tokens.dart';
import 'sign_in_screen.dart';

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
      AuthChecking() || AuthBusy() => const _Checking(),
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

class _Checking extends StatelessWidget {
  const _Checking();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(
        child: SizedBox(
          width: 20,
          height: 20,
          child: CircularProgressIndicator(strokeWidth: 2, color: Tokens.slate),
        ),
      ),
    );
  }
}
