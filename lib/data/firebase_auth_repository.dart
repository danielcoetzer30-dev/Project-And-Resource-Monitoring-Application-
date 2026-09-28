import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart' as fb;

import '../core/constants/app_constants.dart';
import '../core/errors/exceptions.dart';
import '../models/app_user.dart';
import 'auth_repository.dart';

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

      _currentUser = user;
      return user;
    } on fb.FirebaseAuthException catch (error) {
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

    return AppUser(
      id: uid,
      email: data['email'] as String? ?? '',
      displayName: data['displayName'] as String? ?? '',
      orgId: data['orgId'] as String? ?? '',
      role: UserRole.fromName(data['role'] as String? ?? 'developer'),
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
      _ => 'Could not sign you in. Try again.',
    };
  }
}
