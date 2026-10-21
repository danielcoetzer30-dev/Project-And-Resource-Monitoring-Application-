import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:keel/core/errors/exceptions.dart';
import 'package:keel/screens/auth/reset_password_screen.dart';
import 'package:keel/screens/auth/sign_in_screen.dart';
import 'package:keel/screens/auth/splash_screen.dart';
import 'package:keel/theme/app_theme.dart';
import 'package:keel/widgets/labelled_field.dart';

import '../support/fake_auth_repository.dart';

/// Sign in, register, reset a password, and the screen shown while the app
/// works out which of those applies.
///
/// The reset screen is the one with a decision worth protecting: it must not
/// reveal whether an address has an account, because an app built around not
/// exposing its members should not hand that out at the front door.
void main() {
  Widget wrap(Widget child) {
    return ProviderScope(
      child: MaterialApp(theme: AppTheme.dark, home: child),
    );
  }

  group('sign in and register', () {
    testWidgets('offers a way to reset a forgotten password', (tester) async {
      await tester.pumpWidget(wrap(const SignInScreen()));

      expect(find.text('I have forgotten my password'), findsOneWidget);
    });

    testWidgets('does not offer a reset while registering', (tester) async {
      // There is no account yet to reset, so the link would lead nowhere.
      await tester.pumpWidget(wrap(const SignInScreen()));

      await tester.tap(find.text('Create an account instead'));
      await tester.pumpAndSettle();

      expect(find.text('Create account'), findsWidgets);
      expect(find.text('I have forgotten my password'), findsNothing);
    });

    testWidgets('registering asks for a name and an organisation code', (
      tester,
    ) async {
      await tester.pumpWidget(wrap(const SignInScreen()));

      expect(find.byType(LabelledField), findsNWidgets(2));

      await tester.tap(find.text('Create an account instead'));
      await tester.pumpAndSettle();

      // Without an organisation code somebody signs in successfully to an
      // empty dashboard, which is the single most confusing outcome the app
      // has.
      expect(find.byType(LabelledField), findsNWidgets(4));
      expect(find.text('ORGANISATION CODE'), findsOneWidget);
    });

    testWidgets('an empty form is refused with a message per field', (
      tester,
    ) async {
      await tester.pumpWidget(wrap(const SignInScreen()));

      await tester.ensureVisible(find.byType(FilledButton));
      await tester.pump();
      await tester.tap(find.byType(FilledButton));
      await tester.pumpAndSettle();

      expect(find.text('Enter your email address'), findsOneWidget);
      expect(find.text('Enter your password'), findsOneWidget);
    });

    testWidgets('a badly formed email is refused', (tester) async {
      await tester.pumpWidget(wrap(const SignInScreen()));

      await tester.enterText(
        find.byType(TextFormField).first,
        'not-an-address',
      );
      await tester.ensureVisible(find.byType(FilledButton));
      await tester.pump();
      await tester.tap(find.byType(FilledButton));
      await tester.pumpAndSettle();

      expect(find.text('That is not an email address'), findsOneWidget);
    });

    testWidgets('a short password is refused only when registering', (
      tester,
    ) async {
      await tester.pumpWidget(wrap(const SignInScreen()));

      await tester.tap(find.text('Create an account instead'));
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextFormField).at(0), 'Ada');
      await tester.enterText(find.byType(TextFormField).at(1), 'demo-org');
      await tester.enterText(find.byType(TextFormField).at(2), 'a@b.com');
      await tester.enterText(find.byType(TextFormField).at(3), 'short');
      await tester.ensureVisible(find.byType(FilledButton));
      await tester.pump();
      await tester.tap(find.byType(FilledButton));
      await tester.pumpAndSettle();

      expect(find.text('Use at least six characters'), findsOneWidget);
    });

    testWidgets('a refused sign-in says why and keeps what was typed', (
      tester,
    ) async {
      await tester.pumpWidget(
        wrap(
          SignInScreen(
            onSubmit:
                ({
                  required bool isRegistering,
                  required String email,
                  required String password,
                  required String displayName,
                  required String orgId,
                }) async {
                  throw const AuthException('Email or password is incorrect.');
                },
          ),
        ),
      );

      await tester.enterText(find.byType(TextFormField).at(0), 'a@b.com');
      await tester.enterText(find.byType(TextFormField).at(1), 'wrongpass');
      await tester.ensureVisible(find.byType(FilledButton));
      await tester.pump();
      await tester.tap(find.byType(FilledButton));
      await tester.pumpAndSettle();

      expect(
        find.textContaining('Email or password is incorrect'),
        findsOneWidget,
      );
      // Nobody should have to retype an address because the password was
      // wrong.
      expect(find.text('a@b.com'), findsOneWidget);
    });
  });

  group('resetting a password', () {
    testWidgets('asks for the address and reports that a link was sent', (
      tester,
    ) async {
      final auth = FakeAuthRepository();
      addTearDown(auth.dispose);

      await tester.pumpWidget(
        wrap(
          ResetPasswordScreen(
            onSubmit: ({required String email}) =>
                auth.sendPasswordReset(email: email),
          ),
        ),
      );

      await tester.enterText(find.byType(TextFormField), 'ada@example.com');
      await tester.tap(find.text('Send the reset link'));
      await tester.pumpAndSettle();

      expect(auth.resetsRequested, ['ada@example.com']);
      expect(find.text('Check your email'), findsOneWidget);
    });

    testWidgets('does not say whether the address has an account', (
      tester,
    ) async {
      // The property this screen exists to protect. If the wording ever
      // becomes "we have sent you an email", it is claiming something it does
      // not know, and if it becomes "no account uses that address" it is a
      // way of enumerating members.
      final auth = FakeAuthRepository();
      addTearDown(auth.dispose);

      await tester.pumpWidget(
        wrap(
          ResetPasswordScreen(
            initialEmail: 'nobody@example.com',
            onSubmit: ({required String email}) =>
                auth.sendPasswordReset(email: email),
          ),
        ),
      );

      await tester.tap(find.text('Send the reset link'));
      await tester.pumpAndSettle();

      expect(find.textContaining('If an account uses'), findsOneWidget);
      expect(find.textContaining('no account'), findsNothing);
    });

    testWidgets('carries over the address typed on the sign-in screen', (
      tester,
    ) async {
      await tester.pumpWidget(
        wrap(const ResetPasswordScreen(initialEmail: 'ada@example.com')),
      );

      expect(find.text('ada@example.com'), findsOneWidget);
    });

    testWidgets('an empty address is refused', (tester) async {
      await tester.pumpWidget(wrap(const ResetPasswordScreen()));

      await tester.tap(find.text('Send the reset link'));
      await tester.pumpAndSettle();

      expect(find.text('Enter your email address'), findsOneWidget);
      expect(find.text('Check your email'), findsNothing);
    });

    testWidgets('a real failure is reported rather than claimed as sent', (
      tester,
    ) async {
      // No connection is a genuine failure: saying the link is on its way
      // would leave somebody waiting for an email that was never requested.
      final auth = FakeAuthRepository();
      addTearDown(auth.dispose);
      auth.resetError = const NetworkException('No connection.');

      await tester.pumpWidget(
        wrap(
          ResetPasswordScreen(
            onSubmit: ({required String email}) =>
                auth.sendPasswordReset(email: email),
          ),
        ),
      );

      await tester.enterText(find.byType(TextFormField), 'ada@example.com');
      await tester.tap(find.text('Send the reset link'));
      await tester.pumpAndSettle();

      expect(find.textContaining('No connection'), findsOneWidget);
      expect(find.text('Check your email'), findsNothing);
    });
  });

  group('the splash screen', () {
    testWidgets('names the app and says what it is waiting for', (
      tester,
    ) async {
      await tester.pumpWidget(wrap(const SplashScreen()));

      expect(find.text('Keel'), findsOneWidget);
      expect(find.text('Checking your session'), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    });

    testWidgets('says something different while signing in', (tester) async {
      await tester.pumpWidget(
        wrap(const SplashScreen(message: 'Signing you in')),
      );

      expect(find.text('Signing you in'), findsOneWidget);
    });

    testWidgets('needs no data, so it renders with nothing provided', (
      tester,
    ) async {
      // The same promise the Home tab makes: this screen is what somebody
      // sees on a dead connection, so it cannot depend on a repository.
      await tester.pumpWidget(const MaterialApp(home: SplashScreen()));

      expect(tester.takeException(), isNull);
      expect(find.text('Keel'), findsOneWidget);
    });
  });
}
