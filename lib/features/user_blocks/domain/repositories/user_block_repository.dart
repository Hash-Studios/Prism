import 'package:Prism/core/user_blocks/blocked_creators.dart';
import 'package:Prism/core/utils/result.dart';

/// Server-backed block list + callable mutations.
abstract class UserBlockRepository {
  /// Live blocked creators for the active session. Unknown until the session's list loads.
  Stream<BlockedCreators> watchBlockedCreators();

  /// Latest value of [watchBlockedCreators].
  BlockedCreators get blockedCreators;

  /// Waits for the active session's list to load. Gives [UnknownBlockedCreators] if it does not load in time.
  Future<BlockedCreators> loadBlockedCreators();

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
