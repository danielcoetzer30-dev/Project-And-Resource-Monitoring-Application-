import 'package:flutter/material.dart';

import '../theme/tokens.dart';
import '../theme/typography.dart';

/// A label, a value, and optionally how it has moved.
///
/// Numbers use the tabular styles from AppType, so a value updating live does
/// not shift the labels around it.
class MetricTile extends StatelessWidget {
  const MetricTile({
    super.key,
    required this.label,
    required this.value,
    this.delta,
    this.deltaIsGood,
    this.valueColor,
    this.compact = false,
  });

  final String label;
  final String value;

  /// Change since the last window, already formatted, e.g. "-12%".
  final String? delta;

  /// Whether that change is a good thing. Falling budget burn is good; falling
  /// velocity is not, so direction alone cannot decide the colour.
  final bool? deltaIsGood;

  final Color? valueColor;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: '$label: $value${delta == null ? '' : ', change $delta'}',
      excludeSemantics: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(label.toUpperCase(), style: AppType.label),
          const SizedBox(height: Tokens.space2),
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                value,
                style: (compact ? AppType.metricSmall : AppType.metric)
                    .copyWith(color: valueColor ?? Tokens.chalk),
              ),
              if (delta != null) ...[
                const SizedBox(width: Tokens.space2),
                Text(delta!, style: AppType.data.copyWith(color: _deltaColour)),
              ],
            ],
          ),
        ],
      ),
    );
  }

  Color get _deltaColour {
    if (deltaIsGood == null) return Tokens.slate;
    return deltaIsGood! ? Tokens.jade : Tokens.ember;
  }
}
