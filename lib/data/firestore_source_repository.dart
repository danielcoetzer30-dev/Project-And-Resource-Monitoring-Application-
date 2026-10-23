import 'package:cloud_firestore/cloud_firestore.dart';

import '../core/constants/app_constants.dart';
import '../core/errors/exceptions.dart';
import '../models/app_user.dart';
import '../models/ingestion_source.dart';
import 'dto/source_dto.dart';
import 'source_repository.dart';

/// Sources, in the signed-in user's organisation.
///
/// Checks the role before writing so the app can say *why* a change was
/// refused, and relies on `firestore.rules` to make that check more than a
/// courtesy. A developer reads every source and changes none, the same shape
/// as scoring weights, and for the same reason: what a team is measured on
/// should be inspectable by everyone it measures.
class FirestoreSourceRepository implements SourceRepository {
  FirestoreSourceRepository({
    required this.orgId,
    this.author,
    FirebaseFirestore? firestore,
  }) : _firestore = firestore ?? FirebaseFirestore.instance;

  final String orgId;

  /// Who writes are made as. Null when signed out, which cannot write.
  final AppUser? author;

  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, dynamic>> get _sources => _firestore
      .collection(AppConstants.organisationsCollection)
      .doc(orgId)
      .collection(AppConstants.sourcesCollection);

  @override
  Stream<List<IngestionSource>> watch() {
    // Signed out means no organisation to scope to. An unscoped query would
    // be refused anyway; returning empty says so without an error screen.
    if (orgId.isEmpty) return Stream.value(const []);

    return _sources.snapshots().map((snapshot) {
      final sources = [
        for (final doc in snapshot.docs) SourceDto.fromDoc(doc, orgId),
      ];

      // Never-synced first: a source that has not run is the one needing
      // attention, and the one most likely to have been typed in wrongly.
      sources.sort((a, b) {
        if (a.lastSyncedAt == null) return b.lastSyncedAt == null ? 0 : -1;
        if (b.lastSyncedAt == null) return 1;
        return b.lastSyncedAt!.compareTo(a.lastSyncedAt!);
      });

      return sources;
    });
  }

  @override
  Future<void> connect(IngestionSource source) async {
    _refuseUnlessPermitted();

    final problem = SourceRules.problemWith(source);
    if (problem != null) throw ValidationException(problem);

    final id = source.id.isEmpty ? _sources.doc().id : source.id;
    await _sources.doc(id).set(SourceDto.toMap(source));
  }

  @override
  Future<void> setEnabled({
    required String sourceId,
    required bool enabled,
  }) async {
    _refuseUnlessPermitted();
    await _sources.doc(sourceId).update({'isEnabled': enabled});
  }

  @override
  Future<void> disconnect(String sourceId) async {
    _refuseUnlessPermitted();
    await _sources.doc(sourceId).delete();
  }

  void _refuseUnlessPermitted() {
    if (author == null) {
      throw const AuthException('Sign in to change connected sources.');
    }
    if (!author!.canChangeSettings) {
      throw const PermissionException(
        'Only leads and managers can change connected sources.',
      );
    }
  }
}
