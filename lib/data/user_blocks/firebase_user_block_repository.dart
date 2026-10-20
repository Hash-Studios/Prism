import 'dart:async';

import 'package:Prism/auth/user_model.dart';
import 'package:Prism/core/constants/app_functions.dart';
import 'package:Prism/core/error/failure.dart';
import 'package:Prism/core/firestore/firestore_client.dart';
import 'package:Prism/core/firestore/firestore_collections.dart';
import 'package:Prism/core/firestore/firestore_query_specs.dart';
import 'package:Prism/core/offline/durable_json_store.dart';
import 'package:Prism/core/utils/result.dart';
import 'package:Prism/core/wallpaper/parse_helpers.dart';
import 'package:Prism/features/session/domain/repositories/session_repository.dart';
import 'package:Prism/features/user_blocks/domain/repositories/user_block_repository.dart';
import 'package:Prism/features/user_blocks/user_block_snapshot_codec.dart';
import 'package:Prism/logger/logger.dart';
import 'package:cloud_functions/cloud_functions.dart' as cf;
import 'package:injectable/injectable.dart';
import 'package:rxdart/rxdart.dart';

@LazySingleton(as: UserBlockRepository)
class FirebaseUserBlockRepository implements UserBlockRepository {
  FirebaseUserBlockRepository(this._session, this._firestoreClient, {@ignoreParam DurableJsonStore? store})
    : _localBlocks = store ?? DurableJsonStore('user_blocks') {
    _sessionSubscription = _session.watchCurrentUser().listen(_handleSessionUser);
  }

  static const Duration _timeout = Duration(seconds: 25);
  static const Duration _initialLoadTimeout = Duration(seconds: 3);
  static const String _subcollection = 'blockedUsers';

  final SessionRepository _session;
  final FirestoreClient _firestoreClient;
  final DurableJsonStore _localBlocks;
  final Map<String, Future<void>> _blockWriteTails = <String, Future<void>>{};
  final Map<String, Future<void>> _blockSendTails = <String, Future<void>>{};
  final Set<Future<void>> _lifecycleTasks = <Future<void>>{};
  final Set<String> _clearingBlockUsers = <String>{};
  final Set<String> _retryingBlockUsers = <String>{};
  final Map<String, Completer<void>> _retryCancellation = <String, Completer<void>>{};
  late final StreamSubscription<PrismUsersV2> _sessionSubscription;
  StreamSubscription<Set<String>>? _blockedEmailsSubscription;

  final BehaviorSubject<Set<String>> _blockedEmailsSubject = BehaviorSubject<Set<String>>.seeded(<String>{});
  Completer<Set<String>> _initialLoadCompleter = Completer<Set<String>>();
  bool _hasLoadedBlockedCreatorEmails = false;
  String? _activeUserId;
  bool _disposed = false;
  Future<void>? _disposeFuture;

  Future<void> dispose() => _disposeFuture ??= _dispose();

  Future<void> _dispose() async {
    _disposed = true;
    _activeUserId = null;
    for (final Completer<void> cancellation in _retryCancellation.values) {
      if (!cancellation.isCompleted) cancellation.complete();
    }
    await _sessionSubscription.cancel();
    await _blockedEmailsSubscription?.cancel();
    _blockedEmailsSubscription = null;
    while (_lifecycleTasks.isNotEmpty) {
      await Future.wait<void>(List<Future<void>>.of(_lifecycleTasks));
    }
    await _blockedEmailsSubject.close();
  }

  void _trackLifecycle(Future<void> task) {
    _lifecycleTasks.add(task);
    unawaited(
      task.then<void>((_) => _lifecycleTasks.remove(task)).catchError((Object error, StackTrace stackTrace) {
        _lifecycleTasks.remove(task);
        Zone.current.handleUncaughtError(error, stackTrace);
      }),
    );
  }

  Future<void> _waitForRetry(Duration delay, Completer<void> cancellation) {
    final Completer<void> finished = Completer<void>();
    final Timer timer = Timer(delay, finished.complete);
    cancellation.future.then((_) {
      if (!finished.isCompleted) finished.complete();
    });
    return finished.future.whenComplete(timer.cancel);
  }

