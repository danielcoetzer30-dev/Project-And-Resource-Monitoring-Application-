import 'dart:convert';

import 'package:googleapis_auth/auth_io.dart';
import 'package:http/http.dart' as http;

import '../../core/errors/exceptions.dart';

/// The document operations ingestion needs, as an interface.
///
/// Same reasoning as `ProjectRepository` on the app side: the runner writes
/// the research database, so it has to be testable against something that is
/// not the research database. [FirestoreRest] is the real one; tests use an
/// in-memory stand-in.
abstract interface class FirestoreStore {
  /// One document, or null when it does not exist.
  Future<Map<String, dynamic>?> get(String path);

  /// Every document in a collection, by id.
  Future<Map<String, Map<String, dynamic>>> list(String collectionPath);

  /// Creates or updates a document. With [mergeFields], only those fields are
  /// touched and the rest of the document is left as it was.
  Future<void> write(
    String path,
    Map<String, dynamic> data, {
    List<String>? mergeFields,
  });

  Future<void> delete(String path);
}

/// A minimal Firestore client for the ingestion job.
///
/// Why REST and a service account rather than the Admin SDK: there is no
/// Firebase Admin SDK for Dart. Using one would mean writing ingestion in
/// another language, which would mean a second copy of the anonymiser, and
/// two anonymisers means one of them drifts out of compliance without anyone
/// noticing. Reusing the tested Dart code is worth hand-rolling this.
///
/// A service account is **not** subject to `firestore.rules`. That is the
/// point: `projects`, `squads` and `signals` stay `write: false` for every
/// client, and ingestion writes them as a privileged identity instead. No rule
/// has to be loosened for this to work, and nothing a device holds can
/// reproduce it.
///
/// The credential must never reach the repository or a phone. It lives in a
/// GitHub Actions secret and is read from the environment.
class FirestoreRest implements FirestoreStore {
  FirestoreRest._(this._client, this._projectId);

  /// Authenticates with a service-account key in JSON form.
  ///
  /// [keyJson] is the whole file contents, as downloaded from the Google Cloud
  /// console and pasted into a secret.
  static Future<FirestoreRest> connect({
    required String keyJson,
    required String projectId,
  }) async {
    final ServiceAccountCredentials credentials;
    try {
      credentials = ServiceAccountCredentials.fromJson(
        jsonDecode(keyJson) as Map<String, dynamic>,
      );
    } catch (_) {
      throw const AuthException(
        'The service-account key is not valid JSON. Check the secret holds '
        'the whole file, braces included.',
      );
    }

    final client = await clientViaServiceAccount(credentials, const [
      // Datastore scope covers Firestore. Nothing here needs another scope,
      // and a narrower credential is a smaller problem if it ever leaks.
      'https://www.googleapis.com/auth/datastore',
    ]);

    return FirestoreRest._(client, projectId);
  }

  final http.Client _client;
  final String _projectId;

  String get _root =>
      'https://firestore.googleapis.com/v1/projects/$_projectId/'
      'databases/(default)/documents';

  /// Reads one document, or null when it does not exist.
  @override
  Future<Map<String, dynamic>?> get(String path) async {
    final response = await _client.get(Uri.parse('$_root/$path'));

    if (response.statusCode == 404) return null;
    _check(response, 'read $path');

    final body = jsonDecode(response.body) as Map<String, dynamic>;
    return decodeFields(body['fields'] as Map<String, dynamic>?);
  }

  /// Lists a collection, returning each document id against its fields.
  ///
  /// Paged through to the end: a run that silently saw only the first page
  /// would score some projects and quietly skip others.
  @override
  Future<Map<String, Map<String, dynamic>>> list(String collectionPath) async {
    final documents = <String, Map<String, dynamic>>{};
    String? pageToken;

    do {
      final uri = Uri.parse(
        '$_root/$collectionPath',
      ).replace(queryParameters: {'pageSize': '300', 'pageToken': ?pageToken});

      final response = await _client.get(uri);
      if (response.statusCode == 404) return documents;
      _check(response, 'list $collectionPath');

      final body = jsonDecode(response.body) as Map<String, dynamic>;
      final page = body['documents'] as List<dynamic>? ?? const [];

      for (final entry in page) {
        final document = entry as Map<String, dynamic>;
        final name = document['name'] as String;
        documents[name.split('/').last] = decodeFields(
          document['fields'] as Map<String, dynamic>?,
        );
      }

      pageToken = body['nextPageToken'] as String?;
    } while (pageToken != null);

    return documents;
  }

