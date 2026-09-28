import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../core/errors/exceptions.dart';
import '../../models/activity_event.dart';
import '../../models/ingestion_source.dart';
import 'ingestion_adapter.dart';

/// Reads commit metadata from GitHub.
///
/// Requests the commits endpoint only. Commit messages are returned by the API
/// but deliberately not read, and diffs are never requested — a commit's
/// author, timestamp and existence is the entire extent of what the scoring
/// engine needs from version control.
class GitMetadataAdapter implements IngestionAdapter {
  GitMetadataAdapter({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;

  static const _apiRoot = 'https://api.github.com';

  /// GitHub caps a page at 100. Ingestion runs often enough that a window
  /// rarely exceeds one page, and paging further would mostly cost rate limit.
  static const _perPage = 100;

  @override
  SourceType get type => SourceType.github;

  @override
  Future<List<RawActivityEvent>> fetchEvents({
    required IngestionSource source,
    required DateTime since,
    required String token,
  }) async {
    final uri = Uri.parse(
      '$_apiRoot/repos/${source.remoteId}/commits'
      '?since=${since.toUtc().toIso8601String()}&per_page=$_perPage',
    );

    final http.Response response;
    try {
      response = await _client.get(
        uri,
        headers: {
          'Accept': 'application/vnd.github+json',
          'Authorization': 'Bearer $token',
        },
      );
    } catch (error) {
      throw NetworkException('Could not reach GitHub: $error');
    }

    switch (response.statusCode) {
      case 200:
        break;
      case 401:
      case 403:
        throw const PermissionException(
          'GitHub refused the request. Check the access token for this source.',
        );
      case 404:
        throw PermissionException(
          'Repository ${source.remoteId} not found, or the token cannot see it.',
        );
      default:
        throw NetworkException(
          'GitHub returned ${response.statusCode} for ${source.remoteId}.',
        );
    }

    final decoded = jsonDecode(response.body);
    if (decoded is! List) {
      throw const ParseException('GitHub returned an unexpected shape.');
    }

    final events = <RawActivityEvent>[];

    for (final item in decoded) {
      if (item is! Map<String, dynamic>) continue;

      final commit = item['commit'] as Map<String, dynamic>?;
      final author = commit?['author'] as Map<String, dynamic>?;

      final email = author?['email'] as String?;
      final dateText = author?['date'] as String?;
      if (email == null || dateText == null) continue;

      final occurredAt = DateTime.tryParse(dateText);
      if (occurredAt == null) continue;

      events.add(
        RawActivityEvent(
          sourceId: source.id,
          authorKey: email.toLowerCase(),
          occurredAt: occurredAt,
          type: ActivityType.commit,
        ),
      );
    }

    return events;
  }

  void dispose() => _client.close();
}
