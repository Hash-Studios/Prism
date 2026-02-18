import 'package:Prism/core/utils/result.dart';

import 'package:Prism/features/profile_setups/domain/entities/profile_setups_page.dart';

abstract class ProfileSetupsRepository {
  Future<Result<ProfileSetupsPage>> fetchProfileSetups({required String email, required bool refresh});
}
