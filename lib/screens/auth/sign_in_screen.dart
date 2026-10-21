import 'package:flutter/material.dart';

import '../../core/errors/failure.dart';
import '../../routing/routes.dart';
import '../../theme/tokens.dart';
import '../../theme/typography.dart';
import '../../widgets/labelled_field.dart';

/// Sign in, or create an account.
///
/// One screen for both, toggled, because a team of five setting this up for
/// the first time will do both within a minute of each other and bouncing
/// between two screens for that is friction with no purpose.
class SignInScreen extends StatefulWidget {
  const SignInScreen({super.key, this.onSubmit});

  /// Supplied by the caller so this screen stays testable without Firebase.
  final Future<void> Function({
    required bool isRegistering,
    required String email,
    required String password,
    required String displayName,
    required String orgId,
  })?
  onSubmit;

  @override
  State<SignInScreen> createState() => _SignInScreenState();
}

class _SignInScreenState extends State<SignInScreen> {
  final _formKey = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _name = TextEditingController();
  final _org = TextEditingController();

  bool _isRegistering = false;
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    _name.dispose();
    _org.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _busy = true;
      _error = null;
    });

    try {
      await widget.onSubmit?.call(
        isRegistering: _isRegistering,
        email: _email.text,
        password: _password.text,
        displayName: _name.text,
        orgId: _org.text,
      );
      if (mounted) Navigator.of(context).maybePop();
    } catch (error) {
      // Translated rather than interpolated. '$error' on an AppException
      // prints "AuthException: Email or password is incorrect.", and the
      // class name in front of the sentence is for a log, not for somebody
      // trying to get into their account.
      if (mounted) {
        setState(() => _error = failureFromException(error).message);
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_isRegistering ? 'Create account' : 'Sign in'),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(Tokens.space4),
          children: [
            Text(
              _isRegistering
                  ? 'Create an account for your team'
                  : 'Sign in to see your team\'s project health',
              style: AppType.bodyMuted,
            ),
            const SizedBox(height: Tokens.space5),
            Form(
              key: _formKey,
              child: Column(
                children: [
                  if (_isRegistering) ...[
                    LabelledField(
                      controller: _name,
                      label: 'Your name',
                      hint: 'Shown to your team',
                      validator: (v) => (v == null || v.trim().isEmpty)
                          ? 'Enter your name'
                          : null,
                    ),
                    const SizedBox(height: Tokens.space4),
                    LabelledField(
                      controller: _org,
                      label: 'Organisation code',
                      hint: 'From whoever set up your team',
                      validator: (v) => (v == null || v.trim().isEmpty)
                          ? 'Enter the organisation code'
                          : null,
                    ),
                    const SizedBox(height: Tokens.space4),
                  ],
                  LabelledField(
                    controller: _email,
                    label: 'Email',
                    keyboardType: TextInputType.emailAddress,
                    validator: (v) {
                      if (v == null || v.trim().isEmpty) {
                        return 'Enter your email address';
                      }
                      if (!v.contains('@')) {
                        return 'That is not an email address';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: Tokens.space4),
                  LabelledField(
                    controller: _password,
                    label: 'Password',
                    obscure: true,
                    validator: (v) {
                      if (v == null || v.isEmpty) return 'Enter your password';
                      if (_isRegistering && v.length < 6) {
                        return 'Use at least six characters';
                      }
                      return null;
                    },
                  ),
                ],
              ),
            ),
            if (_error != null) ...[
              const SizedBox(height: Tokens.space4),
              Container(
                padding: const EdgeInsets.all(Tokens.space3),
                decoration: BoxDecoration(
                  color: Tokens.flare.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(Tokens.radiusSm),
                  border: Border.all(
                    color: Tokens.flare.withValues(alpha: 0.35),
                  ),
                ),
                child: Text(
                  _error!,
                  style: AppType.body.copyWith(color: Tokens.flare),
                ),
              ),
            ],
            const SizedBox(height: Tokens.space5),
            FilledButton(
              onPressed: _busy ? null : _submit,
              style: FilledButton.styleFrom(
                backgroundColor: Tokens.beacon,
                foregroundColor: Tokens.shaft,
                padding: const EdgeInsets.symmetric(vertical: Tokens.space4),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(Tokens.radiusSm),
                ),
              ),
              child: _busy
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Tokens.shaft,
                      ),
                    )
                  : Text(
                      _isRegistering ? 'Create account' : 'Sign in',
                      style: AppType.bodyStrong.copyWith(color: Tokens.shaft),
                    ),
            ),
            const SizedBox(height: Tokens.space3),
            TextButton(
              onPressed: _busy
                  ? null
                  : () => setState(() {
                      _isRegistering = !_isRegistering;
                      _error = null;
                    }),
              child: Text(
                _isRegistering
                    ? 'I already have an account'
                    : 'Create an account instead',
                style: AppType.body.copyWith(color: Tokens.beacon),
              ),
            ),
            // Only offered while signing in. On the registration form there is
            // no account yet to reset, so the link would be an invitation to
            // a dead end.
            if (!_isRegistering)
              TextButton(
                onPressed: _busy
                    ? null
                    : () => Navigator.of(context).pushNamed(
                        Routes.resetPassword,
                        // Carries over whatever has been typed, so nobody
                        // types their address twice.
                        arguments: _email.text,
                      ),
                child: Text(
                  'I have forgotten my password',
                  style: AppType.body.copyWith(color: Tokens.slate),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