  void _startPendingBlockRetry(String userId) {
    if (_disposed || _retryingBlockUsers.contains(userId)) return;
    _trackLifecycle(_retryPendingBlocks(userId));
  }

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

  @override
  Future<void> clearForUser(String userId) async {
    final String owner = userId.trim();
    if (owner.isEmpty) return;
    _clearingBlockUsers.add(owner);
    await _serializeBlockOwner(owner, () async {
      final Map<String, Map<String, Object?>> records = await _localBlocks.readAll();
      for (final String key in records.keys.where((key) => key.startsWith('$owner::'))) {
        await _localBlocks.delete(key);
      }
    });
  }

  void _handleSessionUser(PrismUsersV2 user) {
    if (_disposed) return;
    final String nextUserId = (user.loggedIn ? user.id : '').trim();
    if (_activeUserId == nextUserId) {
      return;
    }
    final String? previousUserId = _activeUserId;
    _activeUserId = nextUserId;
    if (previousUserId != null) {
      final Completer<void>? cancellation = _retryCancellation.remove(previousUserId);
      if (cancellation != null && !cancellation.isCompleted) cancellation.complete();
    }
    unawaited(_blockedEmailsSubscription?.cancel());
    _blockedEmailsSubscription = null;

    if (nextUserId.isEmpty) {
      _publishSnapshot(<String>{});
      return;
    }

    _beginPendingInitialLoad();
    _blockedEmailsSubject.add(const <String>{});
    _trackLifecycle(_loadLocalBlocks(nextUserId));
    _blockedEmailsSubscription = _watchBlockedEmails(nextUserId).listen(
      (emails) {
        if (_activeUserId != nextUserId || _session.currentUser.id != nextUserId) return;
        if (!_disposed) {
          _trackLifecycle(_publishMergedSnapshot(nextUserId, serverEmails: emails));
          _startPendingBlockRetry(nextUserId);
        }
      },
      onError: (Object error, StackTrace stackTrace) {
        logger.w('Blocked users stream failed; keeping the last known set.', tag: 'UserBlocks', error: error);
        if (!_disposed) _trackLifecycle(_publishMergedSnapshot(nextUserId, completeInitialLoadWhenUnavailable: true));
      },
    );
  }

  Future<void> _loadLocalBlocks(String userId) async {
    try {
      await _publishMergedSnapshot(userId);
      if (_disposed || _activeUserId != userId || _session.currentUser.id != userId) return;
      _startPendingBlockRetry(userId);
    } catch (error, stackTrace) {
      logger.w('Could not read local blocked users.', tag: 'UserBlocks', error: error, stackTrace: stackTrace);
    }
  }

  Future<void> _publishMergedSnapshot(
    String userId, {
    Set<String>? serverEmails,
    bool completeInitialLoadWhenUnavailable = false,
  }) async {
    if (serverEmails != null) {
      if (_clearingBlockUsers.contains(userId)) return;
      await _serializeBlockOwner(userId, () async {
        if (_clearingBlockUsers.contains(userId)) return;
        await _localBlocks.write('$userId::server_emails', UserBlockSnapshotCodec.encodeEmails(serverEmails));
      });
    }
    if (_disposed || _clearingBlockUsers.contains(userId)) return;
    final records = await _localBlocks.readAll();
    if (_disposed || _activeUserId != userId || _session.currentUser.id != userId) return;
    final savedServerEmails = await _localBlocks.read('$userId::server_emails');
    final savedServerRows = await _localBlocks.read('$userId::server_rows');
    if (_disposed || _activeUserId != userId || _session.currentUser.id != userId) return;
    final bool hasKnownServerSnapshot = serverEmails != null || savedServerEmails != null || savedServerRows != null;
    final Set<String> emails = <String>{
      ...serverEmails ??
          (savedServerEmails == null ? const <String>{} : UserBlockSnapshotCodec.decodeEmails(savedServerEmails)),
      if (serverEmails == null && savedServerEmails == null && savedServerRows != null)
        ...UserBlockSnapshotCodec.decodeRows(savedServerRows).map((row) => row.blockedEmail.trim().toLowerCase()),
    }..removeWhere((email) => email.isEmpty);
    for (final entry in records.entries.where((entry) => entry.key.startsWith('$userId::'))) {
      final operation = entry.value;
      if (operation['status'] == 'synced') continue;
      final email = (operation['email']?.toString() ?? '').trim().toLowerCase();
      if (email.isEmpty) continue;
      if (operation['desired'] == true) {
        emails.add(email);
      } else {
        emails.remove(email);
      }
    }
    _publishSnapshot(emails, completeInitialLoad: hasKnownServerSnapshot || completeInitialLoadWhenUnavailable);
  }

