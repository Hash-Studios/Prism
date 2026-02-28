import 'dart:async';

import 'package:Prism/auth/apple_auth.dart';
import 'package:Prism/auth/badgeModel.dart';
import 'package:Prism/auth/google_auth.dart';
import 'package:Prism/auth/transactionModel.dart';
import 'package:Prism/auth/userModel.dart';
import 'package:Prism/core/constants/app_constants.dart';
import 'package:Prism/core/error/failure.dart';
import 'package:Prism/core/purchases/purchases_service.dart';
import 'package:Prism/core/state/auth_runtime.dart';
import 'package:Prism/core/utils/result.dart';
import 'package:Prism/features/session/domain/entities/session_entity.dart';
import 'package:Prism/features/session/domain/repositories/session_repository.dart';
import 'package:Prism/main.dart' as main;
import 'package:injectable/injectable.dart';

@LazySingleton(as: SessionRepository)
class SessionRepositoryImpl implements SessionRepository {
  SessionRepositoryImpl() {
    _currentUser = _readStoredUser();
  }

  final StreamController<PrismUsersV2> _currentUserController = StreamController<PrismUsersV2>.broadcast();

  late PrismUsersV2 _currentUser;

  GoogleAuth get _gAuth => globalGoogleAuth;
  AppleAuth get _appleAuth => globalAppleAuth;

  @override
  PrismUsersV2 get currentUser => _currentUser;

  @override
  Stream<PrismUsersV2> watchCurrentUser() async* {
    yield _currentUser;
    yield* _currentUserController.stream;
  }

  PrismUsersV2 _readStoredUser() {
    if (!main.prefs.isOpen) {
      return createGuestPrismUser();
    }
    final dynamic raw = main.prefs.get(main.userHiveKey);
    if (raw is PrismUsersV2) {
      return raw;
    }
    return createGuestPrismUser();
  }

  Future<void> _persistCurrentUser() async {
    if (!main.prefs.isOpen) {
      return;
    }
    await main.prefs.put(main.userHiveKey, _currentUser);
  }

  void _emitCurrentUser() {
    if (_currentUserController.isClosed) {
      return;
    }
    _currentUserController.add(_currentUser);
  }

  SessionEntity _toEntity() {
    return SessionEntity(
      userId: _currentUser.id,
      email: _currentUser.email,
      name: _currentUser.name,
      username: _currentUser.username,
      profilePhoto: _currentUser.profilePhoto,
      coverPhoto: _currentUser.coverPhoto ?? '',
      bio: _currentUser.bio,
      loggedIn: _currentUser.loggedIn,
      premium: _currentUser.premium,
      subscriptionTier: _currentUser.subscriptionTier,
      coins: _currentUser.coins,
      links: _currentUser.links.cast<String, dynamic>(),
      followers: List<dynamic>.from(_currentUser.followers),
      following: List<dynamic>.from(_currentUser.following),
      badges: List<dynamic>.from(_currentUser.badges),
      transactions: List<dynamic>.from(_currentUser.transactions),
      subPrisms: List<dynamic>.from(_currentUser.subPrisms),
      uploadsWeekStart: _currentUser.uploadsWeekStart,
      uploadsThisWeek: _currentUser.uploadsThisWeek,
    );
  }

  void _syncFromPrefs({bool emit = true}) {
    _currentUser = _readStoredUser();
    if (emit) {
      _emitCurrentUser();
    }
  }

  @override
  Future<Result<SessionEntity>> getSession() async {
    try {
      // Avoid emitting current-user updates while handling SessionEvent.started(),
      // otherwise SessionBloc's stream listener re-dispatches started in a loop.
      _syncFromPrefs(emit: false);
      return Result.success(_toEntity());
    } catch (error) {
      return Result.error(CacheFailure('Unable to read session: $error'));
    }
  }

  @override
  Future<Result<SessionEntity>> signInWithGoogle() async {
    try {
      final String result = await _gAuth.signInWithGoogle();
      if (result == GoogleAuth.signInCancelledResult) {
        _syncFromPrefs();
        return Result.success(_toEntity());
      }
      _syncFromPrefs();
      return Result.success(_toEntity());
    } catch (error) {
      return Result.error(ServerFailure('Unable to sign in: $error'));
    }
  }

  @override
  Future<Result<SessionEntity>> signInWithApple() async {
    try {
      final String result = await _appleAuth.signInWithApple();
      if (result == AppleAuth.signInCancelledResult) {
        _syncFromPrefs();
        return Result.success(_toEntity());
      }
      _syncFromPrefs();
      return Result.success(_toEntity());
    } catch (error) {
      return Result.error(ServerFailure('Unable to sign in with Apple: $error'));
    }
  }

  @override
  Future<Result<SessionEntity>> refreshPremium() async {
    try {
      if (_currentUser.loggedIn) {
        await PurchasesService.instance.checkAndPersistPremium();
      }
      _syncFromPrefs();
      return Result.success(_toEntity());
    } catch (error) {
      return Result.error(ServerFailure('Unable to refresh premium: $error'));
    }
  }

  @override
  Future<Result<SessionEntity>> signOut() async {
    try {
      await _gAuth.signOutGoogle();
      _syncFromPrefs();
      return Result.success(_toEntity());
    } catch (error) {
      return Result.error(ServerFailure('Unable to sign out: $error'));
    }
  }

  @override
  Future<Result<SessionEntity>> replaceCurrentUser(PrismUsersV2 user, {bool persist = true}) async {
    try {
      _currentUser = user;
      if (persist) {
        await _persistCurrentUser();
      }
      _emitCurrentUser();
      return Result.success(_toEntity());
    } catch (error) {
      return Result.error(CacheFailure('Unable to replace session: $error'));
    }
  }

  @override
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
  }) async {
    try {
      if (id != null) _currentUser.id = id;
      if (email != null) _currentUser.email = email;
      if (username != null) _currentUser.username = username;
      if (name != null) _currentUser.name = name;
      if (bio != null) _currentUser.bio = bio;
      if (profilePhoto != null) _currentUser.profilePhoto = profilePhoto;
      if (coverPhoto != null) _currentUser.coverPhoto = coverPhoto;
      if (loggedIn != null) _currentUser.loggedIn = loggedIn;
      if (premium != null) _currentUser.premium = premium;
      if (subscriptionTier != null) _currentUser.subscriptionTier = subscriptionTier;
      if (coins != null) _currentUser.coins = coins;
      if (links != null) _currentUser.links = links;
      if (followers != null) _currentUser.followers = followers;
      if (following != null) _currentUser.following = following;
      if (badges != null) _currentUser.badges = badges.whereType<Badge>().toList(growable: false);
      if (subPrisms != null) _currentUser.subPrisms = subPrisms;
      if (transactions != null) {
        _currentUser.transactions = transactions.whereType<PrismTransaction>().toList(growable: false);
      }
      if (uploadsWeekStart != null) _currentUser.uploadsWeekStart = uploadsWeekStart;
      if (uploadsThisWeek != null) _currentUser.uploadsThisWeek = uploadsThisWeek;

      if (persist) {
        await _persistCurrentUser();
      }
      _emitCurrentUser();
      return Result.success(_toEntity());
    } catch (error) {
      return Result.error(CacheFailure('Unable to patch session: $error'));
    }
  }
}
