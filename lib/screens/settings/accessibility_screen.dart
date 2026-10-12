import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/preferences.dart';
import '../../state/providers.dart';
import '../../theme/density.dart';
import '../../theme/tokens.dart';
import '../../theme/typography.dart';
import '../../widgets/option_group.dart';
import '../../widgets/panel.dart';

/// Text size and bold text.
///
/// Unlike Customisations, these changes wait for a Save. Text size changes
/// every screen at once, so a person should see what they are choosing (the
/// preview) and confirm it, rather than have the app resize under their thumb.
class AccessibilityScreen extends ConsumerStatefulWidget {
  const AccessibilityScreen({super.key});

  @override
  ConsumerState<AccessibilityScreen> createState() =>
      _AccessibilityScreenState();
}

class _AccessibilityScreenState extends ConsumerState<AccessibilityScreen> {
  // Null means "not edited yet", so an untouched screen always follows the
  // saved value, including when it arrives a moment after launch.
  TextSize? _textSize;
  bool? _boldText;
  bool _leaving = false;

  @override
  Widget build(BuildContext context) {
    final saved = ref.watch(preferencesProvider);
    final textSize = _textSize ?? saved.textSize;
    final boldText = _boldText ?? saved.boldText;

    final dirty = textSize != saved.textSize || boldText != saved.boldText;
    final atDefaults = textSize == TextSize.standard && !boldText;

    // The page itself already runs at the saved size. Dividing it back out
    // leaves the phone's own setting, which the preview then rescales.
    final media = MediaQuery.of(context);
    final system = media.textScaler.scale(1) / saved.textSize.scale;
    final previewScaler = TextScaler.linear(
      (system * textSize.scale).clamp(0.8, 2.0),
    );

    return PopScope(
      canPop: !dirty || _leaving,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        final discard = await _confirmDiscard(context);
        if (discard != true || !mounted) return;
        setState(() => _leaving = true);
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) Navigator.of(context).pop();
        });
      },
      child: Scaffold(
        appBar: AppBar(title: const Text('Accessibility')),
        body: ListView(
          padding: EdgeInsets.fromLTRB(
            Tokens.space4,
            Tokens.space2,
            Tokens.space4,
            Tokens.space7,
          ),
          children: [
            Text(
              'Changes apply to the whole app once you save them.',
              style: AppType.bodyMuted,
            ),
            const SizedBox(height: Tokens.space4),
            Panel(
              title: 'Text size',
              padding: EdgeInsets.zero,
              child: OptionGroup(
                children: [
                  for (final size in TextSize.values)
                    OptionRow(
                      label: size.label,
                      selected: textSize == size,
                      onTap: () => setState(() => _textSize = size),
                    ),
                ],
              ),
            ),
            const SizedBox(height: Tokens.space4),
            Panel(
              title: 'Bold text',
              padding: EdgeInsets.zero,
              child: SwitchListTile(
                value: boldText,
                onChanged: (value) => setState(() => _boldText = value),
                contentPadding: EdgeInsets.symmetric(
                  horizontal: context.dense(Tokens.space4),
                ),
                title: Text('Bold text', style: AppType.bodyStrong),
                subtitle: Text(
                  'Makes all text heavier, so it stands out more against the '
                  'dark background.',
                  style: AppType.bodyMuted,
                ),
              ),
            ),
            const SizedBox(height: Tokens.space4),
            Panel(
              title: 'Preview',
              child: MediaQuery(
                data: media.copyWith(
                  textScaler: previewScaler,
                  boldText: boldText,
                ),
                // The preview is decoration for sighted people; screen readers
                // already get the real controls above.
                child: ExcludeSemantics(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Project health', style: AppType.heading),
                      const SizedBox(height: Tokens.space1),
                      Text(
                        'Two signals need attention. Open one to see the '
                        'reason it was raised.',
                        style: AppType.bodyMuted,
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: Tokens.space5),
            FilledButton(
              onPressed: dirty ? () => _save(textSize, boldText) : null,
              child: const Text('Save changes'),
            ),
            const SizedBox(height: Tokens.space2),
            TextButton(
              onPressed: atDefaults
                  ? null
                  : () => setState(() {
                      _textSize = TextSize.standard;
                      _boldText = false;
                    }),
              style: TextButton.styleFrom(
                foregroundColor: Tokens.beacon,
                disabledForegroundColor: Tokens.slate.withValues(alpha: 0.5),
                textStyle: AppType.bodyStrong,
                padding: const EdgeInsets.symmetric(vertical: Tokens.space3),
              ),
              child: const Text('Reset to defaults'),
            ),
          ],
        ),
      ),
    );
  }

  void _save(TextSize textSize, bool boldText) {
    ref
        .read(preferencesProvider.notifier)
        .setAccessibility(textSize: textSize, boldText: boldText);
    setState(() {
      _textSize = null;
      _boldText = null;
    });
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Saved')));
  }

  Future<bool?> _confirmDiscard(BuildContext context) {
    return showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Discard changes?'),
        content: const Text('You have changes that are not saved yet.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Keep editing'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Discard'),
          ),
        ],
      ),
    );
  }
}
