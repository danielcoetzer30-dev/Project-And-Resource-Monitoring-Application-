import 'package:cloud_firestore/cloud_firestore.dart';

import '../core/constants/app_constants.dart';
import '../core/errors/exceptions.dart';
import '../models/scoring_weights.dart';
import 'auth_repository.dart';
import 'settings_repository.dart';

class FirestoreSettingsRepository implements SettingsRepository {
  FirestoreSettingsRepository({
    required this.authRepository,
    FirebaseFirestore? firestore,
  }) : _firestore = firestore ?? FirebaseFirestore.instance;

  final AuthRepository authRepository;
  final FirebaseFirestore _firestore;

  @override
  Stream<ScoringWeights> watchWeights(String orgId) {
    if (orgId.isEmpty) {
      return Stream.value(const ScoringWeights.defaults());
    }

    return _firestore
        .collection(AppConstants.organisationsCollection)
        .doc(orgId)
        .collection(AppConstants.settingsCollection)
        .doc(AppConstants.scoringWeightsDoc)
        .snapshots()
        .map((doc) {
          final data = doc.data();
          return (doc.exists && data != null)
              ? ScoringWeights.fromMap(data)
              : const ScoringWeights.defaults();
        });
  }

  @override
  Future<void> saveWeights({
    required String orgId,
    required ScoringWeights weights,
  }) async {
    final user = authRepository.currentUser;

    // Checked here as well as in firestore.rules: the client says why it was
    // refused, the rules make sure saying so is not the only thing stopping it.
    if (user == null || !user.canChangeSettings) {
      throw const PermissionException(
        'Only leads and managers can change scoring weights.',
      );
    }

    if (!weights.isValid) {
      throw const ValidationException(
        'Scoring weights have to add up to 100% before they can be saved.',
      );
    }

    await _firestore
        .collection(AppConstants.organisationsCollection)
        .doc(orgId)
        .collection(AppConstants.settingsCollection)
        .doc(AppConstants.scoringWeightsDoc)
        .set(weights.toMap());
  }
}