  void _beginPendingInitialLoad() {
    _hasLoadedBlockedCreatorEmails = false;
    if (_initialLoadCompleter.isCompleted) {
      _initialLoadCompleter = Completer<Set<String>>();
    }
  }

  void _publishSnapshot(Set<String> blockedEmails, {bool completeInitialLoad = true}) {
    final Set<String> normalized = Set<String>.unmodifiable(blockedEmails);
    _blockedEmailsSubject.add(normalized);
    if (completeInitialLoad) _hasLoadedBlockedCreatorEmails = true;
    if (completeInitialLoad && !_initialLoadCompleter.isCompleted) {
      _initialLoadCompleter.complete(normalized);
    }
  }

  String _blockedUsersPath(String userId) => '${FirebaseCollections.usersV2}/$userId/$_subcollection';

  Future<Map<String, Object?>> _saveBlockIntent(
    String userId,
    String targetId, {
    required bool desired,
    required String email,
  }) async {
    if (_clearingBlockUsers.contains(userId)) throw StateError('This account was deleted.');
    late Map<String, Object?> operation;
    await _serializeBlockOwner(userId, () async {
      if (_clearingBlockUsers.contains(userId)) throw StateError('This account was deleted.');
      final String key = '$userId::$targetId';
      final previous = await _localBlocks.read(key);
      final revision = (previous?['revision'] as int? ?? 0) + 1;
      operation = <String, Object?>{
        ...?previous,
        'owner': userId,
        'targetId': targetId,
        'email': email.isEmpty ? (previous?['email']) : email,
        'revision': revision,
        'operationId': '$userId:$targetId:$revision',
        'desired': desired,
        'status': 'pending',
      };
      await _localBlocks.write(key, operation);
    });
    return operation;
  }

  Future<void> _updateBlockIntent(
    String userId,
    String targetId,
    String operationId, {
    required String status,
    String? error,
  }) => _serializeBlockOwner(userId, () async {
    if (_clearingBlockUsers.contains(userId)) return;
    final String key = '$userId::$targetId';
    final current = await _localBlocks.read(key);
    if (current?['operationId'] != operationId) return;
    await _localBlocks.write(key, <String, Object?>{
      ...current!,
      'status': status,
      if (status == 'pending') 'attempts': (current['attempts'] as int? ?? 0) + 1,
      if (error != null) 'error': error,
    });
  });

  Future<T> _serializeBlockOwner<T>(String userId, Future<T> Function() action) {
    final Future<void> previous = _blockWriteTails[userId] ?? Future<void>.value();
    final Future<T> next = previous.catchError((Object _) {}).then((_) => action());
    final Future<void> tail = next.then<void>((_) {}, onError: (Object _, StackTrace _) {});
    _blockWriteTails[userId] = tail;
    return next.whenComplete(() {
      if (identical(_blockWriteTails[userId], tail)) _blockWriteTails.remove(userId);
    });
  }

  Future<bool> _sendBlockIntentIfCurrent(
    String userId,
    String targetId,
    String operationId,
    Future<void> Function() send,
  ) => _serializeBlockSend<bool>(userId, () async {
    final bool isCurrent = await _serializeBlockOwner(userId, () async {
      final current = await _localBlocks.read('$userId::$targetId');
      return current?['operationId'] == operationId && _activeUserId == userId && _session.currentUser.id == userId;
    });
    if (!isCurrent) return false;
    await send();
    return true;
  });

