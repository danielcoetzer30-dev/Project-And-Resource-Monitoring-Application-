import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app_shell.dart';
import '../../state/auth_notifier.dart';
import '../../theme/tokens.dart';
import 'sign_in_screen.dart';

/// Decides whether to show the app or the sign-in screen.
///
/// Not currently the app's entry point. Firestore rules are closed and the
/// prototype runs on mock data, so gating the whole app behind a sign-in that
/// cannot succeed would make it undemonstrable. Once rules open per collection
/// in Stage 1, `main.dart` points at this instead of at AppShell.
class AuthGate extends ConsumerWidget {
  const AuthGate({super.key, required this.authProvider});

  final NotifierProvider<AuthNotifier, AuthState> authProvider;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(authProvider);

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
              final notifier = ref.read(authProvider.notifier);
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