  /// Creates or updates a document.
  ///
  /// When [mergeFields] is given, only those fields are written and everything
  /// else on the document is left alone. That is what lets ingestion update a
  /// score without flattening a field a person set, and it is the same
  /// `updateMask` approach `tool/patch_forecast_fields.js` already uses.
  @override
  Future<void> write(
    String path,
    Map<String, dynamic> data, {
    List<String>? mergeFields,
  }) async {
    final uri = Uri.parse(
      '$_root/$path',
    ).replace(queryParameters: {'updateMask.fieldPaths': ?mergeFields});

    final response = await _client.patch(
      uri,
      headers: const {'Content-Type': 'application/json'},
      body: jsonEncode({'fields': encodeFields(data)}),
    );

    _check(response, 'write $path');
  }

  /// Removes a document. Missing is treated as already gone, because a run
  /// that cleared a stale signal and then crashed should be safe to repeat.
  @override
  Future<void> delete(String path) async {
    final response = await _client.delete(Uri.parse('$_root/$path'));
    if (response.statusCode == 404) return;
    _check(response, 'delete $path');
  }

  void close() => _client.close();

  void _check(http.Response response, String what) {
    if (response.statusCode >= 200 && response.statusCode < 300) return;

    final message = 'Firestore refused to $what (${response.statusCode}).';

    throw switch (response.statusCode) {
      401 || 403 => PermissionException(
        '$message Check the service account has the Cloud Datastore User role.',
      ),
      >= 500 => NetworkException('$message Google reported a server error.'),
      _ => ParseException('$message Body: ${response.body}'),
    };
  }

  // --- Value encoding -------------------------------------------------------
  // Firestore's REST API tags every value with its type. This mirrors the
  // encoder in tool/seed_firestore.js, so both tools write documents the app
  // reads identically and docs/SCHEMA.md describes one shape rather than two.
  //
  // One deliberate difference: this dispatches on Dart's static type, so 28.0
  // is a double, while the JavaScript one dispatches on the value and makes
  // the same number an integer. Both are safe because every numeric field is
  // read back through `as num`, which is why the DTOs are written that way.

  static Map<String, dynamic> encodeFields(Map<String, dynamic> data) {
    return {for (final entry in data.entries) entry.key: encode(entry.value)};
  }

  static Map<String, dynamic> encode(Object? value) {
    return switch (value) {
      null => {'nullValue': null},
      DateTime() => {'timestampValue': value.toUtc().toIso8601String()},
      bool() => {'booleanValue': value},
      int() => {'integerValue': value.toString()},
      double() => {'doubleValue': value},
      String() => {'stringValue': value},
      List() => {
        'arrayValue': {'values': value.map(encode).toList()},
      },
      Map() => {
        'mapValue': {'fields': encodeFields(Map<String, dynamic>.from(value))},
      },
      _ => {'stringValue': value.toString()},
    };
  }

  static Map<String, dynamic> decodeFields(Map<String, dynamic>? fields) {
    if (fields == null) return {};
    return {
      for (final entry in fields.entries)
        entry.key: decode(entry.value as Map<String, dynamic>),
    };
  }

  static Object? decode(Map<String, dynamic> value) {
    if (value.containsKey('nullValue')) return null;
    if (value.containsKey('booleanValue')) return value['booleanValue'];
    if (value.containsKey('stringValue')) return value['stringValue'];
    if (value.containsKey('doubleValue')) {
      return (value['doubleValue'] as num).toDouble();
    }
    if (value.containsKey('integerValue')) {
      return int.parse(value['integerValue'] as String);
    }
    if (value.containsKey('timestampValue')) {
      return DateTime.parse(value['timestampValue'] as String);
    }
    if (value.containsKey('arrayValue')) {
      final values =
          (value['arrayValue'] as Map<String, dynamic>)['values']
              as List<dynamic>? ??
          const [];
      return values
          .map((item) => decode(item as Map<String, dynamic>))
          .toList();
    }
    if (value.containsKey('mapValue')) {
      return decodeFields(
        (value['mapValue'] as Map<String, dynamic>)['fields']
            as Map<String, dynamic>?,
      );
    }
    return null;
  }
}
