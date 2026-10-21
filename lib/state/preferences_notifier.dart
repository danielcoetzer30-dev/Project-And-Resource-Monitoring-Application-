import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/utils/date_format.dart';
import '../data/preferences_store.dart';
import '../models/preferences.dart';
import 'providers.dart';

/// Owns the display preferences.
///
/// Every change applies at once and is saved in the background. Date and time
/// formatting is read through static helpers rather than through a widget's
/// context, so each change is also pushed into [DateFormatting] here.
class PreferencesNotifier extends Notifier<Preferences> {
  late final PreferencesStore _store = ref.read(preferencesStoreProvider);

  /// True once somebody has changed a preference in this session.
  ///
  /// The saved values arrive a few milliseconds after launch, and anything
  /// changed before they do used to be silently overwritten by them. That is
  /// a narrow window, but it is exactly the window somebody toggling a switch
  /// on the Customisations screen during a cold start falls into, and losing
  /// a setting you just chose is the kind of bug nobody reports because it
  /// looks like they mis-tapped.
  bool _touched = false;

  @override
  Preferences build() {
    // The defaults show until the saved values arrive, which is a few
    // milliseconds after launch.
    unawaited(_loadSaved());
    return const Preferences();
  }

  Future<void> _loadSaved() async {
    final saved = await _store.load();

    // A choice made while this was in flight wins. The stored values are what
    // the person wanted last time; what they just tapped is what they want
    // now.
    if (_touched) return;

    _apply(saved, persist: false, touch: false);
  }

  void setDateStyle(DateStyle value) =>
      _apply(state.copyWith(dateStyle: value));

  void setTimeStyle(TimeStyle value) =>
      _apply(state.copyWith(timeStyle: value));

  void setDensity(UiDensity value) => _apply(state.copyWith(density: value));

  void setStartTab(StartTab value) => _apply(state.copyWith(startTab: value));

  void setSignalLimit(int value) => _apply(state.copyWith(signalLimit: value));

  void setShowGridStrip(bool value) =>
      _apply(state.copyWith(showGridStrip: value));

  /// Awaited, unlike its neighbours, because the caller needs to know the
  /// value has been written before it reports what happened: turning
  /// notifications on can be refused by the platform, and the switch has to
  /// end up showing what is actually true.
  Future<void> setNotifyOnDecline(bool value) async {
    _apply(state.copyWith(notifyOnDecline: value), persist: false);
    await _store.save(state);
  }

  /// Puts date, time, density, start tab and the dashboard choices back.
  /// Accessibility is left alone, because it has its own reset — somebody who
  /// needs large text should not lose it by tidying up their date format.
  void resetDisplayToDefaults() => _apply(
    state.copyWith(
      dateStyle: DateStyle.dayMonthName,
      timeStyle: TimeStyle.h24,
      density: UiDensity.comfortable,
      startTab: StartTab.home,
      signalLimit: 5,
      showGridStrip: true,
      notifyOnDecline: false,
    ),
  );

  void setAccessibility({required TextSize textSize, required bool boldText}) =>
      _apply(state.copyWith(textSize: textSize, boldText: boldText));

  void _apply(Preferences next, {bool persist = true, bool touch = true}) {
    if (touch) _touched = true;

    DateFormatting.configure(
      dateStyle: next.dateStyle,
      timeStyle: next.timeStyle,
    );
    state = next;
    if (persist) unawaited(_store.save(next));
  }
}
