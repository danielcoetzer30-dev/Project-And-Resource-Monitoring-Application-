import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';

import '../core/constants/app_constants.dart';
import '../models/project.dart';
import '../models/signal.dart';
import '../models/squad.dart';
import 'dto/project_dto.dart';
import 'dto/signal_dto.dart';
import 'dto/squad_dto.dart';
import 'project_repository.dart';

/// The real implementation of [ProjectRepository].
///
/// The UI wants one snapshot containing everything. Firestore gives three
/// separate streams, so this class holds the latest of each and emits a
/// combined snapshot whenever any of them changes.
class FirestoreProjectRepository implements ProjectRepository {
  FirestoreProjectRepository({
    required this.orgId,
    FirebaseFirestore? firestore,
  }) : _firestore = firestore ?? FirebaseFirestore.instance;

  final String orgId;
  final FirebaseFirestore _firestore;

  final _controller = StreamController<HealthSnapshot>.broadcast();
  final _subscriptions = <StreamSubscription<dynamic>>[];

  List<Project> _projects = const [];
  List<Squad> _squads = const [];
  List<Signal> _signals = const [];

  bool _started = false;

  @override
  Stream<HealthSnapshot> watch() {
    if (!_started) {
      _started = true;
      _listenToCollections();
    }
    return _controller.stream;
  }

  void _listenToCollections() {
    // No organisation means nobody is signed in yet. Emit an empty snapshot
    // rather than building a path with a blank segment, which Firestore
    // rejects outright.
    if (orgId.isEmpty) {
      _emit();
      return;
    }

    final org = _firestore
        .collection(AppConstants.organisationsCollection)
        .doc(orgId);

    _subscriptions.add(
      org.collection(AppConstants.projectsCollection).snapshots().listen((
        query,
      ) {
        _projects = query.docs.map(ProjectDto.fromDoc).toList();
        _emit();
      }, onError: _controller.addError),
    );

    _subscriptions.add(
      org.collection(AppConstants.squadsCollection).snapshots().listen((query) {
        _squads = query.docs.map(SquadDto.fromDoc).toList();
        _emit();
      }, onError: _controller.addError),
    );

    _subscriptions.add(
      org
          .collection(AppConstants.signalsCollection)
          .orderBy('raisedAt', descending: true)
          .snapshots()
          .listen((query) {
            _signals = query.docs.map(SignalDto.fromDoc).toList();
            _emit();
          }, onError: _controller.addError),
    );
  }

  void _emit() {
    if (_controller.isClosed) return;

    _controller.add(
      HealthSnapshot(
        projects: _projects,
        squads: _squads,
        signals: _signals,
        // Grid status comes from OutageRepository, which the Infrastructure
        // workstream owns. Until that exists, report a stable grid rather than
        // inventing a stage.
        grid: const GridStatus(
          stage: 0,
          nextOutageStart: null,
          nextOutageEnd: null,
          hoursLostThisWeek: 0,
        ),
        capturedAt: DateTime.now(),
        isLive: true,
      ),
    );
  }

  @override
  void dispose() {
    for (final subscription in _subscriptions) {
      subscription.cancel();
    }
    _subscriptions.clear();
    _controller.close();
  }
}
