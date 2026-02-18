import 'package:Prism/core/utils/result.dart';

import 'package:Prism/features/profile_walls/domain/entities/profile_walls_page.dart';

abstract class ProfileWallsRepository {
  Future<Result<ProfileWallsPage>> fetchProfileWalls({required String email, required bool refresh});
}
