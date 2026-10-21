import 'dart:async';

import 'package:keel/data/auth_repository.dart';
import 'package:keel/models/app_user.dart';

/// An auth repository that is already signed in.
///
/// Lets widget tests exercise the app without Firebase, a network or a real
/// account. Tests that need the signed-out path construct it with
/// `signedIn: false`, and tests about roles pass a `user` of their own.
class FakeAuthRepository implements AuthRepository {
  FakeAuthRepository({bool signedIn = true, AppUser? user})
    : _user = signedIn ? (user ?? demoUser) : null,
      _signInAs = user ?? demoUser;

  static const demoUser = AppUser(
    id: 'test-uid',
    email: 'tester@example.com',
    displayName: 'Tester',
    orgId: 'demo-org',
    role: UserRole.lead,
  );

  /// Who [signIn] and [register] produce. Lets a test sign in as a developer
  /// rather than only as the default lead.
  final AppUser _signInAs;

  AppUser? _user;

  final _controller = StreamController<AppUser?>.broadcast();

  @override
  AppUser? get currentUser => _user;

  @override
  Stream<AppUser?> watchCurrentUser() {
    scheduleMicrotask(() {
      if (!_controller.isClosed) _controller.add(_user);
    });
    return _controller.stream;
  }

  /// Set to make [signIn] fail, so the refusal path can be exercised through
  /// the real notifier and gate rather than through a callback a test wrote.
  Object? signInError;

  @override
  Future<AppUser> signIn({
    required String email,
    required String password,
  }) async {
    if (signInError != null) throw signInError!;

    _user = _signInAs;
    _controller.add(_user);
    return _signInAs;
  }

  @override
  Future<AppUser> register({
    required String email,
    required String password,
    required String displayName,
    required String orgId,
  }) async {
    _user = _signInAs;
    _controller.add(_user);
    return _signInAs;
  }

  /// Addresses [sendPasswordReset] was asked about, in order. Lets a test
  /// assert that the screen asked, without a mail server.
  final resetsRequested = <String>[];

  /// Set to make [sendPasswordReset] fail, for the error path.
  Object? resetError;

  @override
  Future<void> sendPasswordReset({required String email}) async {
    resetsRequested.add(email.trim());
    if (resetError != null) throw resetError!;
  }

  @override
  Future<void> signOut() async {
    _user = null;
    _controller.add(null);
  }

  void dispose() => _controller.close();
}
