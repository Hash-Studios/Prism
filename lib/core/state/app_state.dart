import 'dart:async';

import 'package:Prism/auth/badgeModel.dart';
import 'package:Prism/auth/google_auth.dart';
import 'package:Prism/auth/transactionModel.dart';
import 'package:Prism/auth/userModel.dart';
import 'package:Prism/core/constants/admin_users.dart';
import 'package:Prism/core/constants/app_constants.dart' as app_constants;
import 'package:Prism/core/di/injection.dart';
import 'package:Prism/core/state/auth_runtime.dart';
import 'package:Prism/core/utils/premium_wall_utils.dart' as premium_wall_utils;
import 'package:Prism/features/session/domain/entities/badge_entity.dart';
import 'package:Prism/features/session/domain/repositories/session_repository.dart';
import 'package:Prism/features/session/domain/entities/transaction_entity.dart';
import 'package:Prism/features/startup/domain/entities/startup_config_entity.dart';
import 'package:Prism/features/startup/domain/repositories/startup_repository.dart';
import 'package:Prism/main.dart' as main;

export 'package:Prism/core/utils/string_extensions.dart';

bool updateChecked = false;
bool updateAvailable = false;
Map versionInfo = <String, dynamic>{};
bool updateAlerted = false;
bool hasNotch = false;
double? notchSize;
bool tooltipShown = false;

SessionRepository? _sessionRepositoryOrNull() {
  if (!getIt.isRegistered<SessionRepository>()) {
    return null;
  }
  return getIt<SessionRepository>();
}

StartupRepository? _startupRepositoryOrNull() {
  if (!getIt.isRegistered<StartupRepository>()) {
    return null;
  }
  return getIt<StartupRepository>();
}

PrismUsersV2 _fallbackUser = app_constants.createGuestPrismUser();

PrismUsersV2 get prismUser {
  final repo = _sessionRepositoryOrNull();
  if (repo == null) {
    return _fallbackUser;
  }
  return repo.currentUser;
}

set prismUser(PrismUsersV2 value) {
  final repo = _sessionRepositoryOrNull();
  if (repo == null) {
    _fallbackUser = value;
    return;
  }
  unawaited(repo.replaceCurrentUser(value));
}

Future<void> persistPrismUser() async {
  final repo = _sessionRepositoryOrNull();
  if (repo != null) {
    await repo.replaceCurrentUser(prismUser);
    return;
  }
  if (main.prefs.isOpen) {
    await main.prefs.put(main.userHiveKey, prismUser);
  }
}

Future<void> patchPrismUser({
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
  Map<String, String>? links,
  List<String>? followers,
  List<String>? following,
  List<BadgeEntity>? badges,
  List<String>? subPrisms,
  List<TransactionEntity>? transactions,
  String? uploadsWeekStart,
  int? uploadsThisWeek,
}) async {
  final repo = _sessionRepositoryOrNull();
  if (repo != null) {
    await repo.patchCurrentUser(
      id: id,
      email: email,
      username: username,
      name: name,
      bio: bio,
      profilePhoto: profilePhoto,
      coverPhoto: coverPhoto,
      loggedIn: loggedIn,
      premium: premium,
      subscriptionTier: subscriptionTier,
      coins: coins,
      links: links,
      followers: followers,
      following: following,
      badges: badges,
      subPrisms: subPrisms,
      transactions: transactions,
      uploadsWeekStart: uploadsWeekStart,
      uploadsThisWeek: uploadsThisWeek,
    );
    return;
  }
  if (id != null) _fallbackUser.id = id;
  if (email != null) _fallbackUser.email = email;
  if (username != null) _fallbackUser.username = username;
  if (name != null) _fallbackUser.name = name;
  if (bio != null) _fallbackUser.bio = bio;
  if (profilePhoto != null) _fallbackUser.profilePhoto = profilePhoto;
  if (coverPhoto != null) _fallbackUser.coverPhoto = coverPhoto;
  if (loggedIn != null) _fallbackUser.loggedIn = loggedIn;
  if (premium != null) _fallbackUser.premium = premium;
  if (subscriptionTier != null) _fallbackUser.subscriptionTier = subscriptionTier;
  if (coins != null) _fallbackUser.coins = coins;
  if (links != null) _fallbackUser.links = links;
  if (followers != null) _fallbackUser.followers = followers;
  if (following != null) _fallbackUser.following = following;
  if (badges != null) {
    _fallbackUser.badges = badges
        .map(
          (badge) => Badge(
            id: badge.id,
            name: badge.name,
            description: badge.description,
            imageUrl: badge.imageUrl,
            color: badge.color,
            url: badge.url,
            awardedAt: badge.awardedAt,
          ),
        )
        .toList(growable: false);
  }
  if (subPrisms != null) _fallbackUser.subPrisms = subPrisms;
  if (transactions != null) {
    _fallbackUser.transactions = transactions
        .map(
          (transaction) => PrismTransaction(
            id: transaction.id,
            name: transaction.name,
            description: transaction.description,
            amount: transaction.amount,
            credit: transaction.credit,
            by: transaction.by,
            processedAt: transaction.processedAt,
          ),
        )
        .toList(growable: false);
  }
  if (uploadsWeekStart != null) _fallbackUser.uploadsWeekStart = uploadsWeekStart;
  if (uploadsThisWeek != null) _fallbackUser.uploadsThisWeek = uploadsThisWeek;
}

