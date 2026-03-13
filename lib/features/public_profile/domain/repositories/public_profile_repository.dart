import 'package:Prism/core/utils/result.dart';

import 'package:Prism/features/public_profile/domain/entities/public_profile_entity.dart';
import 'package:Prism/features/public_profile/domain/entities/public_profile_page.dart';
import 'package:Prism/features/public_profile/domain/entities/public_profile_setup_entity.dart';
import 'package:Prism/features/public_profile/domain/entities/public_profile_wall_entity.dart';
import 'package:Prism/features/public_profile/domain/entities/user_summary_entity.dart';

abstract class PublicProfileRepository {
  Future<Result<PublicProfileEntity>> fetchProfile({required String email});

  Future<Result<PublicProfilePage<PublicProfileWallEntity>>> fetchWalls({required String email, required bool refresh});

  Future<Result<PublicProfilePage<PublicProfileSetupEntity>>> fetchSetups({
    required String email,
    required bool refresh,
  });

  Future<Result<PublicProfileEntity>> follow({
    required String currentUserId,
    required String currentUserEmail,
    required String targetUserId,
    required String targetUserEmail,
  });

  Future<Result<PublicProfileEntity>> unfollow({
    required String currentUserId,
    required String currentUserEmail,
    required String targetUserId,
    required String targetUserEmail,
  });

  Future<Result<PublicProfileEntity>> updateLinks({required String userId, required Map<String, String> links});

  /// Fetches lightweight user summaries for the given list of [emails].
  /// [currentUserEmail] is used to determine [UserSummaryEntity.isFollowedByCurrentUser].
  Future<Result<List<UserSummaryEntity>>> fetchUserSummaries({
    required List<String> emails,
    required String currentUserEmail,
  });

  /// Fetches a single page of user summaries from [allEmails].
  ///
  /// [page] is zero-indexed. Only the slice
  /// `[page * pageSize, (page + 1) * pageSize)` of [allEmails] is queried,
  /// so the number of Firestore reads is bounded by [pageSize].
  Future<Result<({List<UserSummaryEntity> items, bool hasMore})>> fetchUserSummariesPage({
    required List<String> allEmails,
    required String currentUserEmail,
    required int page,
    int pageSize = 20,
  });

  /// Searches [usersv2] for users whose [username] starts with [query],
  /// then filters results to those whose email is in [scopeEmails].
  ///
  /// Returns at most [limit] results. Uses a Firestore prefix range query
  /// so it does not require loading all [scopeEmails].
  Future<Result<List<UserSummaryEntity>>> searchUsersByUsername({
    required String query,
    required List<String> scopeEmails,
    required String currentUserEmail,
    int limit = 5,
  });
}
