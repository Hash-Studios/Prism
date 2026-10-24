import 'package:Prism/core/utils/result.dart';

/// Server-backed block list + callable mutations.
abstract class UserBlockRepository {
  /// Live blocked creator UIDs for feed filtering.
  Stream<Set<String>> watchBlockedCreatorUids();

  /// Last known set from [watchBlockedCreatorUids]; empty until first emission.
  Set<String> get cachedBlockedCreatorUids;

  /// Returns blocked creator UIDs for the current session.
  ///
  /// When [waitForInitialLoad] is true, the future waits until the first
  /// snapshot for the active session has been loaded so callers can
  /// distinguish "not loaded yet" from "loaded empty set".
  Future<Set<String>> getBlockedCreatorUids({bool waitForInitialLoad = false});

  /// Clears this owner's cached block records after all queued writes finish.
  Future<void> clearForUser(String userId);

  Future<Result<List<BlockedUserListRow>>> fetchBlockedUsersList();

  Future<Result<void>> blockUser({required String targetUserId});

  Future<Result<void>> unblockUser({required String targetUserId});
}

/// Row for settings screen (includes display hint).
class BlockedUserListRow {
  const BlockedUserListRow({required this.blockedUid, this.blockedUsername, this.syncStatus = 'synced'});

  final String blockedUid;
  final String? blockedUsername;
  final String syncStatus;
}
