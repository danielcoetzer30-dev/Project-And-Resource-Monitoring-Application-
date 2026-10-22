import 'package:cloud_firestore/cloud_firestore.dart';

import '../../models/ingestion_source.dart';

/// Converts between a Firestore document and an [IngestionSource].
///
/// [toMap] writes exactly four fields and never a credential. The security
/// rules refuse a source document carrying `token`, `accessToken` or `apiKey`,
/// so adding one here would not quietly succeed — it would fail every write.
/// That is the intended behaviour, not an obstacle to work around.
///
/// `lastSyncedAt` is written by ingestion, never by the app, so it is read
/// here and deliberately not sent back.
abstract final class SourceDto {
  static IngestionSource fromDoc(
    DocumentSnapshot<Map<String, dynamic>> doc,
    String orgId,
  ) {
    final data = doc.data() ?? <String, dynamic>{};

    return IngestionSource(
      id: doc.id,
      type: SourceType.fromName(data['type'] as String? ?? ''),
      label: data['label'] as String? ?? 'Unnamed source',
      remoteId: data['remoteId'] as String? ?? '',
      orgId: orgId,
      // Absent means on. A source somebody added before this field existed
      // should keep being read, not silently stop.
      isEnabled: data['isEnabled'] as bool? ?? true,
      squadId: data['squadId'] as String? ?? '',
      lastSyncedAt: (data['lastSyncedAt'] as Timestamp?)?.toDate(),
    );
  }

  static Map<String, dynamic> toMap(IngestionSource source) {
    return {
      'type': source.type.name,
      'label': source.label,
      'remoteId': source.remoteId,
      'isEnabled': source.isEnabled,
      'squadId': source.squadId,
    };
  }
}

/// What may be saved, in one place so the app, the mock and the security rules
/// agree.
abstract final class SourceRules {
  static const maxLabel = 60;
  static const maxRemoteId = 120;

  static int _length(String raw) => raw.trim().runes.length;

  static String? labelProblem(String raw) {
    final length = _length(raw);
    if (length == 0) return 'Give it a name you will recognise later.';
    if (length > maxLabel) {
      return 'Keep the name to $maxLabel characters or fewer.';
    }
    return null;
  }

  /// Checked per type, because getting this wrong fails silently: the wrong
  /// shape returns a 404 from the remote system, which reads to the team as
  /// "no activity" rather than as "wrong address".
  static String? remoteIdProblem(SourceType type, String raw) {
    final text = raw.trim();
    if (text.isEmpty) return 'Enter what this source is called remotely.';

    if (text.runes.length > maxRemoteId) {
      return 'Keep it to $maxRemoteId characters or fewer.';
    }

    return switch (type) {
      SourceType.github || SourceType.gitlab =>
        RegExp(r'^[\w.-]+/[\w.-]+$').hasMatch(text)
            ? null
            : 'Use owner/repository, for example rrousselGit/riverpod.',
      SourceType.clickUp =>
        RegExp(r'^\d+$').hasMatch(text) ? null : 'A ClickUp list id is digits.',
      SourceType.jira =>
        RegExp(r'^[A-Z][A-Z0-9]+$').hasMatch(text)
            ? null
            : 'A Jira project key is capitals, for example PRAHM.',
    };
  }

  /// The first thing wrong with [source], or null when it can be saved.
  static String? problemWith(IngestionSource source) {
    return labelProblem(source.label) ??
        remoteIdProblem(source.type, source.remoteId) ??
        // Without a squad nothing can be aggregated, so the source would be
        // read on every run and thrown away. Better to refuse it here.
        (source.squadId.isEmpty
            ? 'Choose the squad that works on this.'
            : null);
  }
}
