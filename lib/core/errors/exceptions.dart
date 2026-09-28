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

///The device could not reach backend.
class NetworkException extends AppException {
  const NetworkException(super.message);
}

///Sign in failed or session expired.
class AuthException extends AppException {
  const AuthException(super.message);
}

///The backend refused the operation. Usually this is because the user does not have permission to do it.
class PermissionException extends AppException {
  const PermissionException(super.message);
}

///A document came back in a shape the app did not expect.
class ParseException extends AppException {
  const ParseException(super.message);
}
