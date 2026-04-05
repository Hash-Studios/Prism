import 'package:Prism/core/utils/result.dart';

/// Server-backed block list + callable mutations.
abstract class UserBlockRepository {
  /// Live blocked creator emails (lowercase), for UI and filtering.
  Stream<Set<String>> watchBlockedCreatorEmails();

  /// Last known set from [watchBlockedCreatorEmails]; empty until first emission.
  Set<String> get cachedBlockedCreatorEmails;

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
