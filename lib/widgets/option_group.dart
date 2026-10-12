import 'package:flutter/material.dart';

import '../theme/tokens.dart';
import '../theme/typography.dart';

/// Rows separated by hairlines.
class OptionGroup extends StatelessWidget {
  const OptionGroup({super.key, required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        for (var i = 0; i < children.length; i++) ...[
          if (i > 0) const Divider(height: Tokens.hairline),
          children[i],
        ],
      ],
    );
  }
}

/// One choice in a set of mutually exclusive choices.
///
/// Drawn by hand rather than with the Material radio widgets so it matches the
/// other settings rows, and so it does not depend on the radio API, which has
/// changed between Flutter versions.
class OptionRow extends StatelessWidget {
  const OptionRow({
    super.key,
    required this.label,
    required this.selected,
    required this.onTap,
    this.example,
    this.description,
  });

  final String label;

  /// What the option looks like, shown on the right in the data face.
  final String? example;

  /// A sentence under the label, for options that need one.
  final String? description;

  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final spoken = [label, ?example, ?description].join(', ');

    return Semantics(
      label: spoken,
      inMutuallyExclusiveGroup: true,
      checked: selected,
      onTap: onTap,
      excludeSemantics: true,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(Tokens.space4),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.only(top: 1),
                child: Icon(
                  selected
                      ? Icons.radio_button_checked
                      : Icons.radio_button_unchecked,
                  size: 18,
                  color: selected ? Tokens.beacon : Tokens.slate,
                ),
              ),
              const SizedBox(width: Tokens.space3),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(label, style: AppType.bodyStrong),
                    if (description != null) ...[
                      const SizedBox(height: Tokens.space1),
                      Text(description!, style: AppType.bodyMuted),
                    ],
                  ],
                ),
              ),
              if (example != null) ...[
                const SizedBox(width: Tokens.space3),
                Text(example!, style: AppType.data),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
