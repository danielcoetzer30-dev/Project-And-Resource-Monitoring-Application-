import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';

import '../core/constants/app_constants.dart';
import '../core/errors/exceptions.dart';
import '../models/app_user.dart';
import '../models/comment.dart';
import 'comment_repository.dart';
import 'dto/comment_dto.dart';

/// The real implementation of [CommentRepository].
///
/// A thread is the `comments` subcollection of its signal, so it costs nothing
/// until someone opens it: no listener runs for the signals list, and the one
/// that runs for an open thread is bounded by [AppConstants.commentsShown] and
/// closes when the screen does.
class FirestoreCommentRepository implements CommentRepository {
  FirestoreCommentRepository({
    required this.orgId,
    this.author,
    FirebaseFirestore? firestore,
  }) : _firestore = firestore ?? FirebaseFirestore.instance;

  final String orgId;

  /// Who comments are written as. Null when nobody is signed in, in which case
  /// reading yields nothing and writing is refused.
  final AppUser? author;

  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, dynamic>> _comments(String signalId) {
    return _firestore
        .collection(AppConstants.organisationsCollection)
        .doc(orgId)
        .collection(AppConstants.signalsCollection)
        .doc(signalId)
        .collection(AppConstants.commentsCollection);
  }

  @override
  Stream<List<Comment>> watch(String signalId) {
    // No organisation means nobody is signed in. Firestore rejects a path with
    // a blank segment outright, so answer with an empty thread instead.
    if (orgId.isEmpty) return Stream.value(const []);

    return _comments(signalId)
        .orderBy('createdAt')
        .limitToLast(AppConstants.commentsShown)
        // Metadata changes are free of read charges and are what flips a
        // comment from "Sending" to delivered.
        .snapshots(includeMetadataChanges: true)
        .map((query) => query.docs.map(CommentDto.fromDoc).toList())
        .transform(
          StreamTransformer<List<Comment>, List<Comment>>.fromHandlers(
            handleError: (error, stackTrace, sink) =>
                sink.addError(_translate(error), stackTrace),
          ),
        );
  }

  @override
  Future<void> add({required String signalId, required String body}) async {
    final writer = author;
    if (writer == null || orgId.isEmpty) {
      throw const AuthException('Sign in to join the discussion.');
    }

    final text = body.trim();
    if (CommentRules.problemWith(text) != null) {
      throw const ParseException('That comment cannot be posted.');
    }

    try {
      await _comments(
        signalId,
      ).add(CommentDto.toNewMap(body: text, author: writer));
    } on FirebaseException catch (error) {
      throw _translate(error);
    }
  }

  @override
  Future<void> delete({
    required String signalId,
    required String commentId,
  }) async {
    if (orgId.isEmpty) {
      throw const AuthException('Sign in to join the discussion.');
    }

    try {
      await _comments(signalId).doc(commentId).delete();
    } on FirebaseException catch (error) {
      throw _translate(error);
    }
  }

  /// Converts a Firestore error at the repository boundary, so nothing above
  /// this file catches a raw `FirebaseException`.
  Object _translate(Object error) {
    if (error is! FirebaseException) return error;

    return switch (error.code) {
      'permission-denied' => const PermissionException(
        'The backend refused this comment.',
      ),
      'unavailable' || 'deadline-exceeded' => const NetworkException(
        'The device could not reach the backend.',
      ),
      _ => error,
    };
  }
}
