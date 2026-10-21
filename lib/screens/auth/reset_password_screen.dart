import 'package:flutter/material.dart';

import '../../theme/tokens.dart';
import '../../theme/typography.dart';
import '../../widgets/labelled_field.dart';

/// Asks Firebase to email a password reset link.
///
/// The screen deliberately says the same thing whether or not the address has
/// an account. "No account uses that email" would turn this form into a way
/// of finding out who is registered, which is the kind of thing an app built
/// around not exposing its members should not hand out at the front door.
/// [AuthRepository.sendPasswordReset] swallows those two error codes for the
/// same reason.
///
/// Reset itself happens in the email, not here. The app never sees the new
/// password, which is why there is no second screen to build.
class ResetPasswordScreen extends StatefulWidget {
  const ResetPasswordScreen({super.key, this.onSubmit, this.initialEmail = ''});

  /// Supplied by the caller so this screen stays testable without Firebase,
  /// the same arrangement the sign-in screen uses.
  final Future<void> Function({required String email})? onSubmit;

  /// Carried over from the sign-in screen, so somebody who has already typed
  /// their address does not type it again.
  final String initialEmail;

  @override
  State<ResetPasswordScreen> createState() => _ResetPasswordScreenState();
}

class _ResetPasswordScreenState extends State<ResetPasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  late final _email = TextEditingController(text: widget.initialEmail);

  bool _busy = false;
  bool _sent = false;
  String? _error;

  @override
  void dispose() {
    _email.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _busy = true;
      _error = null;
    });

    try {
      await widget.onSubmit?.call(email: _email.text);
      if (mounted) setState(() => _sent = true);
    } catch (error) {
      if (mounted) setState(() => _error = '$error');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Reset your password')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(Tokens.space4),
          children: [
            if (_sent) _Sent(email: _email.text.trim()) else ..._form(),
          ],
        ),
      ),
    );
  }

  List<Widget> _form() {
    return [
      Text(
        'We will email you a link to set a new password. Open it on this '
        'phone and you will come back here signed out, ready to sign in '
        'again.',
        style: AppType.bodyMuted,
      ),
      const SizedBox(height: Tokens.space5),
      Form(
        key: _formKey,
        child: LabelledField(
          controller: _email,
          label: 'Email',
          hint: 'The address you signed up with',
          keyboardType: TextInputType.emailAddress,
          autofocus: true,
          onSubmitted: (_) => _busy ? null : _submit(),
          validator: (v) {
            if (v == null || v.trim().isEmpty) {
              return 'Enter your email address';
            }
            if (!v.contains('@')) return 'That is not an email address';
            return null;
          },
        ),
      ),
      if (_error != null) ...[
        const SizedBox(height: Tokens.space4),
        _ErrorPanel(message: _error!),
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
                'Send the reset link',
                style: AppType.bodyStrong.copyWith(color: Tokens.shaft),
              ),
      ),
      const SizedBox(height: Tokens.space3),
      TextButton(
        onPressed: _busy ? null : () => Navigator.of(context).maybePop(),
        child: Text(
          'Back to sign in',
          style: AppType.body.copyWith(color: Tokens.beacon),
        ),
      ),
    ];
  }
}

/// What the screen says once the request has gone.
///
/// Phrased so it is true whether or not an account exists at that address.
/// It names the address, so somebody who mistyped it can see that they did.
class _Sent extends StatelessWidget {
  const _Sent({required this.email});

  final String email;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: Tokens.space4),
        const Icon(
          Icons.mark_email_read_outlined,
          size: 30,
          color: Tokens.jade,
        ),
        const SizedBox(height: Tokens.space4),
        Text('Check your email', style: AppType.heading),
        const SizedBox(height: Tokens.space2),
        Text(
          'If an account uses $email, a reset link is on its way. It is '
          'valid for one hour.',
          style: AppType.bodyMuted,
        ),
        const SizedBox(height: Tokens.space3),
        Text(
          'Nothing arrived? Check the spam folder, and check the address '
          'above is the one you signed up with.',
          style: AppType.bodyMuted,
        ),
        const SizedBox(height: Tokens.space5),
        FilledButton(
          onPressed: () => Navigator.of(context).maybePop(),
          style: FilledButton.styleFrom(
            backgroundColor: Tokens.beacon,
            foregroundColor: Tokens.shaft,
            padding: const EdgeInsets.symmetric(vertical: Tokens.space4),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(Tokens.radiusSm),
            ),
          ),
          child: Text(
            'Back to sign in',
            style: AppType.bodyStrong.copyWith(color: Tokens.shaft),
          ),
        ),
      ],
    );
  }
}

/// Shown when the request itself failed — no connection, or too many
/// attempts. Not shown for an address with no account, which is not an error
/// this screen is willing to report.
class _ErrorPanel extends StatelessWidget {
  const _ErrorPanel({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(Tokens.space3),
      decoration: BoxDecoration(
        color: Tokens.flare.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(Tokens.radiusSm),
        border: Border.all(color: Tokens.flare.withValues(alpha: 0.35)),
      ),
      child: Text(message, style: AppType.body.copyWith(color: Tokens.flare)),
    );
  }
}
