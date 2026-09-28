import 'package:flutter/material.dart';

import '../theme/tokens.dart';
import '../theme/typography.dart';

/// A hairline-ruled instrument panel.
///
/// Depth comes from a surface step and a one-pixel rule, not from shadows —
/// shadows on a dark base turn into mud, and the app is meant to read as a
/// panel of instruments rather than a stack of floating cards.
class Panel extends StatelessWidget {
  const Panel({
    super.key,
    required this.child,
    this.title,
    this.trailing,
    this.padding = const EdgeInsets.all(Tokens.space4),
  });

  final Widget child;
  final String? title;
  final Widget? trailing;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Tokens.seam,
        borderRadius: BorderRadius.circular(Tokens.radiusMd),
        border: Border.all(color: Tokens.rule, width: Tokens.hairline),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          if (title != null) ...[
            Padding(
              padding: const EdgeInsets.fromLTRB(
                Tokens.space4,
                Tokens.space3,
                Tokens.space3,
                Tokens.space3,
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(title!.toUpperCase(), style: AppType.label),
                  ),
                  ?trailing,
                ],
              ),
            ),
            const Divider(height: Tokens.hairline),
          ],
          Padding(padding: padding, child: child),
        ],
      ),
    );
  }
}
