import 'package:shared_preferences/shared_preferences.dart';

/// Holds the API key the user supplies for the assistant.
///
/// The key is the user's own, entered by them, and stays on their device. It
/// is never sent to Firestore, never shared with the team, and never included
/// in an APK — which is the whole reason the assistant asks for one instead of
/// shipping a key everyone could extract from the app.
///
/// `shared_preferences` is not encrypted storage. For a prototype where each
/// person supplies their own key and can revoke it from their own Anthropic
/// console, that is an acceptable trade; a production build should move this
/// to the platform keystore via `flutter_secure_storage`.
class ApiKeyStore {
  const ApiKeyStore();

  static const _key = 'assistant_api_key';

  Future<String?> read() async {
    final prefs = await SharedPreferences.getInstance();
    final value = prefs.getString(_key);
    return (value == null || value.isEmpty) ? null : value;
  }

  Future<void> write(String key) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, key.trim());
  }

  Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_key);
  }

  Future<bool> hasKey() async => (await read()) != null;

  /// Enough of the key to recognise it, never the whole thing.
  ///
  /// Settings shows this so someone can tell which key is stored without the
  /// screen displaying a credential in full.
  static String mask(String key) {
    if (key.length <= 12) return '••••';
    return '${key.substring(0, 7)}…${key.substring(key.length - 4)}';
  }
}