  Future<T> _serializeBlockSend<T>(String userId, Future<T> Function() action) {
    final Future<void> previous = _blockSendTails[userId] ?? Future<void>.value();
    final Future<T> next = previous.catchError((Object _) {}).then((_) => action());
    final Future<void> tail = next.then<void>((_) {}, onError: (Object _, StackTrace _) {});
    _blockSendTails[userId] = tail;
    return next.whenComplete(() {
      if (identical(_blockSendTails[userId], tail)) _blockSendTails.remove(userId);
    });
  }

  Stream<Set<String>> _watchBlockedEmails(String userId) {
    return _firestoreClient
        .watchQuery<String>(
          FirestoreQuerySpec(collection: _blockedUsersPath(userId), sourceTag: 'user_blocks.watch', isStream: true),
          (data, docId) => parseString(data['blockedEmail']).trim().toLowerCase(),
        )
        .map((emails) => emails.where((email) => email.isNotEmpty).toSet());
  }

  @override
  Future<Result<void>> blockUser({required String targetUserId, String? targetEmail}) async {
    final String tid = targetUserId.trim();
    if (tid.isEmpty) {
      return Result.error(const ValidationFailure('Invalid user.'));
    }
    final String uid = _session.currentUser.id.trim();
    final String email = (targetEmail ?? '').trim().toLowerCase();
    if (uid.isEmpty) return Result.error(const ValidationFailure('Sign in to block users.'));
    late String operationId;
    try {
      final operation = await _saveBlockIntent(uid, tid, desired: true, email: email);
      operationId = operation['operationId']! as String;
      if (_activeUserId == uid && _session.currentUser.id == uid && email.isNotEmpty) {
        _publishSnapshot(<String>{..._blockedEmailsSubject.value, email});
      }
    } catch (error) {
      return Result.error(ServerFailure('Could not save block locally: $error'));
    }
    try {
      final bool sent = await _sendBlockIntentIfCurrent(uid, tid, operationId, () async {
        final cf.HttpsCallable callable = appFunctions.httpsCallable(
          'blockUser',
          options: cf.HttpsCallableOptions(timeout: _timeout),
        );
        await callable.call(<String, dynamic>{'targetUserId': tid});
      });
      if (!sent) return Result.error(const ServerFailure('Pending sync: A newer block choice is waiting to sync.'));
      if (_clearingBlockUsers.contains(uid)) return Result.error(const ServerFailure('Account was deleted.'));
      if (_session.currentUser.id == uid) await _updateBlockIntent(uid, tid, operationId, status: 'synced');
      return Result.success<void>(null);
    } on cf.FirebaseFunctionsException catch (e) {
      if (_isPermanentBlockFailure(e)) {
        await _updateBlockIntent(uid, tid, operationId, status: 'rejected', error: e.message ?? e.code);
        return Result.error(ServerFailure(e.message ?? 'The block was rejected by the server.'));
      }
      logger.w('Block remains local and pending server retry.', tag: 'UserBlocks', error: e);
      _startPendingBlockRetry(uid);
      return Result.error(const ServerFailure('Pending sync: Block saved on this device; waiting to sync.'));
    } catch (e) {
      logger.w('Block remains local and pending server retry.', tag: 'UserBlocks', error: e);
      _startPendingBlockRetry(uid);
      return Result.error(const ServerFailure('Pending sync: Block saved on this device; waiting to sync.'));
    }
  }

