import 'package:Prism/core/utils/result.dart';
import 'package:Prism/features/public_profile/domain/entities/public_profile_entity.dart';
import 'package:Prism/features/public_profile/domain/entities/public_profile_wall_entity.dart';
import 'package:Prism/features/public_profile/domain/entities/user_summary_entity.dart';

abstract class PublicProfileRepository {
  /// Live profile for an email or username. Emits `null` when no user matches.
  Stream<PublicProfileEntity?> watchProfile(String identifier);

  Future<Result<({List<PublicProfileWallEntity> items, bool hasMore})>> fetchWalls({
    required String email,
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

  /// Fetches a single page of user summaries from [allEmails].
  ///
  /// [page] is zero-indexed. Only that page's slice of [allEmails] is queried,
  /// so the number of Firestore reads is bounded by the page size.
  Future<Result<({List<UserSummaryEntity> items, bool hasMore})>> fetchUserSummariesPage({
    required List<String> allEmails,
    required int page,
  });

  /// Finds users in [scopeEmails] whose username starts with [query],
  /// ignoring case (matches on the server-maintained `usernameLower`).
  ///
  /// Returns at most 5 results, sorted by username.
  Future<Result<List<UserSummaryEntity>>> searchUsersByUsername({
    required String query,
    required List<String> scopeEmails,
  });
}
