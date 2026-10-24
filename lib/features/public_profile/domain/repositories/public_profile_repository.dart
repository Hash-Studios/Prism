import 'package:Prism/core/utils/result.dart';
import 'package:Prism/features/public_profile/domain/entities/public_profile_entity.dart';
import 'package:Prism/features/public_profile/domain/entities/public_profile_wall_entity.dart';
import 'package:Prism/features/public_profile/domain/entities/user_relation_kind.dart';
import 'package:Prism/features/public_profile/domain/entities/user_summary_entity.dart';

abstract class PublicProfileRepository {
  /// Most recent edges loaded for a followers or following list.
  static const int relationIdsLimit = 500;

  /// Loads up to [relationIdsLimit] ids from `profiles/{uid}/followers` or `/following`, newest first.
  /// One query, only when a list screen opens.
  Future<Result<List<String>>> fetchRelationIds({required String profileUid, required UserRelationKind kind});

  /// Live profile for a UID or canonical username. Email identifiers fail closed.
  Stream<PublicProfileEntity?> watchProfile(String identifier);

  /// Clears this owner's snapshots after queued snapshot writes finish.
  Future<void> clearForUser(String userId);

  Future<Result<({List<PublicProfileWallEntity> items, bool hasMore})>> fetchWalls({
    required String userId,
    required bool refresh,
  });

  Future<Result<void>> follow({
    required String currentUserId,
    required String currentUserEmail,
    required String targetUserId,
    required String targetUserEmail,
  });

  Future<Result<void>> unfollow({
    required String currentUserId,
    required String currentUserEmail,
    required String targetUserId,
    required String targetUserEmail,
  });

  /// Fetches a single page of user summaries from [userIds].
  ///
  /// [page] is zero-indexed. Only that page's slice of [userIds] is queried,
  /// so the number of Firestore reads is bounded by the page size.
  Future<Result<({List<UserSummaryEntity> items, bool hasMore})>> fetchUserSummariesPage({
    required List<String> userIds,
    required int page,
  });

  /// Finds users in [scopeUserIds] whose username starts with [query],
  /// ignoring case (matches on the server-maintained `usernameLower`).
  ///
  /// Returns at most 5 results, sorted by username.
  Future<Result<List<UserSummaryEntity>>> searchUsersByUsername({
    required String query,
    required List<String> scopeUserIds,
  });
}
