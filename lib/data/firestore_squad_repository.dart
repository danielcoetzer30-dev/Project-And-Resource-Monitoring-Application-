import 'package:cloud_firestore/cloud_firestore.dart';

import '../core/constants/app_constants.dart';
import '../core/errors/exceptions.dart';
import '../models/app_user.dart';
import '../models/squad_rules.dart';
import 'squad_repository.dart';

/// Squads in the signed-in user's organisation.
///
/// Checks the role and the input before writing so the app can say why
/// something was refused, and relies on `firestore.rules` to make those
/// checks more than a courtesy.
class FirestoreSquadRepository implements SquadRepository {
  FirestoreSquadRepository({
    required this.orgId,
    this.author,
    FirebaseFirestore? firestore,
  }) : _firestore = firestore ?? FirebaseFirestore.instance;

  final String orgId;

  /// Who writes are made as. Null when signed out, which cannot write.
  final AppUser? author;

  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, dynamic>> get _squads => _firestore
      .collection(AppConstants.organisationsCollection)
      .doc(orgId)
      .collection(AppConstants.squadsCollection);

  void _checkCanEdit() {
    final user = author;
    if (user == null || orgId.isEmpty) {
      throw const AuthException('Sign in to change squads.');
    }
    if (!user.canChangeSettings) {
      throw const PermissionException(
        'Only leads and managers can create or change squads.',
      );
    }
  }

  void _checkValid(String name, int headcount) {
    final problem =
        SquadRules.nameProblem(name) ??
        SquadRules.headcountProblem('$headcount');
    if (problem != null) throw ValidationException(problem);
  }

  @override
  ({String id, Future<void> saved}) create({
    required String name,
    required int headcount,
  }) {
    _checkCanEdit();
    _checkValid(name, headcount);

    // The id is made on the device, so it exists before the server answers.
    final ref = _squads.doc();
    final saved = ref
        .set({
          'name': name.trim(),
          'headcount': headcount,
          // Measured figures start at zero and belong to ingestion from here.
          // The rules refuse a create that starts anywhere else.
          'capacityUsed': 0,
          'activeProjectCount': 0,
          'velocityTrend': 0,
          'createdAt': FieldValue.serverTimestamp(),
        })
        .catchError((Object error) {
          if (error is FirebaseException) throw _translate(error);
          throw error;
        });

    return (id: ref.id, saved: saved);
  }

  @override
  Future<void> update({
    required String squadId,
    required String name,
    required int headcount,
  }) async {
    _checkCanEdit();
    _checkValid(name, headcount);

    try {
      await _squads.doc(squadId).update({
        'name': name.trim(),
        'headcount': headcount,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } on FirebaseException catch (error) {
      throw _translate(error);
    }
  }

  @override
  Future<void> delete(String squadId) async {
    _checkCanEdit();

    try {
      await _squads.doc(squadId).delete();
    } on FirebaseException catch (error) {
      throw _translate(error);
    }
  }

  Object _translate(FirebaseException error) {
    return switch (error.code) {
      'permission-denied' => const PermissionException(
        'The backend refused this change. Check that the latest security '
        'rules are published.',
      ),
      'not-found' => const ValidationException('That squad no longer exists.'),
      'unavailable' || 'deadline-exceeded' => const NetworkException(
        'The device could not reach the backend.',
      ),
      _ => ValidationException('The change could not be saved (${error.code}).'),
    };
  }
}
