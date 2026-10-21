/// Route names, in one place so a typo is a compile error rather than a
/// blank screen at runtime.
abstract final class Routes {
  static const shell = '/';
  static const signIn = '/sign-in';
  static const projectDetail = '/project';
  static const signalThread = '/signal';
  static const settings = '/settings';
  static const messages = '/messages';
  static const newMessage = '/messages/new';
  static const newGroup = '/messages/new-group';
  static const conversation = '/messages/conversation';
  static const groupMembers = '/messages/members';
  static const scoringWeights = '/settings/weights';
  static const ingestionSources = '/settings/sources';
  static const projects = '/projects';
  static const editProject = '/projects/edit';
  static const connectSource = '/onboarding/connect';
  static const apiKey = '/settings/api-key';
  static const customisations = '/settings/customisations';
  static const accessibility = '/settings/accessibility';
  static const about = '/settings/about';
}
