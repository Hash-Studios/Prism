import 'dart:async';

import 'package:Prism/auth/userModel.dart';
import 'package:Prism/core/error/failure.dart';
import 'package:Prism/core/firestore/firestore_collections.dart';
import 'package:Prism/core/utils/result.dart';
import 'package:Prism/features/session/domain/repositories/session_repository.dart';
import 'package:Prism/features/user_blocks/domain/repositories/user_block_repository.dart';
import 'package:cloud_firestore/cloud_firestore.dart'
    show CollectionReference, FirebaseFirestore, QueryDocumentSnapshot, QuerySnapshot, Timestamp;
import 'package:cloud_functions/cloud_functions.dart' as cf;
import 'package:injectable/injectable.dart';
import 'package:rxdart/rxdart.dart';

@LazySingleton(as: UserBlockRepository)
class FirebaseUserBlockRepository implements UserBlockRepository {
  FirebaseUserBlockRepository(this._session) {
    // Repository lifetime matches the app lifetime, so this subscription stays active.
    // ignore: cancel_subscriptions
    _session.watchCurrentUser().listen(_handleSessionUser);
  }

  static const String _region = 'asia-south1';
  static const Duration _timeout = Duration(seconds: 25);
  static const String _subcollection = 'blockedUsers';

  final SessionRepository _session;
  StreamSubscription<Set<String>>? _blockedEmailsSubscription;

  final BehaviorSubject<Set<String>> _blockedEmailsSubject = BehaviorSubject<Set<String>>.seeded(<String>{});
  Completer<Set<String>> _initialLoadCompleter = Completer<Set<String>>();
  bool _hasLoadedBlockedCreatorEmails = false;
  String? _activeUserId;

  cf.FirebaseFunctions get _functions => cf.FirebaseFunctions.instanceFor(region: _region);

  @override
  Set<String> get cachedBlockedCreatorEmails => _blockedEmailsSubject.value;

  @override
  bool get hasLoadedBlockedCreatorEmails => _hasLoadedBlockedCreatorEmails;

  @override
  Future<Set<String>> getBlockedCreatorEmails({bool waitForInitialLoad = false}) async {
    if (!waitForInitialLoad || _hasLoadedBlockedCreatorEmails) {
      return _blockedEmailsSubject.value;
    }
    return _initialLoadCompleter.future;
  }

  @override
  Stream<Set<String>> watchBlockedCreatorEmails() => _blockedEmailsSubject.stream;

  void _handleSessionUser(PrismUsersV2 user) {
    final String nextUserId = (user.loggedIn ? user.id : '').trim();
    if (_activeUserId == nextUserId) {
      return;
    }
    _activeUserId = nextUserId;
    unawaited(_blockedEmailsSubscription?.cancel());
    _blockedEmailsSubscription = null;

    if (nextUserId.isEmpty) {
      _publishSnapshot(<String>{});
      return;
    }

    _beginPendingInitialLoad();
    _blockedEmailsSubscription = _snapshotStreamForUser(user).listen(_publishSnapshot);
  }

  void _beginPendingInitialLoad() {
    _hasLoadedBlockedCreatorEmails = false;
    if (_initialLoadCompleter.isCompleted) {
      _initialLoadCompleter = Completer<Set<String>>();
    }
  }

  void _publishSnapshot(Set<String> blockedEmails) {
    final Set<String> normalized = Set<String>.unmodifiable(blockedEmails);
    _blockedEmailsSubject.add(normalized);
    _hasLoadedBlockedCreatorEmails = true;
    if (!_initialLoadCompleter.isCompleted) {
      _initialLoadCompleter.complete(normalized);
    }
  }

