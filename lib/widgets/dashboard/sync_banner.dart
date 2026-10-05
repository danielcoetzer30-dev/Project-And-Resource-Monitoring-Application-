import 'package:flutter/material.dart';

import '../../../theme/tokens.dart';
import '../../../theme/typography.dart';

/// Tells the team how old the numbers on screen are.
///
/// The app is built for unreliable connectivity, so "when was this true?" is
/// information, not an error. Neutral styling: being offline during an outage
/// is not a health state, and it should not borrow the signal ramp.
class SyncBanner extends StatelessWidget {
  const SyncBanner({super.key, required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      liveRegion: true,
      child: Container(
        padding: const EdgeInsets.all(Tokens.space3),
        decoration: BoxDecoration(
          color: Tokens.seam,
          borderRadius: BorderRadius.circular(Tokens.radiusMd),
          border: Border.all(color: Tokens.rule, width: Tokens.hairline),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Padding(
              padding: EdgeInsets.only(top: Tokens.space1),
              child: Icon(
                Icons.cloud_off_outlined,
                size: 16,
                color: Tokens.slate,
              ),
            ),
            const SizedBox(width: Tokens.space3),
            Expanded(child: Text(message, style: AppType.bodyMuted)),
          ],
        ),
      ),
    );
  }
}
