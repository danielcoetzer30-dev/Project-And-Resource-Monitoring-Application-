import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../core/errors/exceptions.dart';
import '../../models/activity_event.dart';
import '../../models/ingestion_source.dart';
import 'ingestion_adapter.dart';

/// Reads task state from ClickUp.
///
/// Task titles and descriptions are ignored. What the engine needs is when
/// items were opened and closed and roughly how big they were, which is enough
/// to compute velocity and complexity ratio without reading anything a client
/// would consider confidential.
class IssueTrackerAdapter implements IngestionAdapter {
  IssueTrackerAdapter({http.Client? client})
    : _client = client ?? http.Client();

  final http.Client _client;

  static const _apiRoot = 'https://api.clickup.com/api/v2';

  @override
  SourceType get type => SourceType.clickUp;

  @override
  Future<List<RawActivityEvent>> fetchEvents({
    required IngestionSource source,
    required DateTime since,
    required String token,
  }) async {
    final sinceMillis = since.toUtc().millisecondsSinceEpoch;

    final uri = Uri.parse(
      '$_apiRoot/list/${source.remoteId}/task'
      '?subtasks=true&include_closed=true&date_updated_gt=$sinceMillis',
    );

    final http.Response response;
    try {
      response = await _client.get(uri, headers: {'Authorization': token});
    } catch (error) {
      throw NetworkException('Could not reach ClickUp: $error');
    }

    if (response.statusCode == 401 || response.statusCode == 403) {
      throw const PermissionException(
        'ClickUp refused the request. Check the API token for this source.',
      );
    }
    if (response.statusCode != 200) {
      throw NetworkException(
        'ClickUp returned ${response.statusCode} for list ${source.remoteId}.',
      );
    }

    final decoded = jsonDecode(response.body);
    if (decoded is! Map<String, dynamic>) {
      throw const ParseException('ClickUp returned an unexpected shape.');
    }

    final tasks = decoded['tasks'];
    if (tasks is! List) return const [];

    final events = <RawActivityEvent>[];

    for (final item in tasks) {
      if (item is! Map<String, dynamic>) continue;

      // ClickUp reports assignees as a list. Only the first is used, and only
      // to route the event to a squad — it is dropped by the anonymiser
      // immediately afterwards.
      final assignees = item['assignees'] as List<dynamic>?;
      if (assignees == null || assignees.isEmpty) continue;

      final first = assignees.first;
      if (first is! Map<String, dynamic>) continue;
      final email = first['email'] as String?;
      if (email == null) continue;

      final status = item['status'] as Map<String, dynamic>?;
      final statusType = status?['type'] as String?;
      final isClosed = statusType == 'closed' || statusType == 'done';

      final stampField = isClosed ? 'date_closed' : 'date_created';
      final stamp = int.tryParse('${item[stampField] ?? ''}');
      if (stamp == null) continue;

      events.add(
        RawActivityEvent(
          sourceId: source.id,
          authorKey: email.toLowerCase(),
          occurredAt: DateTime.fromMillisecondsSinceEpoch(stamp),
          type: isClosed ? ActivityType.taskCompleted : ActivityType.taskOpened,
          weight: _weightOf(item),
        ),
      );
    }

    return events;
  }

  /// Story points where the team uses them, otherwise every task counts as one.
  ///
  /// Falling back to 1 rather than guessing keeps the complexity ratio honest:
  /// a team that does not estimate simply gets a ratio based on item counts.
  double _weightOf(Map<String, dynamic> task) {
    final points = task['points'];
    if (points is num && points > 0) return points.toDouble();
    return 1;
  }

  void dispose() => _client.close();
}
