import 'package:Prism/auth/userModel.dart';
import 'package:Prism/core/utils/result.dart';
import 'package:Prism/features/session/domain/entities/session_entity.dart';

abstract class SessionRepository {
  PrismUsersV2 get currentUser;

  Stream<PrismUsersV2> watchCurrentUser();

  Future<Result<SessionEntity>> getSession();

  Future<Result<SessionEntity>> signInWithGoogle();

  Future<Result<SessionEntity>> refreshPremium();

  Future<Result<SessionEntity>> signOut();

  Future<Result<SessionEntity>> replaceCurrentUser(PrismUsersV2 user, {bool persist = true});

  Future<Result<SessionEntity>> patchCurrentUser({
    String? id,
    String? email,
    String? username,
    String? name,
    String? bio,
    String? profilePhoto,
    String? coverPhoto,
    bool? loggedIn,
    bool? premium,
    String? subscriptionTier,
    int? coins,
    Map<dynamic, dynamic>? links,
    List<dynamic>? followers,
    List<dynamic>? following,
    List<dynamic>? badges,
    List<dynamic>? subPrisms,
    List<dynamic>? transactions,
    String? uploadsWeekStart,
    int? uploadsThisWeek,
    bool persist = true,
  });
}