  Stream<Set<String>> _snapshotStreamForUser(PrismUsersV2 user) {
    final bool loggedIn = user.loggedIn;
    final String id = user.id.trim();
    if (!loggedIn || id.isEmpty) {
      return Stream<Set<String>>.value(<String>{});
    }
    final CollectionReference<Map<String, dynamic>> ref = FirebaseFirestore.instance
        .collection(FirebaseCollections.usersV2)
        .doc(id)
        .collection(_subcollection);
    return ref.snapshots().map((QuerySnapshot<Map<String, dynamic>> snapshot) {
      final Set<String> out = <String>{};
      for (final QueryDocumentSnapshot<Map<String, dynamic>> doc in snapshot.docs) {
        final String be = (doc.data()['blockedEmail'] ?? '').toString().trim().toLowerCase();
        if (be.isNotEmpty) {
          out.add(be);
        }
      }
      return out;
    });
  }

  @override
  Future<Result<void>> blockUser({required String targetUserId}) async {
    final String tid = targetUserId.trim();
    if (tid.isEmpty) {
      return Result.error(const ValidationFailure('Invalid user.'));
    }
    try {
      final cf.HttpsCallable callable = _functions.httpsCallable(
        'blockUser',
        options: cf.HttpsCallableOptions(timeout: _timeout),
      );
      await callable.call(<String, dynamic>{'targetUserId': tid});
      return Result.success<void>(null);
    } on cf.FirebaseFunctionsException catch (e) {
      return Result.error(ServerFailure(e.message ?? e.code));
    } catch (e) {
      return Result.error(ServerFailure('Failed to block user: $e'));
    }
  }

  @override
  Future<Result<void>> unblockUser({required String targetUserId}) async {
    final String tid = targetUserId.trim();
    if (tid.isEmpty) {
      return Result.error(const ValidationFailure('Invalid user.'));
    }
    try {
      final cf.HttpsCallable callable = _functions.httpsCallable(
        'unblockUser',
        options: cf.HttpsCallableOptions(timeout: _timeout),
      );
      await callable.call(<String, dynamic>{'targetUserId': tid});
      return Result.success<void>(null);
    } on cf.FirebaseFunctionsException catch (e) {
      return Result.error(ServerFailure(e.message ?? e.code));
    } catch (e) {
      return Result.error(ServerFailure('Failed to unblock user: $e'));
    }
  }

  @override
  Future<Result<List<BlockedUserListRow>>> fetchBlockedUsersList() async {
    final String id = _session.currentUser.id.trim();
    if (!_session.currentUser.loggedIn || id.isEmpty) {
      return Result.success(<BlockedUserListRow>[]);
    }
    try {
      final QuerySnapshot<Map<String, dynamic>> snap = await FirebaseFirestore.instance
          .collection(FirebaseCollections.usersV2)
          .doc(id)
          .collection(_subcollection)
          .get();
      final List<QueryDocumentSnapshot<Map<String, dynamic>>> docs = snap.docs.toList(growable: false)
        ..sort((QueryDocumentSnapshot<Map<String, dynamic>> a, QueryDocumentSnapshot<Map<String, dynamic>> b) {
          final Object? ca = a.data()['createdAt'];
          final Object? cb = b.data()['createdAt'];
          if (ca is Timestamp && cb is Timestamp) {
            return cb.compareTo(ca);
          }
          if (ca is Timestamp) {
            return -1;
          }
          if (cb is Timestamp) {
            return 1;
          }
          return 0;
        });
      final List<BlockedUserListRow> rows = docs
          .map((QueryDocumentSnapshot<Map<String, dynamic>> d) {
            final Map<String, dynamic> m = d.data();
            final String email = (m['blockedEmail'] ?? '').toString().trim();
            final String? username = m['blockedUsername']?.toString().trim();
            return BlockedUserListRow(
              blockedUid: d.id,
              blockedEmail: email,
              blockedUsername: (username != null && username.isNotEmpty) ? username : null,
            );
          })
          .toList(growable: false);
      return Result.success(rows);
    } catch (e) {
      return Result.error(ServerFailure('Failed to load blocked users: $e'));
    }
  }
}
