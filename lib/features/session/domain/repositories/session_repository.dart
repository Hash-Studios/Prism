import 'package:Prism/core/utils/result.dart';

import 'package:Prism/features/session/domain/entities/session_entity.dart';

abstract class SessionRepository {
  Future<Result<SessionEntity>> getSession();

  Future<Result<SessionEntity>> refreshPremium();

  Future<Result<SessionEntity>> signOut();
}
