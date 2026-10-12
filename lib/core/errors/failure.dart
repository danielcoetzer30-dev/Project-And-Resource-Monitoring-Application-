import 'exceptions.dart';

/// A problem, in a form the UI can act on.
///
/// Sealed so a screen handling failures gets a compile error if a new kind is
/// added and it does not handle it. Each one carries a message written for the
/// person reading it, not for a developer reading a log.
sealed class Failure {
  const Failure(this.message);

  final String message;
}

class NetworkFailure extends Failure {
  const NetworkFailure([super.message = 'No connection. Showing saved data.']);
}

class AuthFailure extends Failure {
  const AuthFailure([super.message = 'Sign in to continue.']);
}

class PermissionFailure extends Failure {
  const PermissionFailure([super.message = 'You do not have access to this.']);
}

class DataFailure extends Failure {
  const DataFailure([super.message = 'Something went wrong loading this.']);
}

/// The app refused the input before sending it. Carries the specific message
/// rather than a default, because "weights have to add up to 100%" is the
/// whole value of the failure.
class ValidationFailure extends Failure {
  const ValidationFailure(super.message);
}

/// Converts an exception from the data layer into a Failure.
///
/// This is the single place the translation happens, so error wording stays
/// consistent wherever a failure surfaces.
Failure failureFromException(Object error) {
  return switch (error) {
    NetworkException() => const NetworkFailure(),
    AuthException() => const AuthFailure(),
    // Both carry a message already written for the person reading it, so it
    // is passed through rather than replaced with a generic one.
    PermissionException(:final message) => PermissionFailure(message),
    ValidationException(:final message) => ValidationFailure(message),
    ParseException() => const DataFailure(),
    _ => const DataFailure(),
  };
}
