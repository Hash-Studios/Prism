import 'package:Prism/core/utils/result.dart';

import 'package:Prism/features/public_profile/domain/entities/public_profile_entity.dart';
import 'package:Prism/features/public_profile/domain/entities/public_profile_page.dart';
import 'package:Prism/features/public_profile/domain/entities/public_profile_setup_entity.dart';
import 'package:Prism/features/public_profile/domain/entities/public_profile_wall_entity.dart';

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
}
