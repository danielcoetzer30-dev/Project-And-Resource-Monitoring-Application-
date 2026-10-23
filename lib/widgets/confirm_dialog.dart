import 'package:flutter/material.dart';

import '../theme/tokens.dart';
import '../theme/typography.dart';

/// Asks before something that is hard to undo.
///
/// One widget rather than a dialog written out at each call site, because the
/// thing that makes a confirmation useful is that it reads the same every
/// time: the same shape, the same button order, and the destructive action
/// always on the right in the warning colour. A dialog that moves its buttons
/// around trains people to tap without reading.
///
/// It states what will happen rather than asking "are you sure?", somebody
/// who has to ask themselves whether they are sure has not been told what the
/// button does.
class ConfirmDialog extends StatelessWidget {
  const ConfirmDialog({
    super.key,
    required this.title,
    required this.body,
    required this.confirmLabel,
    this.cancelLabel = 'Cancel',
    this.isDestructive = true,
  });

  /// What is about to happen, as a short statement.
  final String title;

  /// The consequence, including anything that cannot be undone.
  final String body;

  /// Names the action, "Archive", "Remove", never "OK". A button labelled
  /// OK next to a question is the one people tap by reflex.
  final String confirmLabel;

  final String cancelLabel;

  /// Colours the confirm button as a warning. False for a confirmation that
  /// is merely important rather than damaging.
  final bool isDestructive;

  /// Shows the dialog and returns true only if the person confirmed.
  ///
  /// Dismissing by tapping outside or pressing back returns null, which this
  /// reports as false: the safe reading of "went away" is "did not mean to".
  static Future<bool> show(
    BuildContext context, {
    required String title,
    required String body,
    required String confirmLabel,
    String cancelLabel = 'Cancel',
    bool isDestructive = true,
  }) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => ConfirmDialog(
        title: title,
        body: body,
        confirmLabel: confirmLabel,
        cancelLabel: cancelLabel,
        isDestructive: isDestructive,
      ),
    );

    return confirmed ?? false;
  }

  @override
  Widget build(BuildContext context) {
    final accent = isDestructive ? Tokens.flare : Tokens.beacon;

    return AlertDialog(
      backgroundColor: Tokens.seam,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(Tokens.radiusMd),
        side: const BorderSide(color: Tokens.rule, width: Tokens.hairline),
      ),
      title: Text(title, style: AppType.heading),
      content: Text(body, style: AppType.bodyMuted),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: Text(
            cancelLabel,
            style: AppType.body.copyWith(color: Tokens.slate),
          ),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(true),
          style: FilledButton.styleFrom(
            backgroundColor: accent,
            foregroundColor: Tokens.shaft,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(Tokens.radiusSm),
            ),
          ),
          child: Text(
            confirmLabel,
            style: AppType.bodyStrong.copyWith(color: Tokens.shaft),
          ),
        ),
      ],
    );
  }
}
