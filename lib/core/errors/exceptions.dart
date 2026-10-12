/// Thrown by the data layer when something goes wrong talking to a backend.
///
/// These are caught at the repository boundary and converted into a Failure,
/// so nothing above the data layer ever has to catch a raw exception.
class AppException implements Exception {
  const AppException(this.message);

  final String message;

  @override
  String toString() => '$runtimeType: $message';
}

/// The device could not reach backend.
class NetworkException extends AppException {
  const NetworkException(super.message);
}

/// Sign in failed or session expired.
class AuthException extends AppException {
  const AuthException(super.message);
}

/// The backend refused the operation, usually because the signed-in user does
/// not have permission for it.
class PermissionException extends AppException {
  const PermissionException(super.message);
}

/// A value the app itself rejected before sending it, such as scoring
/// weights that do not add up to 100%.
class ValidationException extends AppException {
  const ValidationException(super.message);
}

/// A document came back in a shape the app did not expect.
class ParseException extends AppException {
  const ParseException(super.message);
}
