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

  @override
  Preferences build() {
    // The defaults show until the saved values arrive, which is a few
    // milliseconds after launch.
    unawaited(_loadSaved());
    return const Preferences();
  }

  Future<void> _loadSaved() async {
    final saved = await _store.load();
    _apply(saved, persist: false);
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
    ),
  );

  void setAccessibility({required TextSize textSize, required bool boldText}) =>
      _apply(state.copyWith(textSize: textSize, boldText: boldText));

  void _apply(Preferences next, {bool persist = true}) {
    DateFormatting.configure(
      dateStyle: next.dateStyle,
      timeStyle: next.timeStyle,
    );
    state = next;
    if (persist) unawaited(_store.save(next));
  }
}