  @override
  Future<Result<void>> unblockUser({required String targetUserId}) async {
    final String tid = targetUserId.trim();
    if (tid.isEmpty) {
      return Result.error(const ValidationFailure('Invalid user.'));
    }
    final String uid = _session.currentUser.id.trim();
    if (uid.isEmpty) return Result.error(const ValidationFailure('Sign in to unblock users.'));
    late String operationId;
    try {
      final operation = await _saveBlockIntent(uid, tid, desired: false, email: '');
      operationId = operation['operationId']! as String;
      final previousEmail = operation['email']?.toString().trim().toLowerCase() ?? '';
      if (_activeUserId == uid && _session.currentUser.id == uid) {
        _publishSnapshot(_blockedEmailsSubject.value.where((item) => item != previousEmail).toSet());
      }
      final bool sent = await _sendBlockIntentIfCurrent(uid, tid, operationId, () async {
        final cf.HttpsCallable callable = appFunctions.httpsCallable(
          'unblockUser',
          options: cf.HttpsCallableOptions(timeout: _timeout),
        );
        await callable.call(<String, dynamic>{'targetUserId': tid});
      });
      if (!sent) return Result.error(const ServerFailure('Pending sync: A newer unblock choice is waiting to sync.'));
      if (_clearingBlockUsers.contains(uid)) return Result.error(const ServerFailure('Account was deleted.'));
      if (_session.currentUser.id == uid) await _updateBlockIntent(uid, tid, operationId, status: 'synced');
      return Result.success<void>(null);
    } on cf.FirebaseFunctionsException catch (e) {
      if (_isPermanentBlockFailure(e)) {
        await _updateBlockIntent(uid, tid, operationId, status: 'rejected', error: e.message ?? e.code);
        return Result.error(ServerFailure(e.message ?? 'The unblock was rejected by the server.'));
      }
      logger.w('Unblock remains local and pending server retry.', tag: 'UserBlocks', error: e);
      _startPendingBlockRetry(uid);
      return Result.error(const ServerFailure('Pending sync: Unblock saved on this device; waiting to sync.'));
    } catch (e) {
      logger.w('Unblock remains local and pending server retry.', tag: 'UserBlocks', error: e);
      _startPendingBlockRetry(uid);
      return Result.error(const ServerFailure('Pending sync: Unblock saved on this device; waiting to sync.'));
    }
  }

  bool _isPermanentBlockFailure(cf.FirebaseFunctionsException error) => const <String>{
    'permission-denied',
    'invalid-argument',
    'not-found',
    'failed-precondition',
    'unauthenticated',
  }.contains(error.code);

