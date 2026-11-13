import 'package:Prism/core/utils/result.dart';
import 'package:Prism/features/public_profile/domain/entities/public_profile_entity.dart';
import 'package:Prism/features/public_profile/domain/entities/public_profile_wall_entity.dart';
import 'package:Prism/features/public_profile/domain/entities/user_relation_kind.dart';
import 'package:Prism/features/public_profile/domain/entities/user_summary_entity.dart';

abstract class PublicProfileRepository {
  /// Most recent edges [fetchRelationIds] loads. Smart folders and relation search use it.
  static const int relationIdsLimit = 500;

  /// Edges per [fetchRelationPage]. It is also the Firestore `in` limit, so one profile read covers a page.
  static const int relationPageSize = 30;

  /// Users per [fetchUserSummariesPage].
  static const int summariesPageSize = 20;

  /// Loads up to [relationIdsLimit] ids from `profiles/{uid}/followers` or `/following`, newest first.
  Future<Result<List<String>>> fetchRelationIds({required String profileUid, required UserRelationKind kind});

  /// Loads the [relationPageSize] edges after [cursor] from `profiles/{uid}/followers` or `/following`, newest first.
  /// A null [cursor] loads the first page. Users the viewer blocked and users without a profile are left out, so a
  /// page can have fewer users than edges. [RelationPage.next] is null at the end of the list.
  Future<Result<RelationPage>> fetchRelationPage({
    required String profileUid,
    required UserRelationKind kind,
    RelationCursor? cursor,
  });

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
  /// [page] is zero-indexed, [summariesPageSize] users a page. Only that page's slice of [userIds] is queried,
  /// so the number of Firestore reads is bounded by the page size.
  Future<Result<({List<UserSummaryEntity> items, bool hasMore})>> fetchUserSummariesPage({
    required List<String> userIds,
    required int page,
  });

  /// Finds users in [scopeUserIds] whose username starts with [query],
  /// ignoring case (matches on the server-maintained `usernameLower`).
  ///
  /// Users the viewer blocked are left out. Returns at most 5 results, sorted by username.
  Future<Result<List<UserSummaryEntity>>> searchUsersByUsername({
    required String query,
    required List<String> scopeUserIds,
  });
}

/// Position of the last edge on a relation page. Only the repository reads its fields.
class RelationCursor {
  const RelationCursor({required this.createdAt, required this.edgeId});

  final Object? createdAt;
  final String edgeId;
}

/// One page of a followers or following list.
class RelationPage {
  const RelationPage({required this.users, required this.next});

  final List<UserSummaryEntity> users;

  /// Where the next page starts. Null when this page is the last one.
  final RelationCursor? next;
}
