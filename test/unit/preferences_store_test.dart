import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:prahm/data/preferences_store.dart';
import 'package:prahm/models/preferences.dart';
import 'package:prahm/state/providers.dart';

/// Preferences are a convenience, never something the app depends on, so the
/// behaviour that matters is what happens when storage is empty, stale or
/// holding something the app no longer understands.
void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  const store = PreferencesStore();

  test(
    'an empty device gets the defaults, which is how the app looked',
    () async {
      final loaded = await store.load();

      expect(loaded, const Preferences());
      expect(loaded.displayIsDefault, isTrue);
      expect(loaded.accessibilityIsDefault, isTrue);
    },
  );

  test('every choice survives a round trip', () async {
    const chosen = Preferences(
      dateStyle: DateStyle.iso,
      timeStyle: TimeStyle.h12,
      density: UiDensity.compact,
      textSize: TextSize.large,
      boldText: true,
      startTab: StartTab.week,
      signalLimit: 10,
      showGridStrip: false,
    );

    await store.save(chosen);

    expect(await store.load(), chosen);
  });

  test('a tab that no longer exists falls back to Home', () async {
    // What a device holds after the Grid tab was folded into Week: the stored
    // name is real, but the enum value is gone. Opening the wrong screen would
    // be worse than ignoring the preference.
    SharedPreferences.setMockInitialValues({'preferences.startTab': 'grid'});

    expect((await store.load()).startTab, StartTab.home);
  });

  test('a signal count nobody can choose is not honoured', () async {
    SharedPreferences.setMockInitialValues({'preferences.signalLimit': 7});

    final loaded = await store.load();

    expect(Preferences.signalLimits.contains(loaded.signalLimit), isTrue);
    expect(loaded.signalLimit, 5);
  });

  test('an unreadable enum name does not take the rest down with it', () async {
    SharedPreferences.setMockInitialValues({
      'preferences.dateStyle': 'klingon',
      'preferences.timeStyle': TimeStyle.h12.name,
    });

    final loaded = await store.load();

    expect(loaded.dateStyle, DateStyle.dayMonthName);
    expect(loaded.timeStyle, TimeStyle.h12);
  });

  test('a choice made during launch is not overwritten by the saved one', () {
    // The saved values arrive a few milliseconds after launch, and a toggle
    // flipped before they land used to be silently reverted by them. Narrow,
    // but it is exactly the window somebody tapping a switch on a cold start
    // falls into, and a setting that quietly undoes itself reads as a
    // mis-tap rather than as a bug.
    SharedPreferences.setMockInitialValues({
      'preferences.showGridStrip': false,
      'preferences.notifyOnDecline': false,
    });

    final container = ProviderContainer();
    addTearDown(container.dispose);

    final notifier = container.read(preferencesProvider.notifier);

    // Before the load can complete.
    notifier.setShowGridStrip(true);

    return Future<void>.delayed(const Duration(milliseconds: 50), () {
      expect(
        container.read(preferencesProvider).showGridStrip,
        isTrue,
        reason: 'the stored value must not clobber a choice just made',
      );
    });
  });
}
