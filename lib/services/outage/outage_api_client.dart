import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../core/errors/exceptions.dart';
import '../../models/outage_window.dart';

/// Fetches load-shedding schedules from EskomSePush.
///
/// A public schedule is only ever a forecast — stages change at short notice
/// and the published times shift. So this returns what the feed says and the
/// service layer treats it as an estimate, never as a record of what happened.
class OutageApiClient {
  OutageApiClient({http.Client? client, this.apiKey})
    : _client = client ?? http.Client();

  final http.Client _client;

  /// Null in the prototype. Without it the client reports unavailable and the
  /// app falls back to windows a team enters by hand, which is the behaviour a
  /// team without a subscription would get anyway.
  final String? apiKey;

  static const _apiRoot = 'https://developer.sepush.co.za/business/2.0';

  bool get isConfigured => apiKey != null && apiKey!.isNotEmpty;

  /// The national stage right now, or 0 when the grid is up.
  Future<int> fetchStage() async {
    if (!isConfigured) {
      throw const NetworkException('No load-shedding API key configured.');
    }

    final response = await _get('$_apiRoot/status');
    final status = response['status'];
    if (status is! Map<String, dynamic>) {
      throw const ParseException('Status feed returned an unexpected shape.');
    }

    // The feed nests the national operator under a key that has changed name
    // before, so take whichever entry is present rather than hard-coding it.
    for (final entry in status.values) {
      if (entry is! Map<String, dynamic>) continue;
      final current = entry['stage'];
      if (current is num) return current.toInt();
      final stageText = (entry['stage'] ?? '').toString();
      final parsed = int.tryParse(stageText);
      if (parsed != null) return parsed;
    }

    return 0;
  }

  /// Upcoming windows for one area.
  Future<List<OutageWindow>> fetchWindows({
    required String areaId,
    required List<String> affectedSquadIds,
  }) async {
    if (!isConfigured) {
      throw const NetworkException('No load-shedding API key configured.');
    }

    final response = await _get('$_apiRoot/area?id=$areaId');
    final events = response['events'];
    if (events is! List) return const [];

    final windows = <OutageWindow>[];

    for (var i = 0; i < events.length; i++) {
      final event = events[i];
      if (event is! Map<String, dynamic>) continue;

      final start = DateTime.tryParse('${event['start'] ?? ''}');
      final end = DateTime.tryParse('${event['end'] ?? ''}');
      if (start == null || end == null) continue;

      final note = '${event['note'] ?? ''}';
      final stage =
          int.tryParse(RegExp(r'\d+').firstMatch(note)?.group(0) ?? '') ?? 0;

      windows.add(
        OutageWindow(
          id: '$areaId-${start.millisecondsSinceEpoch}',
          stage: stage,
          start: start,
          end: end,
          affectedSquadIds: affectedSquadIds,
        ),
      );
    }

    return windows;
  }

  Future<Map<String, dynamic>> _get(String url) async {
    final http.Response response;
    try {
      response = await _client.get(Uri.parse(url), headers: {'Token': apiKey!});
    } catch (error) {
      throw NetworkException('Could not reach the load-shedding feed: $error');
    }

    if (response.statusCode == 403) {
      throw const PermissionException('Load-shedding API key was rejected.');
    }
    if (response.statusCode != 200) {
      throw NetworkException(
        'Load-shedding feed returned ${response.statusCode}.',
      );
    }

    final decoded = jsonDecode(response.body);
    if (decoded is! Map<String, dynamic>) {
      throw const ParseException(
        'Load-shedding feed returned unexpected JSON.',
      );
    }
    return decoded;
  }

  void dispose() => _client.close();
}
