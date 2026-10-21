import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart' as fb;
import 'package:flutter/foundation.dart' show debugPrint;

import '../core/constants/app_constants.dart';
import '../core/errors/exceptions.dart';
import '../models/app_user.dart';
import 'auth_repository.dart';
import 'dto/directory_dto.dart';

/// Firebase Auth implementation of [AuthRepository].
///
/// Firebase Auth knows the credentials; it does not know which organisation a
/// user belongs to or what role they have. Those live in a document in the
/// users collection, so every sign-in reads that document too.
class FirebaseAuthRepository implements AuthRepository {
  FirebaseAuthRepository({fb.FirebaseAuth? auth, FirebaseFirestore? firestore})
    : _auth = auth ?? fb.FirebaseAuth.instance,
      _firestore = firestore ?? FirebaseFirestore.instance;

  final fb.FirebaseAuth _auth;
  final FirebaseFirestore _firestore;

  AppUser? _currentUser;

  @override
  AppUser? get currentUser => _currentUser;

  @override
  Stream<AppUser?> watchCurrentUser() {
    return _auth.authStateChanges().asyncMap((credential) async {
      if (credential == null) {
        _currentUser = null;
        return null;
      }
      _currentUser = await _loadProfile(credential.uid);
      return _currentUser;
    });
  }

  @override
  Future<AppUser> signIn({
    required String email,
    required String password,
  }) async {
    try {
      final result = await _auth.signInWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );
      final uid = result.user!.uid;
      final user = await _loadProfile(uid);
      _currentUser = user;
      return user;
    } on fb.FirebaseAuthException catch (error) {
      throw AuthException(_messageFor(error.code));
    }
  }

  @override
  Future<AppUser> register({
    required String email,
    required String password,
    required String displayName,
    required String orgId,
  }) async {
    try {
      final result = await _auth.createUserWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );
      final uid = result.user!.uid;

      // New accounts always start as developer. Raising a role is an
      // administrative action, not something registration can grant itself.
      final user = AppUser(
        id: uid,
        email: email.trim(),
        displayName: displayName.trim(),
        orgId: orgId,
        role: UserRole.developer,
      );

      await _firestore.collection(AppConstants.usersCollection).doc(uid).set({
        'email': user.email,
        'displayName': user.displayName,
        'orgId': user.orgId,
        'role': user.role.name,
        'createdAt': FieldValue.serverTimestamp(),
      });
      _publishToDirectory(user);

      _currentUser = user;
      return user;
    } on fb.FirebaseAuthException catch (error) {
      throw AuthException(_messageFor(error.code));
    }
  }

  @override
  Future<void> sendPasswordReset({required String email}) async {
    try {
      await _auth.sendPasswordResetEmail(email: email.trim());
    } on fb.FirebaseAuthException catch (error) {
      // `user-not-found` and `invalid-email` are swallowed on purpose: a reset
      // form that distinguishes them tells anybody who asks which addresses
      // have accounts. The screen says the same thing either way, so there is
      // nothing to learn from trying. Everything else is a real failure and
      // has to be reported, or somebody waits for an email that was never
      // sent.
      if (error.code == 'user-not-found' || error.code == 'invalid-email') {
        return;
      }
      throw AuthException(_messageFor(error.code));
    }
  }

  @override
  Future<void> signOut() async {
    await _auth.signOut();
    _currentUser = null;
  }

  Future<AppUser> _loadProfile(String uid) async {
    final doc = await _firestore
        .collection(AppConstants.usersCollection)
        .doc(uid)
        .get();

    final data = doc.data();
    if (data == null) {
      throw const AuthException('Your account is not set up yet.');
    }

    final user = AppUser(
      id: uid,
      email: data['email'] as String? ?? '',
      displayName: data['displayName'] as String? ?? '',
      orgId: data['orgId'] as String? ?? '',
      role: UserRole.fromName(data['role'] as String? ?? 'developer'),
    );
    _publishToDirectory(user);
    return user;
  }

  /// Lists [user] in their organisation's messaging directory, so teammates can
  /// find them to message.
  ///
  /// Done on every sign-in rather than only at registration, which keeps the
  /// entry in step when a role is raised in the console and covers people who
  /// registered before messaging existed. The entry holds a name and a role and
  /// nothing else, and `firestore.rules` refuses one whose role differs from
  /// the role on the person's `users` document.
  ///
  /// Not awaited, and a failure is only logged: offline, the write waits for a
  /// connection, and being unlisted must never stop somebody signing in.
  void _publishToDirectory(AppUser user) {
    if (user.orgId.isEmpty || user.displayName.isEmpty) return;

    unawaited(
      _firestore
          .collection(AppConstants.organisationsCollection)
          .doc(user.orgId)
          .collection(AppConstants.directoryCollection)
          .doc(user.id)
          .set(DirectoryDto.toMap(user))
          .catchError((Object error) {
            debugPrint('Could not update the messaging directory: $error');
          }),
    );
  }

  /// Firebase error codes are not written for people to read.
  String _messageFor(String code) {
    return switch (code) {
      'invalid-email' => 'That email address is not valid.',
      'user-disabled' => 'This account has been disabled.',
      'user-not-found' ||
      'wrong-password' ||
      'invalid-credential' => 'Email or password is incorrect.',
      'email-already-in-use' => 'An account already uses that email.',
      'weak-password' => 'Use a longer password, at least six characters.',
      'network-request-failed' =>
        'No connection. Try again when you are back online.',
      'too-many-requests' =>
        'Too many attempts. Wait a few minutes and try again.',
      _ => 'Could not sign you in. Try again.',
    };
  }
}
