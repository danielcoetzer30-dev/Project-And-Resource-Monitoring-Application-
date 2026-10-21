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

  /// Whether the last snapshot Firestore delivered came from its own cache
  /// rather than from the server.
  ///
  /// This used to be hardcoded to "live", which made the app unable to report
  /// itself stale at all: Firestore keeps serving cached documents when the
  /// device is offline, so the stream never stops emitting and the badge
  /// never stopped saying Live. For an application whose whole argument is
  /// that it stays usable during load-shedding, silently showing old numbers
  /// as current is the worst thing it could do.
  bool _fromCache = false;

  /// When the server last answered. Null until it has.
  ///
  /// Cached snapshots carry this rather than the current time, so "updated at"
  /// means what it says and [SyncState.isStale] can become true.
  DateTime? _lastServerAt;

  bool _started = false;

  /// Records where a snapshot came from.
  ///
  /// Firestore reports this per query. Any one of the three arriving from
  /// cache means the picture on screen is not wholly live, so this is an
  /// "or" rather than a "last writer wins" — overstating freshness is the
  /// failure that matters.
  void _noteSource(QuerySnapshot<Map<String, dynamic>> query) {
    _fromCache = query.metadata.isFromCache;
    if (!_fromCache) _lastServerAt = DateTime.now();
  }

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
        // Archived projects are dropped here, once, rather than in each
        // screen. A project the team archived should be absent everywhere —
        // the dashboard, the Week bars, the squad counts, the assistant —
        // and filtering at the seam is what makes that true without every
        // widget having to remember.
        _projects = query.docs
            .map(ProjectDto.fromDoc)
            .where((project) => !project.isArchived)
            .toList();
        _noteSource(query);
        _emit();
      }, onError: _controller.addError),
    );

    _subscriptions.add(
      org.collection(AppConstants.squadsCollection).snapshots().listen((query) {
        _squads = query.docs.map(SquadDto.fromDoc).toList();
        _noteSource(query);
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
            _noteSource(query);
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
        // A cached snapshot reports when the server last answered, not now.
        // Otherwise the data always looks current and nothing is ever stale.
        capturedAt: _fromCache
            ? (_lastServerAt ?? DateTime.now())
            : DateTime.now(),
        isLive: !_fromCache,
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