  Future<void> _retryPendingBlocks(String userId) async {
    if (_disposed || !_retryingBlockUsers.add(userId)) return;
    final Completer<void> cancellation = Completer<void>();
    _retryCancellation[userId] = cancellation;
    var delay = const Duration(seconds: 2);
    try {
      while (!cancellation.isCompleted && _activeUserId == userId && _session.currentUser.id == userId) {
        Map<String, Map<String, Object?>> records;
        try {
          records = await _localBlocks.readAll();
        } catch (error, stackTrace) {
          logger.w('Could not read pending block operations.', tag: 'UserBlocks', error: error, stackTrace: stackTrace);
          await _waitForRetry(delay, cancellation);
          delay = Duration(seconds: (delay.inSeconds * 2).clamp(2, 60));
          continue;
        }
        final pending = records.entries
            .where(
              (entry) =>
                  entry.key.startsWith('$userId::') &&
                  entry.value['owner'] == userId &&
                  entry.value['status'] == 'pending',
            )
            .toList(growable: false);
        if (pending.isEmpty) return;
        for (final entry in pending) {
          if (cancellation.isCompleted || _activeUserId != userId || _session.currentUser.id != userId) return;
          final operation = entry.value;
          final String targetId = operation['targetId']?.toString() ?? '';
          final String operationId = operation['operationId']?.toString() ?? '';
          try {
            final String callableName = operation['desired'] == true ? 'blockUser' : 'unblockUser';
            final bool sent = await _sendBlockIntentIfCurrent(userId, targetId, operationId, () async {
              await appFunctions.httpsCallable(callableName, options: cf.HttpsCallableOptions(timeout: _timeout)).call(
                <String, dynamic>{'targetUserId': targetId},
              );
            });
            if (!sent) continue;
            if (cancellation.isCompleted || _activeUserId != userId || _session.currentUser.id != userId) return;
            await _updateBlockIntent(userId, targetId, operationId, status: 'synced');
          } on cf.FirebaseFunctionsException catch (error) {
            final bool rejected = error.code == 'permission-denied' || error.code == 'invalid-argument';
            await _updateBlockIntent(
              userId,
              targetId,
              operationId,
              status: rejected ? 'rejected' : 'pending',
              error: error.message ?? error.code,
            );
          } catch (error) {
            await _updateBlockIntent(userId, targetId, operationId, status: 'pending', error: error.toString());
          }
        }
        await _waitForRetry(delay, cancellation);
        delay = Duration(seconds: (delay.inSeconds * 2).clamp(2, 60));
      }
    } finally {
      _retryingBlockUsers.remove(userId);
      if (identical(_retryCancellation[userId], cancellation)) _retryCancellation.remove(userId);
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
      if (_session.currentUser.id != id) {
        return Result.error(const ServerFailure('Account changed while loading blocks.'));
      }
      final serverRows = docs.map((doc) => doc.$1).toList(growable: false);
      await _serializeBlockOwner(
        id,
        () => _localBlocks.write('$id::server_rows', UserBlockSnapshotCodec.encodeRows(serverRows)),
      );
      if (_session.currentUser.id != id) {
        return Result.error(const ServerFailure('Account changed while loading blocks.'));
      }
      final records = await _localBlocks.readAll();
      if (_session.currentUser.id != id) {
        return Result.error(const ServerFailure('Account changed while loading blocks.'));
      }
      final Map<String, BlockedUserListRow> rows = <String, BlockedUserListRow>{
        for (final row in serverRows) row.blockedUid: row,
      };
      for (final entry in records.entries.where(
        (entry) =>
            entry.key.startsWith('$id::') &&
            (entry.value['status'] == 'pending' || entry.value['status'] == 'rejected'),
      )) {
        final String target = entry.value['targetId']?.toString() ?? entry.key.substring('$id::'.length);
        if (entry.value['desired'] == true) {
          rows[target] = BlockedUserListRow(
            blockedUid: target,
            blockedEmail: entry.value['email']?.toString() ?? rows[target]?.blockedEmail ?? '',
            blockedUsername: entry.value['username']?.toString() ?? rows[target]?.blockedUsername,
            syncStatus: entry.value['status']?.toString() ?? 'pending',
          );
        } else {
          rows.remove(target);
        }
      }
      return Result.success(rows.values.toList(growable: false));
    } catch (e) {
      if (_session.currentUser.id == id) {
        try {
          final records = await _localBlocks.readAll();
          if (_session.currentUser.id != id) {
            return Result.error(const ServerFailure('Account changed while loading blocks.'));
          }
          final saved = await _localBlocks.read('$id::server_rows');
          if (_session.currentUser.id != id) {
            return Result.error(const ServerFailure('Account changed while loading blocks.'));
          }
          final pending = records.entries.where(
            (entry) =>
                entry.key.startsWith('$id::') &&
                entry.value['owner'] == id &&
                (entry.value['status'] == 'pending' || entry.value['status'] == 'rejected'),
          );
          if (saved == null && pending.isEmpty) {
            return Result.error(ServerFailure('Failed to load blocked users: $e'));
          }
          final Map<String, BlockedUserListRow> rows = <String, BlockedUserListRow>{
            for (final row in saved == null ? const <BlockedUserListRow>[] : UserBlockSnapshotCodec.decodeRows(saved))
              row.blockedUid: row,
          };
          for (final entry in pending) {
            final String target = entry.value['targetId']?.toString() ?? entry.key.substring('$id::'.length);
            if (entry.value['desired'] == true) {
              rows[target] = BlockedUserListRow(
                blockedUid: target,
                blockedEmail: entry.value['email']?.toString() ?? rows[target]?.blockedEmail ?? '',
                blockedUsername: entry.value['username']?.toString() ?? rows[target]?.blockedUsername,
                syncStatus: entry.value['status']?.toString() ?? 'pending',
              );
            } else {
              rows.remove(target);
            }
          }
          return Result.success(rows.values.toList(growable: false));
        } catch (_) {}
      }
      return Result.error(ServerFailure('Failed to load blocked users: $e'));
    }
  }
}
