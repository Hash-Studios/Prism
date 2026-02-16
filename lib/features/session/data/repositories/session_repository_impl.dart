import 'package:Prism/core/error/failure.dart';
import 'package:Prism/core/utils/result.dart';
import 'package:Prism/features/session/domain/entities/session_entity.dart';
import 'package:Prism/features/session/domain/repositories/session_repository.dart';
import 'package:Prism/global/globals.dart' as globals;
import 'package:Prism/main.dart' as main;
import 'package:Prism/payments/upgrade.dart';
import 'package:injectable/injectable.dart';

@LazySingleton(as: SessionRepository)
class SessionRepositoryImpl implements SessionRepository {
  SessionEntity _toEntity() {
    final user = globals.prismUser;
    return SessionEntity(
      userId: user.id,
      email: user.email,
      name: user.name,
      profilePhoto: user.profilePhoto,
      loggedIn: user.loggedIn,
      premium: user.premium,
    );
  }

  @override
  Future<Result<SessionEntity>> getSession() async {
    try {
      return Result.success(_toEntity());
    } catch (error) {
      return Result.error(CacheFailure('Unable to read session: $error'));
    }
  }

  @override
  Future<Result<SessionEntity>> refreshPremium() async {
    try {
      if (globals.prismUser.loggedIn) {
        await checkPremium();
        await main.prefs.put(main.userHiveKey, globals.prismUser);
      }
      return Result.success(_toEntity());
    } catch (error) {
      return Result.error(ServerFailure('Unable to refresh premium: $error'));
    }
  }

  @override
  Future<Result<SessionEntity>> signOut() async {
    try {
      await globals.gAuth.signOutGoogle();
      return Result.success(_toEntity());
    } catch (error) {
      return Result.error(ServerFailure('Unable to sign out: $error'));
    }
  }
}