Future<void> refreshSessionFromPersistence() async {
  final repo = _sessionRepositoryOrNull();
  if (repo != null) {
    await repo.getSession();
    return;
  }
  if (!main.prefs.isOpen) {
    return;
  }
  final dynamic raw = main.prefs.get(main.userHiveKey);
  if (raw is PrismUsersV2) {
    _fallbackUser = raw;
  }
}

StartupConfigEntity? get startupConfig {
  final repo = _startupRepositoryOrNull();
  if (repo == null) {
    return null;
  }
  return repo.currentConfig;
}

String get currentAppVersion => app_constants.currentAppVersion;
String get currentAppVersionCode => app_constants.currentAppVersionCode;
String get obsoleteAppVersion => startupConfig?.obsoleteAppVersion ?? app_constants.defaultObsoleteAppVersion;

String get topImageLink => startupConfig?.topImageLink ?? app_constants.defaultTopImageLink;
String get bannerText => startupConfig?.bannerText ?? app_constants.defaultBannerText;
bool get bannerTextOn => startupConfig?.bannerTextOn ?? app_constants.defaultBannerTextOn;
String get bannerURL => startupConfig?.bannerUrl ?? app_constants.defaultBannerUrl;

bool get followersTab => startupConfig?.followersTab ?? true;

bool get aiEnabled => startupConfig?.aiEnabled ?? app_constants.defaultAiEnabled;
int get aiRolloutPercent => startupConfig?.aiRolloutPercent ?? app_constants.defaultAiRolloutPercent;
bool get aiSubmitEnabled => startupConfig?.aiSubmitEnabled ?? app_constants.defaultAiSubmitEnabled;
bool get aiVariationsEnabled => startupConfig?.aiVariationsEnabled ?? app_constants.defaultAiVariationsEnabled;
bool get useRcPaywalls => startupConfig?.useRcPaywalls ?? app_constants.defaultUseRcPaywalls;

List<String> get topTitleText => List<String>.from(startupConfig?.topTitleText ?? app_constants.defaultTopTitleText);
List<String> get premiumCollections =>
    List<String>.from(startupConfig?.premiumCollections ?? app_constants.defaultPremiumCollections);
List<String> get verifiedUsers => List<String>.from(startupConfig?.verifiedUsers ?? app_constants.defaultVerifiedUsers);

String get defaultProfilePhotoUrl => app_constants.defaultProfilePhotoUrl;

bool isAdminUser([String? email]) {
  final String target = (email ?? prismUser.email).trim().toLowerCase();
  return isAdminEmail(target);
}

bool isPremiumWall(List<String> premiumCollections, List<Object?> wallCollections) {
  return premium_wall_utils.isPremiumWall(premiumCollections, wallCollections);
}

GoogleAuth get gAuth => globalGoogleAuth;
