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

  /// Subcollection of a signal: the discussion about why it fired.
  static const commentsCollection = 'comments';
  static const outagesCollection = 'outages';

  /// Repositories and trackers ingestion reads from. One of the three things
  /// a client may write, and gated to leads and managers.
  static const sourcesCollection = 'sources';

  /// What a team states about a project: name, client, squad, budget, dates
  /// and rostered hours. Ingestion creates the `projects` document from it.
  static const projectPlansCollection = 'projectPlans';
  static const settingsCollection = 'settings';

  /// Who can be messaged: display name and role, nothing else.
  static const directoryCollection = 'directory';

  /// Who is on which squad. One field per document, `squadId`, keyed by uid.
  /// the name and role a roster shows are read from the directory, so this is
  /// not a second place a person's details accumulate. See
  /// `lib/models/squad_member.dart` for what adding it cost.
  static const squadMembersCollection = 'squadMembers';
  static const conversationsCollection = 'conversations';

  /// Subcollection of a conversation.
  static const messagesCollection = 'messages';

  /// Document id for the single settings document per organisation.

  static const scoringWeightsDoc = 'scoringweights';

  /// Most recent comments a thread loads. Bounds the reads for one signal, so a
  /// long argument cannot quietly become an expensive screen to open.
  static const commentsShown = 100;

  /// Most recent messages a conversation loads, for the same reason.
  static const messagesShown = 200;

  ///Ingestion
  ///how often does ingestion polls its sources when device is online
  static const pollInterval = Duration(minutes: 15);

  ///Data that is older than this is considered/shown as stale with the warning
  static const staleAfter = Duration(hours: 6);

  ///Scoring
  ///days of history a health Seam shows by default.
  static const seamWindowDays = 30;
}
