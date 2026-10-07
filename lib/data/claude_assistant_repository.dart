import 'dart:convert';

import 'package:http/http.dart' as http;

import '../core/errors/exceptions.dart';
import '../models/chat_message.dart';
import 'api_key_store.dart';
import 'assistant_repository.dart';

/// Asks Claude, directly from the device, using the user's own API key.
///
/// Dart has no official Anthropic SDK, so this calls the Messages API over
/// HTTP. Calling it from the device is only acceptable because the key belongs
/// to the person using the app — a shared key shipped inside the APK could be
/// extracted by anyone who downloaded it.
///
/// When the team moves to a backend, this class is replaced by one that posts
/// to a Cloud Function instead. Nothing above the interface changes.
class ClaudeAssistantRepository implements AssistantRepository {
  ClaudeAssistantRepository({
    http.Client? client,
    this.keyStore = const ApiKeyStore(),
  }) : _client = client ?? http.Client();

  final http.Client _client;
  final ApiKeyStore keyStore;

  static const _endpoint = 'https://api.anthropic.com/v1/messages';
  static const _apiVersion = '2023-06-01';

  /// Change this one line to use a cheaper or more capable model.
  static const model = 'claude-opus-5-5';

  /// Answers are short and the context is small, so the lowest effort setting
  /// is the right trade here — it keeps replies quick and cheap without
  /// costing accuracy on questions this direct.
  static const effort = 'low';

  static const _maxTokens = 1024;

  /// Only the last few turns are replayed. The brief is re-sent every time and
  /// is the bulk of the cost, so a long history would multiply the bill for
  /// very little gain.
  static const historyTurns = 6;

  @override
  Future<bool> isConfigured() => keyStore.hasKey();

  @override
  Future<String> ask({
    required String question,
    required String context,
    required List<ChatMessage> history,
  }) async {
    final apiKey = await keyStore.read();
    if (apiKey == null) {
      throw const AuthException(
        'No API key saved. Add one in Settings to use the assistant.',
      );
    }

    final recent = history.length > historyTurns
        ? history.sublist(history.length - historyTurns)
        : history;

    final body = {
      'model': model,
      'max_tokens': _maxTokens,
      'output_config': {'effort': effort},
      'system': _systemPrompt(context),
      'messages': [
        for (final message in recent)
          if (!message.isError)
            {
              'role': message.isUser ? 'user' : 'assistant',
              'content': message.text,
            },
        {'role': 'user', 'content': question},
      ],
    };

    final http.Response response;
    try {
      response = await _client.post(
        Uri.parse(_endpoint),
        headers: {
          'content-type': 'application/json',
          'x-api-key': apiKey,
          'anthropic-version': _apiVersion,
        },
        body: jsonEncode(body),
      );
    } catch (error) {
      throw NetworkException('Could not reach the assistant: $error');
    }

    switch (response.statusCode) {
      case 200:
        break;
      case 401:
        throw const AuthException(
          'That API key was rejected. Check it in Settings.',
        );
      case 400:
        throw ParseException(_apiMessage(response.body) ?? 'Bad request.');
      case 429:
        throw const NetworkException(
          'Rate limited. Wait a moment and ask again.',
        );
      case 529:
        throw const NetworkException(
          'The assistant is busy right now. Try again shortly.',
        );
      default:
        throw NetworkException(
          _apiMessage(response.body) ??
              'The assistant returned ${response.statusCode}.',
        );
    }

    return _extractText(response.body);
  }

  /// Pulls the text out of the content blocks, ignoring thinking blocks.
  String _extractText(String responseBody) {
    final decoded = jsonDecode(responseBody);
    if (decoded is! Map<String, dynamic>) {
      throw const ParseException('The assistant returned an unexpected shape.');
    }

    // A safety refusal comes back as a 200 with this stop reason, so it has to
    // be checked before reading content.
    if (decoded['stop_reason'] == 'refusal') {
      throw const ParseException(
        'The assistant declined to answer that. Try rephrasing it.',
      );
    }

    final content = decoded['content'];
    if (content is! List) {
      throw const ParseException('The assistant returned no content.');
    }

    final text = content
        .whereType<Map<String, dynamic>>()
        .where((block) => block['type'] == 'text')
        .map((block) => block['text'] as String? ?? '')
        .join()
        .trim();

    if (text.isEmpty) {
      throw const ParseException('The assistant returned an empty answer.');
    }
    return text;
  }

  String? _apiMessage(String responseBody) {
    try {
      final decoded = jsonDecode(responseBody);
      if (decoded is Map<String, dynamic>) {
        final error = decoded['error'];
        if (error is Map<String, dynamic>) return error['message'] as String?;
      }
    } catch (_) {
      // Not JSON. Fall through to the caller's default message.
    }
    return null;
  }

  /// What the assistant is told about its job.
  ///
  /// The constraints here are the app's, not decoration: it must not invent
  /// numbers, must not reason about individuals, and must treat outage hours
  /// the way the scoring engine does. A confident wrong answer about a health
  /// score is worse than no assistant at all.
  String _systemPrompt(String context) {
    return '''
You are the assistant inside Keel, a project health monitoring app used by
small South African software teams.

Answer questions about the data below. Be direct and brief — two or three
sentences for most questions. These are busy people checking their phone.

Rules you must follow:

- Only use the data below. If it does not contain the answer, say so plainly
  rather than estimating. Never invent a number, a project, or a date.
- Never speculate about individual people. This app measures squads, never
  developers, and no per-person data exists. If asked who is responsible for
  something, or who is underperforming, explain that the tool deliberately
  does not track individuals and answer at squad level instead.
- Hours lost to load-shedding are reported but never deducted from a health
  score. If a team looks slow and lost hours to outages, say both — do not
  present an outage as underdelivery.
- When you cite a score, give the reasoning behind it from the breakdown
  rather than the number alone.
- Use plain words. Say "at risk", not "sub-optimal trajectory".
- Prices, currency and dates are South African.

$context
''';
  }

  void dispose() => _client.close();
}
