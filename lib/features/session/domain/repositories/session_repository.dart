import 'package:Prism/auth/user_model.dart';
import 'package:Prism/core/utils/result.dart';
import 'package:Prism/features/session/domain/entities/session_entity.dart';

abstract class SessionRepository {
  PrismUsersV2 get currentUser;

  Stream<PrismUsersV2> watchCurrentUser();

  Future<Result<SessionEntity>> getSession();

  Future<Result<SessionEntity>> replaceCurrentUser(PrismUsersV2 user);

  Future<Result<SessionEntity>> updateFollowing(List<String> following);
}
