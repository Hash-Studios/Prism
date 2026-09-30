import 'package:Prism/core/utils/result.dart';
import 'package:Prism/features/setups/domain/entities/setup_entity.dart';
import 'package:Prism/features/setups/domain/entities/setups_page.dart';

abstract class SetupsRepository {
  Future<Result<SetupsPage>> fetchSetups({required bool refresh});

  /// Resolves a reviewed setup by name for share links. `null` data means no such setup.
  Future<Result<SetupEntity?>> fetchSetupByName(String name);
}
