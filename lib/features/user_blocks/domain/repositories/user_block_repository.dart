import 'package:Prism/core/utils/result.dart';

/// Server-backed block list + callable mutations.
abstract class UserBlockRepository {
  /// Whether the first blocked-creator snapshot for the current session has loaded.
  bool get hasLoadedBlockedCreatorEmails;

  /// Live blocked creator emails (lowercase), for UI and filtering.
  Stream<Set<String>> watchBlockedCreatorEmails();

  /// Last known set from [watchBlockedCreatorEmails]; empty until first emission.
  Set<String> get cachedBlockedCreatorEmails;

  /// Returns blocked creator emails for the current session.
  ///
  /// When [waitForInitialLoad] is true, the future waits until the first
  /// snapshot for the active session has been loaded so callers can
  /// distinguish "not loaded yet" from "loaded empty set".
  Future<Set<String>> getBlockedCreatorEmails({bool waitForInitialLoad = false});

  Future<Result<List<BlockedUserListRow>>> fetchBlockedUsersList();

  Future<Result<void>> blockUser({required String targetUserId});

  Future<Result<void>> unblockUser({required String targetUserId});
}

/// Row for settings screen (includes display hint).
class BlockedUserListRow {
  const BlockedUserListRow({required this.blockedUid, required this.blockedEmail, this.blockedUsername});

  final String blockedUid;
  final String blockedEmail;
  final String? blockedUsername;
}
