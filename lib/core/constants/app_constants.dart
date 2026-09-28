/// Values that would otherwise be typed as string literals in several places.
///
/// Collection names live here because a typo in one of them fails silently:
/// Firestore happily reads from a collection that does not exist and returns
/// nothing, which looks identical to "no data yet".
abstract final class AppConstants {
  //FireStore collections

  static const usersCollection = 'users';
  static const organisationsCollection = 'organisations';
  static const projectsCollection = 'projects';
  static const squadsCollection = 'squads';
  static const signalsCollection = 'signals';
  static const outagesCollection = 'outages';
  static const settingsCollection = 'settings';

  /// Document id for the single settings document per organisation.

  static const scoringWeightsDoc = 'scoringweights';

  ///Ingestion
  ///how often does ingestion polls its sources when device is online
  static const pollInterval = Duration(minutes: 15);

  ///Data that is older than this is considered/shown as stale with the warning
  static const staleAfter = Duration(hours: 6);

  ///Scoring
  ///days of history a health Seam shows by default.
  static const seamWindowDays = 30;
}
