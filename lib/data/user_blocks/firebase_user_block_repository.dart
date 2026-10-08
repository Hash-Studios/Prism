import 'dart:async';

import 'package:Prism/auth/user_model.dart';
import 'package:Prism/core/constants/app_functions.dart';
import 'package:Prism/core/error/failure.dart';
import 'package:Prism/core/firestore/firestore_client.dart';
import 'package:Prism/core/firestore/firestore_collections.dart';
import 'package:Prism/core/firestore/firestore_query_specs.dart';
import 'package:Prism/core/utils/result.dart';
import 'package:Prism/core/wallpaper/parse_helpers.dart';
import 'package:Prism/features/session/domain/repositories/session_repository.dart';
import 'package:Prism/features/user_blocks/domain/repositories/user_block_repository.dart';
import 'package:Prism/logger/logger.dart';
import 'package:cloud_functions/cloud_functions.dart' as cf;
import 'package:injectable/injectable.dart';
import 'package:rxdart/rxdart.dart';

@LazySingleton(as: UserBlockRepository)
class FirebaseUserBlockRepository implements UserBlockRepository {
  FirebaseUserBlockRepository(this._session, this._firestoreClient) {
    // Repository lifetime matches the app lifetime, so this subscription stays active.
    // ignore: cancel_subscriptions
    _session.watchCurrentUser().listen(_handleSessionUser);
  }

  static const Duration _timeout = Duration(seconds: 25);
  static const Duration _initialLoadTimeout = Duration(seconds: 3);
  static const String _subcollection = 'blockedUsers';

  final SessionRepository _session;
  final FirestoreClient _firestoreClient;
  StreamSubscription<Set<String>>? _blockedEmailsSubscription;

  final BehaviorSubject<Set<String>> _blockedEmailsSubject = BehaviorSubject<Set<String>>.seeded(<String>{});
  Completer<Set<String>> _initialLoadCompleter = Completer<Set<String>>();
  bool _hasLoadedBlockedCreatorEmails = false;
  String? _activeUserId;

  @override
  Set<String> get cachedBlockedCreatorEmails => _blockedEmailsSubject.value;

  @override
  Future<Set<String>> getBlockedCreatorEmails({bool waitForInitialLoad = false}) async {
    if (!waitForInitialLoad || _hasLoadedBlockedCreatorEmails) {
      return _blockedEmailsSubject.value;
    }
    return _initialLoadCompleter.future.timeout(_initialLoadTimeout, onTimeout: () => _blockedEmailsSubject.value);
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
    _blockedEmailsSubscription = _watchBlockedEmails(nextUserId).listen(
      _publishSnapshot,
      onError: (Object error, StackTrace stackTrace) {
        logger.w('Blocked users stream failed; keeping the last known set.', tag: 'UserBlocks', error: error);
        _publishSnapshot(_blockedEmailsSubject.value);
      },
    );
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

  String _blockedUsersPath(String userId) => '${FirebaseCollections.usersV2}/$userId/$_subcollection';

  Stream<Set<String>> _watchBlockedEmails(String userId) {
    return _firestoreClient
        .watchQuery<String>(
          FirestoreQuerySpec(collection: _blockedUsersPath(userId), sourceTag: 'user_blocks.watch', isStream: true),
          (data, docId) => parseString(data['blockedEmail']).trim().toLowerCase(),
        )
        .map((emails) => emails.where((email) => email.isNotEmpty).toSet());
  }

  @override
  Future<Result<void>> blockUser({required String targetUserId}) async {
    final String tid = targetUserId.trim();
    if (tid.isEmpty) {
      return Result.error(const ValidationFailure('Invalid user.'));
    }
    try {
      final cf.HttpsCallable callable = appFunctions.httpsCallable(
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
      final cf.HttpsCallable callable = appFunctions.httpsCallable(
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
      final List<(BlockedUserListRow, DateTime?)> docs = await _firestoreClient.query<(BlockedUserListRow, DateTime?)>(
        FirestoreQuerySpec(collection: _blockedUsersPath(id), sourceTag: 'user_blocks.list'),
        (data, docId) {
          final String username = parseString(data['blockedUsername']).trim();
          return (
            BlockedUserListRow(
              blockedUid: docId,
              blockedEmail: parseString(data['blockedEmail']).trim(),
              blockedUsername: username.isEmpty ? null : username,
            ),
            parseDateTime(data['createdAt']),
          );
        },
      );
      docs.sort((a, b) {
        final DateTime? ca = a.$2;
        final DateTime? cb = b.$2;
        if (ca != null && cb != null) {
          return cb.compareTo(ca);
        }
        if (ca != null) {
          return -1;
        }
        return cb != null ? 1 : 0;
      });
      final List<BlockedUserListRow> rows = docs.map((doc) => doc.$1).toList(growable: false);
      return Result.success(rows);
    } catch (e) {
      return Result.error(ServerFailure('Failed to load blocked users: $e'));
    }
  }
}
