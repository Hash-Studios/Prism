import 'dart:async';

import 'package:Prism/auth/google_auth.dart';
import 'package:Prism/auth/userModel.dart';
import 'package:Prism/core/constants/admin_users.dart';
import 'package:Prism/core/constants/app_constants.dart' as app_constants;
import 'package:Prism/core/di/injection.dart';
import 'package:Prism/core/state/auth_runtime.dart';
import 'package:Prism/core/utils/premium_wall_utils.dart' as premium_wall_utils;
import 'package:Prism/features/session/domain/repositories/session_repository.dart';
import 'package:Prism/features/startup/domain/entities/startup_config_entity.dart';
import 'package:Prism/features/startup/domain/repositories/startup_repository.dart';
import 'package:package_info_plus/package_info_plus.dart';

export 'package:Prism/core/utils/string_extensions.dart';

bool updateChecked = false;
bool updateAvailable = false;
Map versionInfo = <String, dynamic>{};
bool updateAlerted = false;
bool hasNotch = false;
double? notchSize;
bool tooltipShown = false;

String _runtimeAppVersion = app_constants.currentAppVersion;
String _runtimeAppVersionCode = app_constants.currentAppVersionCode;

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
  _fallbackUser = prismUser;
}

StartupConfigEntity? get startupConfig {
  final repo = _startupRepositoryOrNull();
  if (repo == null) {
    return null;
  }
  return repo.currentConfig;
}

String get currentAppVersion => _runtimeAppVersion;
String get currentAppVersionCode => _runtimeAppVersionCode;
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

Future<void> initializeRuntimeAppVersion() async {
  final PackageInfo info = await PackageInfo.fromPlatform();
  final String version = info.version.trim();
  final String build = info.buildNumber.trim();
  if (version.isNotEmpty) {
    _runtimeAppVersion = version;
  }
  if (build.isNotEmpty) {
    _runtimeAppVersionCode = build;
  }
}
