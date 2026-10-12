import 'package:shared_preferences/shared_preferences.dart';

import '../models/preferences.dart';

/// Keeps display preferences on this device.
///
/// Preferences are a convenience, never something the app depends on, so a
/// storage failure falls back to the defaults instead of surfacing an error.
class PreferencesStore {
  const PreferencesStore();

  static const _dateKey = 'preferences.dateStyle';
  static const _timeKey = 'preferences.timeStyle';
  static const _densityKey = 'preferences.density';
  static const _textSizeKey = 'preferences.textSize';
  static const _boldKey = 'preferences.boldText';
  static const _startTabKey = 'preferences.startTab';
  static const _signalLimitKey = 'preferences.signalLimit';
  static const _gridStripKey = 'preferences.showGridStrip';

  Future<Preferences> load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return Preferences(
        dateStyle: _read(
          DateStyle.values,
          prefs.getString(_dateKey),
          DateStyle.dayMonthName,
        ),
        timeStyle: _read(
          TimeStyle.values,
          prefs.getString(_timeKey),
          TimeStyle.h24,
        ),
        density: _read(
          UiDensity.values,
          prefs.getString(_densityKey),
          UiDensity.comfortable,
        ),
        textSize: _read(
          TextSize.values,
          prefs.getString(_textSizeKey),
          TextSize.standard,
        ),
        boldText: prefs.getBool(_boldKey) ?? false,
        startTab: _read(
          StartTab.values,
          prefs.getString(_startTabKey),
          StartTab.home,
        ),
        signalLimit: _limit(prefs.getInt(_signalLimitKey)),
        showGridStrip: prefs.getBool(_gridStripKey) ?? true,
      );
    } catch (_) {
      return const Preferences();
    }
  }

  Future<void> save(Preferences preferences) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_dateKey, preferences.dateStyle.name);
      await prefs.setString(_timeKey, preferences.timeStyle.name);
      await prefs.setString(_densityKey, preferences.density.name);
      await prefs.setString(_textSizeKey, preferences.textSize.name);
      await prefs.setBool(_boldKey, preferences.boldText);
      await prefs.setString(_startTabKey, preferences.startTab.name);
      await prefs.setInt(_signalLimitKey, preferences.signalLimit);
      await prefs.setBool(_gridStripKey, preferences.showGridStrip);
    } catch (_) {
      // Not saving is acceptable; the choice still applies this session.
    }
  }

  /// Only the offered limits are accepted, so an odd stored value cannot leave
  /// the dashboard with a count nobody can choose.
  static int _limit(int? stored) =>
      Preferences.signalLimits.contains(stored) ? stored! : 5;

  /// Looks a stored name up in an enum, falling back if it is missing or from
  /// an older version of the app that no longer has that value.
  static T _read<T extends Enum>(List<T> values, String? name, T fallback) {
    for (final value in values) {
      if (value.name == name) return value;
    }
    return fallback;
  }
}
