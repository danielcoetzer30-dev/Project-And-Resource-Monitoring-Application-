import 'package:flutter/material.dart';

import '../theme/tokens.dart';
import '../theme/typography.dart';

/// A text field with the app's label above it.
///
/// Extracted from the sign-in screen so the reset-password screen could not
/// drift away from it: two auth screens that look subtly different are worse
/// than either one, and a field is exactly the kind of thing that gets
/// re-typed with slightly different padding each time.
///
/// Everything resolves through [Tokens] and [AppType], so a change to the
/// palette or the type scale reaches every field in the app at once.
class LabelledField extends StatelessWidget {
  const LabelledField({
    super.key,
    required this.controller,
    required this.label,
    this.hint,
    this.obscure = false,
    this.keyboardType,
    this.validator,
    this.onSubmitted,
    this.autofocus = false,
  });

  final TextEditingController controller;

  /// Drawn above the field in the label style, upper-cased. Also what a screen
  /// reader announces, so it is a name rather than a placeholder.
  final String label;

  /// One line of help, when the label alone is not enough.
  final String? hint;

  final bool obscure;
  final TextInputType? keyboardType;

  /// Returns null when the value is acceptable, or the message to show.
  final String? Function(String?)? validator;

  /// Called when the person presses the keyboard's action key, so a one-field
  /// form can be submitted without reaching for the button.
  final ValueChanged<String>? onSubmitted;

  final bool autofocus;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label.toUpperCase(), style: AppType.label),
        const SizedBox(height: Tokens.space2),
        TextFormField(
          controller: controller,
          obscureText: obscure,
          keyboardType: keyboardType,
          validator: validator,
          onFieldSubmitted: onSubmitted,
          autofocus: autofocus,
          style: AppType.body,
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: AppType.bodyMuted,
            filled: true,
            fillColor: Tokens.seam,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: Tokens.space3,
              vertical: Tokens.space3,
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(Tokens.radiusSm),
              borderSide: const BorderSide(color: Tokens.rule),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(Tokens.radiusSm),
              borderSide: const BorderSide(color: Tokens.rule),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(Tokens.radiusSm),
              borderSide: const BorderSide(color: Tokens.beacon, width: 1.5),
            ),
          ),
        ),
      ],
    );
  }
}
