import 'package:Prism/core/utils/result.dart';
import 'package:Prism/features/folders/data/smart_folder_creators.dart';
import 'package:Prism/features/public_profile/domain/entities/user_relation_kind.dart';
import 'package:Prism/features/public_profile/domain/entities/user_summary_entity.dart';
import 'package:Prism/features/public_profile/domain/repositories/public_profile_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _Profiles extends Mock implements PublicProfileRepository {}

UserSummaryEntity _creator(String id) =>
    UserSummaryEntity(id: id, email: '', name: id, username: id, profilePhoto: '', isFollowedByCurrentUser: true);

void main() {
  test('the creator picker loads following pages after the first twenty creators', () async {
    final _Profiles profiles = _Profiles();
    final List<String> ids = List<String>.generate(21, (i) => 'creator$i');
    when(
      () => profiles.fetchRelationIds(profileUid: 'me', kind: UserRelationKind.following),
    ).thenAnswer((_) async => Result.success(ids));
    for (int page = 0; page < 2; page++) {
      final int current = page;
      when(() => profiles.fetchUserSummariesPage(userIds: ids, page: current)).thenAnswer(
        (_) async =>
            Result.success((items: ids.skip(current * 20).take(20).map(_creator).toList(), hasMore: current == 0)),
      );
    }

    final List<UserSummaryEntity> creators = await loadSmartFolderCreators(profiles, 'me', const <String>[]);

    expect(creators.map((user) => user.id), ids);
    verify(() => profiles.fetchUserSummariesPage(userIds: ids, page: 1)).called(1);
  });
}
