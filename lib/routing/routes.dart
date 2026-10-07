/// Route names, in one place so a typo is a compile error rather than a
/// blank screen at runtime.
abstract final class Routes {
  static const shell = '/';
  static const signIn = '/sign-in';
  static const projectDetail = '/project';
  static const settings = '/settings';
  static const scoringWeights = '/settings/weights';
  static const ingestionSources = '/settings/sources';
  static const connectSource = '/onboarding/connect';
  static const apiKey = '/settings/api-key';
}
