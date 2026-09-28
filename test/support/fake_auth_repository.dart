import 'dart:async';

import 'package:keel/data/auth_repository.dart';
import 'package:keel/models/app_user.dart';

/// An auth repository that is already signed in.
///
/// Lets widget tests exercise the app without Firebase, a network or a real
/// account. Tests that need the signed-out path construct it with
/// `signedIn: false`.
class FakeAuthRepository implements AuthRepository {
  FakeAuthRepository({bool signedIn = true})
    : _user = signedIn ? demoUser : null;

  static const demoUser = AppUser(
    id: 'test-uid',
    email: 'tester@example.com',
    displayName: 'Tester',
    orgId: 'demo-org',
    role: UserRole.lead,
  );

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

  @override
  Future<AppUser> signIn({
    required String email,
    required String password,
  }) async {
    _user = demoUser;
    _controller.add(_user);
    return demoUser;
  }

  @override
  Future<AppUser> register({
    required String email,
    required String password,
    required String displayName,
    required String orgId,
  }) async {
    _user = demoUser;
    _controller.add(_user);
    return demoUser;
  }

  @override
  Future<void> signOut() async {
    _user = null;
    _controller.add(null);
  }

  void dispose() => _controller.close();
}
