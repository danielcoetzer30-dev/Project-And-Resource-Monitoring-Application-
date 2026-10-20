import 'package:cloud_firestore/cloud_firestore.dart';

import '../core/constants/app_constants.dart';
import '../core/errors/exceptions.dart';
import '../models/app_user.dart';
import '../models/project_plan.dart';
import 'dto/project_plan_dto.dart';
import 'project_plan_repository.dart';

/// Project plans, in the signed-in user's organisation.
///
/// Checks the role before writing so the app can say why a change was
/// refused, and relies on `firestore.rules` to make that check more than a
/// courtesy. A developer reads every plan and changes none — the same shape
/// as scoring weights and connected sources, and for the same reason: what a
/// team is measured on should be inspectable by everyone it measures.
class FirestoreProjectPlanRepository implements ProjectPlanRepository {
  FirestoreProjectPlanRepository({
    required this.orgId,
    this.author,
    FirebaseFirestore? firestore,
  }) : _firestore = firestore ?? FirebaseFirestore.instance;

  final String orgId;

  /// Who writes are made as. Null when signed out, which cannot write.
  final AppUser? author;

  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, dynamic>> get _plans => _firestore
      .collection(AppConstants.organisationsCollection)
      .doc(orgId)
      .collection(AppConstants.projectPlansCollection);

  @override
  Stream<List<ProjectPlan>> watch() {
    // Signed out means no organisation to scope to. An unscoped query would
    // be refused anyway; empty says so without an error screen.
    if (orgId.isEmpty) return Stream.value(const []);

    return _plans.snapshots().map((snapshot) {
      final plans = [
        for (final doc in snapshot.docs) ProjectPlanDto.fromDoc(doc),
      ];

      // Active first, then alphabetical. Archived projects are still here to
      // be found, just not in the way.
      plans.sort((a, b) {
        if (a.isArchived != b.isArchived) return a.isArchived ? 1 : -1;
        return a.name.toLowerCase().compareTo(b.name.toLowerCase());
      });

      return plans;
    });
  }

  @override
  Stream<ProjectPlan?> watchOne(String projectId) {
    if (orgId.isEmpty || projectId.isEmpty) return Stream.value(null);

    return _plans
        .doc(projectId)
        .snapshots()
        .map((doc) => doc.exists ? ProjectPlanDto.fromDoc(doc) : null);
  }

  @override
  Future<String> save(ProjectPlan plan) async {
    _refuseUnlessPermitted();

    final problem = ProjectPlanRules.problemWith(plan);
    if (problem != null) throw ValidationException(problem);

    // The repository allocates the id rather than the caller. A timestamp
    // would collide when two people add a project in the same moment, and
    // the loser's would silently replace the winner's.
    final id = plan.projectId.isEmpty ? _plans.doc().id : plan.projectId;

    await _plans.doc(id).set(ProjectPlanDto.toMap(plan));
    return id;
  }

  @override
  Future<void> setArchived({
    required String projectId,
    required bool archived,
  }) async {
    _refuseUnlessPermitted();
    await _plans.doc(projectId).update({'isArchived': archived});
  }

  void _refuseUnlessPermitted() {
    if (author == null) {
      throw const AuthException('Sign in to change a project.');
    }
    if (!author!.canChangeSettings) {
      throw const PermissionException(
        'Only leads and managers can add or change a project.',
      );
    }
  }
}
