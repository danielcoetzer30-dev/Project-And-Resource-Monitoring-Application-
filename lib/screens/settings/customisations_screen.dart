import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/utils/date_format.dart';
import '../../models/preferences.dart';
import '../../state/providers.dart';
import '../../theme/tokens.dart';
import '../../theme/typography.dart';
import '../../widgets/option_group.dart';
import '../../widgets/panel.dart';

/// How dates, times and controls are shown.
///
/// Every choice applies the moment it is made and is kept on this device, so
/// there is no Save button: a preference you have to confirm is one you cannot
/// see the effect of first.
class CustomisationsScreen extends ConsumerWidget {
  const CustomisationsScreen({super.key});

  static const _dateOptions = <DateStyle, String>{
    DateStyle.dayMonthName: 'Day and month name',
    DateStyle.dayMonthYear: 'Day / month / year',
    DateStyle.monthDayYear: 'Month / day / year',
    DateStyle.iso: 'Year-month-day',
  };

  static const _timeOptions = <TimeStyle, String>{
    TimeStyle.h24: '24-hour',
    TimeStyle.h12: '12-hour',
  };

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final prefs = ref.watch(preferencesProvider);
    final notifier = ref.read(preferencesProvider.notifier);

    // One moment, formatted every way, so each option previews itself.
    final now = DateTime.now();

    return Scaffold(
      appBar: AppBar(title: const Text('Customisations')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(
          Tokens.space4,
          Tokens.space2,
          Tokens.space4,
          Tokens.space7,
        ),
        children: [
          Text(
            'Changes apply straight away and are kept on this device.',
            style: AppType.bodyMuted,
          ),
          const SizedBox(height: Tokens.space4),
          Panel(
            title: 'Date format',
            padding: EdgeInsets.zero,
            child: OptionGroup(
              children: [
                for (final entry in _dateOptions.entries)
                  OptionRow(
                    label: entry.value,
                    example: DateFormatting.mediumDateAs(entry.key, now),
                    selected: prefs.dateStyle == entry.key,
                    onTap: () => notifier.setDateStyle(entry.key),
                  ),
              ],
            ),
          ),
          const SizedBox(height: Tokens.space4),
          Panel(
            title: 'Time format',
            padding: EdgeInsets.zero,
            child: OptionGroup(
              children: [
                for (final entry in _timeOptions.entries)
                  OptionRow(
                    label: entry.value,
                    example: DateFormatting.timeAs(entry.key, now),
                    selected: prefs.timeStyle == entry.key,
                    onTap: () => notifier.setTimeStyle(entry.key),
                  ),
              ],
            ),
          ),
          const SizedBox(height: Tokens.space4),
          Panel(
            title: 'Density',
            padding: EdgeInsets.zero,
            child: OptionGroup(
              children: [
                OptionRow(
                  label: 'Comfortable',
                  description: 'Standard spacing throughout.',
                  selected: prefs.density == UiDensity.comfortable,
                  onTap: () => notifier.setDensity(UiDensity.comfortable),
                ),
                OptionRow(
                  label: 'Compact',
                  description:
                      'Tighter panels, project rows, settings rows and '
                      'buttons, so more fits on one screen. Touch areas '
                      'stay full size.',
                  selected: prefs.density == UiDensity.compact,
                  onTap: () => notifier.setDensity(UiDensity.compact),
                ),
              ],
            ),
          ),
          const SizedBox(height: Tokens.space4),
          Panel(
            title: 'Start screen',
            padding: EdgeInsets.zero,
            child: OptionGroup(
              children: [
                for (final tab in StartTab.values)
                  OptionRow(
                    label: tab.label,
                    selected: prefs.startTab == tab,
                    onTap: () => notifier.setStartTab(tab),
                  ),
              ],
            ),
          ),
          const SizedBox(height: Tokens.space4),
          Panel(
            title: 'Signals on the dashboard',
            padding: EdgeInsets.zero,
            child: OptionGroup(
              children: [
                for (final count in Preferences.signalLimits)
                  OptionRow(
                    label: '$count signals',
                    selected: prefs.signalLimit == count,
                    onTap: () => notifier.setSignalLimit(count),
                  ),
              ],
            ),
          ),
          const SizedBox(height: Tokens.space4),
          Panel(
            title: 'Grid strip',
            padding: EdgeInsets.zero,
            child: SwitchListTile(
              value: prefs.showGridStrip,
              onChanged: notifier.setShowGridStrip,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: Tokens.space4,
              ),
              title: Text('Show on the dashboard', style: AppType.bodyStrong),
              subtitle: Text(
                'The load-shedding strip at the top of the Projects tab. The '
                'Schedule tab still reports the hours either way.',
                style: AppType.bodyMuted,
              ),
            ),
          ),
          const SizedBox(height: Tokens.space4),
          Panel(
            title: 'Notifications',
            padding: EdgeInsets.zero,
            child: SwitchListTile(
              value: prefs.notifyOnDecline,
              // Routed through the alert notifier rather than straight to the
              // preference: turning it on asks the platform for permission
              // first, and a refusal has to leave the switch off rather than
              // claiming to be on while nothing can be shown.
              onChanged: (wanted) async {
                final messenger = ScaffoldMessenger.of(context);
                final granted = await ref
                    .read(alertNotifierProvider.notifier)
                    .setEnabled(wanted);

                if (wanted && !granted) {
                  messenger.showSnackBar(
                    const SnackBar(
                      content: Text(
                        'Notifications are switched off for Keel in your '
                        'phone settings. Turn them on there and try again.',
                      ),
                    ),
                  );
                }
              },
              contentPadding: const EdgeInsets.symmetric(
                horizontal: Tokens.space4,
              ),
              title: Text(
                'Tell me when a project declines',
                style: AppType.bodyStrong,
              ),
              subtitle: Text(
                'A notification when a project moves into at risk or '
                'critical, and when one recovers. Once per change, never '
                'once per day — and nothing about a person, only a '
                'project.',
                style: AppType.bodyMuted,
              ),
            ),
          ),
          const SizedBox(height: Tokens.space5),
          TextButton(
            onPressed: prefs.displayIsDefault
                ? null
                : notifier.resetDisplayToDefaults,
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
    );
  }
}
