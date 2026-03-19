import 'package:Prism/core/utils/result.dart';

import 'package:Prism/features/setups/domain/entities/setups_page.dart';

abstract class SetupsRepository {
  Future<Result<SetupsPage>> fetchSetups({required bool refresh});
}
