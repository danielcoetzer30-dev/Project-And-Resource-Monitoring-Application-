/// How dates are written.
enum DateStyle {
  /// "12 Sep 2026", the style the app has always used.
  dayMonthName,

  /// "12/09/2026"
  dayMonthYear,

  /// "09/12/2026"
  monthDayYear,

  /// "2026-09-12"
  iso,
}

/// 24-hour or 12-hour clock.
enum TimeStyle {
  /// "14:05", how load-shedding schedules are published.
  h24,

  /// "2:05 pm"
  h12,
}

/// How tightly Material controls are packed.
enum UiDensity { comfortable, compact }

/// Which tab the app opens on.
///
/// The order matches `_sections` in the shell: Home first, then the data
/// sections, so [index] can be used directly. If a tab is added, renamed or
/// folded away there, change it here too, and note that the stored value is
/// the enum's `name`, so a removed value falls back to Home rather than
/// opening the wrong screen.
/// Which tab the app opens on.
///
/// The enum *name* is what gets stored on the device, so renaming one of these
/// identifiers silently invalidates every saved preference, which is why the
/// renamed tabs changed only their labels. `health` is the
/// Projects tab, `squads` is Capacity and `week` is Schedule. The labels have
/// to match the titles in `AppShell._sections`, because the index is used
/// directly.
enum StartTab {
  home('Home'),
  health('Projects'),
  squads('Capacity'),
  signals('Signals'),
  week('Schedule'),
  ask('Ask');

  const StartTab(this.label);

  final String label;
}

/// How large text is drawn, on top of the phone's own text size setting.
enum TextSize {
  small(0.85, 'Small'),
  standard(1.0, 'Default'),
  large(1.2, 'Large');

  const TextSize(this.scale, this.label);

  final double scale;
  final String label;
}

/// Display and accessibility preferences.
///
/// Date, time and density live under Customisations and apply at once. Text
/// size and bold text live under Accessibility and apply when saved.
///
/// The defaults reproduce how the app looked before this existed, so nobody
/// sees a change until they choose one.
class Preferences {
  const Preferences({
    this.dateStyle = DateStyle.dayMonthName,
    this.timeStyle = TimeStyle.h24,
    this.density = UiDensity.comfortable,
    this.textSize = TextSize.standard,
    this.boldText = false,
    this.startTab = StartTab.home,
    this.signalLimit = 5,
    this.showGridStrip = true,
    this.notifyOnDecline = false,
  });

  /// The choices offered for how many signals the dashboard lists.
  static const signalLimits = [3, 5, 10];

  final DateStyle dateStyle;
  final TimeStyle timeStyle;
  final UiDensity density;
  final TextSize textSize;
  final bool boldText;
  final StartTab startTab;
  final int signalLimit;
  final bool showGridStrip;

  /// Whether a project crossing into or out of a failing state raises a
  /// notification on this device.
  ///
  /// Off by default, and deliberately. Notifications are the one thing this
  /// app does that reaches somebody who did not open it, so it is a choice
  /// rather than something that starts happening after an update.
  final bool notifyOnDecline;

  /// True when nothing under Customisations has been changed, so its "Reset to
  /// defaults" can switch itself off. Accessibility choices are not counted.
  bool get displayIsDefault =>
      dateStyle == DateStyle.dayMonthName &&
      timeStyle == TimeStyle.h24 &&
      density == UiDensity.comfortable &&
      startTab == StartTab.home &&
      signalLimit == 5 &&
      showGridStrip &&
      !notifyOnDecline;

  /// True when text size and bold text are both at their defaults.
  bool get accessibilityIsDefault => textSize == TextSize.standard && !boldText;

  Preferences copyWith({
    DateStyle? dateStyle,
    TimeStyle? timeStyle,
    UiDensity? density,
    TextSize? textSize,
    bool? boldText,
    StartTab? startTab,
    int? signalLimit,
    bool? showGridStrip,
    bool? notifyOnDecline,
  }) {
    return Preferences(
      dateStyle: dateStyle ?? this.dateStyle,
      timeStyle: timeStyle ?? this.timeStyle,
      density: density ?? this.density,
      textSize: textSize ?? this.textSize,
      boldText: boldText ?? this.boldText,
      startTab: startTab ?? this.startTab,
      signalLimit: signalLimit ?? this.signalLimit,
      showGridStrip: showGridStrip ?? this.showGridStrip,
      notifyOnDecline: notifyOnDecline ?? this.notifyOnDecline,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Preferences &&
          other.dateStyle == dateStyle &&
          other.timeStyle == timeStyle &&
          other.density == density &&
          other.textSize == textSize &&
          other.boldText == boldText &&
          other.startTab == startTab &&
          other.signalLimit == signalLimit &&
          other.showGridStrip == showGridStrip &&
          other.notifyOnDecline == notifyOnDecline;

  @override
  int get hashCode => Object.hash(
    dateStyle,
    timeStyle,
    density,
    textSize,
    boldText,
    startTab,
    signalLimit,
    showGridStrip,
    notifyOnDecline,
  );
}
