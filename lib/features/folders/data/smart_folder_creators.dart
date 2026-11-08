import 'package:Prism/features/public_profile/domain/entities/user_relation_kind.dart';
import 'package:Prism/features/public_profile/domain/entities/user_summary_entity.dart';
import 'package:Prism/features/public_profile/domain/repositories/public_profile_repository.dart';

Future<List<UserSummaryEntity>> loadSmartFolderCreators(
  PublicProfileRepository profiles,
  String uid,
  Iterable<String> picked,
) async {
  final List<String> following =
      (await profiles.fetchRelationIds(profileUid: uid, kind: UserRelationKind.following)).data ?? const <String>[];
  final List<String> ids = <String>{...picked, ...following}.toList();
  if (ids.isEmpty) return const <UserSummaryEntity>[];
  final List<UserSummaryEntity> creators = <UserSummaryEntity>[];
  for (int page = 0; page < ids.length; page++) {
    final result = (await profiles.fetchUserSummariesPage(userIds: ids, page: page)).data;
    if (result == null) break;
    creators.addAll(result.items);
    if (!result.hasMore) break;
  }
  return creators;
}
