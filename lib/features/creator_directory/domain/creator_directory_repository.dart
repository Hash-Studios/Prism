import 'package:Prism/features/creator_directory/domain/creator_directory_entities.dart';

/// Reads the server-built creator directory. Blocked creators and the viewer are never returned.
abstract class CreatorDirectoryRepository {
  static const int pageSize = 12;

  /// Creators by rank, after [afterRank] when paging. [category] keeps creators with that main category.
  Future<CreatorPage> fetchPage({String? category, int? afterRank, int limit = pageSize});

  /// The uids in [uids] that the viewer follows.
  Future<Set<String>> followedAmong(List<String> uids);

  /// Up to [limit] creators like [uid] that the viewer does not follow yet.
  Future<List<DirectoryCreator>> similarTo(String uid, {int limit = 6});

  /// People the viewer follows who follow [creatorUid]. Cached for the app session.
  Future<FollowedBy> followedBy(String creatorUid);
}
