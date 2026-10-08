import 'dart:async';

import 'package:Prism/core/constants/app_constants.dart';
import 'package:Prism/core/di/injection.dart';
import 'package:Prism/core/error/failure.dart';
import 'package:Prism/core/startup/firebase_init.dart';
import 'package:Prism/core/utils/result.dart';
import 'package:Prism/data/notifications/notifications.dart';
import 'package:Prism/features/in_app_notifications/biz/bloc/in_app_notifications_bloc.j.dart';
import 'package:Prism/features/onboarding_v2/src/utils/onboarding_v2_config.dart';
import 'package:Prism/features/startup/domain/entities/startup_config_entity.dart';
import 'package:Prism/features/startup/domain/repositories/startup_repository.dart';
import 'package:Prism/logger/logger.dart';
import 'package:firebase_remote_config/firebase_remote_config.dart';
import 'package:flutter/foundation.dart';
import 'package:injectable/injectable.dart';

const Duration remoteConfigFetchBudget = Duration(seconds: 3);

/// A successful fetch newer than this is fresh enough that the splash does not wait for the next one.
const Duration remoteConfigFreshFor = Duration(hours: 24);

/// Applies cached values at once, then waits at most [fetchBudget] for fresh ones. A slow fetch keeps running and
/// activates on its own. Splash never waits on the network for long, and not at all when the last fetch is fresh.
@visibleForTesting
Future<void> prepareRemoteConfig(
  FirebaseRemoteConfig remoteConfig, {
  required bool release,
  Duration fetchBudget = remoteConfigFetchBudget,
  DateTime Function() now = DateTime.now,
}) async {
  await remoteConfig.setConfigSettings(
    RemoteConfigSettings(
      fetchTimeout: remoteConfigFetchBudget,
      minimumFetchInterval: release ? const Duration(hours: 1) : Duration.zero,
    ),
  );
  await remoteConfig.setDefaults(<String, dynamic>{
    'topImageLink': defaultTopImageLink,
    'bannerText': defaultBannerText,
    'bannerTextOn': defaultBannerTextOn.toString(),
    'bannerURL': defaultBannerUrl,
    'obsoleteVersion': defaultObsoleteAppVersion,
    'premiumCollections': defaultPremiumCollections.toString(),
    'verifiedUsers': defaultVerifiedUsers.toString(),
    'ai_enabled': defaultAiEnabled,
    'ai_rollout_percent': defaultAiRolloutPercent,
    'ai_submit_enabled': defaultAiSubmitEnabled,
    'ai_variations_enabled': defaultAiVariationsEnabled,
    'use_rc_paywalls': defaultUseRcPaywalls,
    'onboarding_v2_enabled': defaultOnboardingV2Enabled,
    OnboardingV2Config.remoteConfigStarterPackKey: defaultOnboardingStarterPack,
    personalizedInterestsRemoteConfigKey: defaultPersonalizedInterestsJson,
  });
  try {
    await remoteConfig.activate();
  } catch (error) {
    logger.w('Remote Config activate failed; using defaults.', tag: 'StartupRepository', error: error);
  }
  final Future<bool> fetch = remoteConfig.fetchAndActivate();
  unawaited(fetch.then<void>((_) {}, onError: (Object _) {}));
  final bool fresh =
      remoteConfig.lastFetchStatus == RemoteConfigFetchStatus.success &&
      now().difference(remoteConfig.lastFetchTime) < remoteConfigFreshFor;
  if (fresh) return;
  try {
    await fetch.timeout(fetchBudget);
  } catch (error) {
    // Offline, throttled or slow: keep the defaults and last activated values instead of failing startup.
    logger.w('Remote Config fetch failed; using cached values.', tag: 'StartupRepository', error: error);
  }
}

@LazySingleton(as: StartupRepository)
class StartupRepositoryImpl implements StartupRepository {
  // FirebaseRemoteConfig is intentionally NOT injected via the constructor.
  // Accessing FirebaseRemoteConfig.instance requires Firebase to be initialized,
  // which happens in the background after runApp(). Injecting it here would cause
  // the DI factory to call Firebase.instance before Firebase is ready.
  // Instead, it is accessed lazily inside bootstrap() after awaiting FirebaseInit.readyFuture.

  StartupConfigEntity? _currentConfig;

  @override
  StartupConfigEntity? get currentConfig => _currentConfig;

  List<String> _parseStringList(String raw) {
    var normalized = raw.replaceAll('"', '');
    normalized = normalized.replaceAll('[', '');
    normalized = normalized.replaceAll(',]', '');
    if (normalized.trim().isEmpty) {
      return <String>[];
    }
    return normalized.split(',').map((e) => e.trim()).where((e) => e.isNotEmpty).toList(growable: false);
  }

  @override
  Future<Result<StartupConfigEntity>> bootstrap() async {
    // Wait for Firebase (started in background from main()) before touching RemoteConfig.
    final bool firebaseReady = await FirebaseInit.readyFuture;

    // Only access FirebaseRemoteConfig.instance after Firebase is confirmed ready.
    final FirebaseRemoteConfig? remoteConfig = firebaseReady ? FirebaseRemoteConfig.instance : null;

    try {
      if (remoteConfig != null) {
        await prepareRemoteConfig(remoteConfig, release: kReleaseMode);
      } else {
        logger.w('Firebase not ready; using hardcoded default config values.', tag: 'StartupRepository');
      }

      final topImageLink = remoteConfig?.getString('topImageLink') ?? defaultTopImageLink;
      final bannerText = remoteConfig?.getString('bannerText') ?? defaultBannerText;
      final bannerTextOn = parseRemoteBool(
        remoteConfig?.getString('bannerTextOn') ?? defaultBannerTextOn.toString(),
        fallback: defaultBannerTextOn,
      );
      final bannerUrl = remoteConfig?.getString('bannerURL') ?? defaultBannerUrl;
      final obsoleteVersion = remoteConfig?.getString('obsoleteVersion') ?? defaultObsoleteAppVersion;
      final verifiedUsers = _parseStringList(
        remoteConfig?.getString('verifiedUsers') ?? defaultVerifiedUsers.toString(),
      );
      final premiumCollections = _parseStringList(
        remoteConfig?.getString('premiumCollections') ?? defaultPremiumCollections.toString(),
      );
      final aiEnabled = remoteConfig?.getBool('ai_enabled') ?? defaultAiEnabled;
      final aiRolloutPercent = (remoteConfig?.getInt('ai_rollout_percent') ?? defaultAiRolloutPercent).clamp(0, 100);
      final aiSubmitEnabled = remoteConfig?.getBool('ai_submit_enabled') ?? defaultAiSubmitEnabled;
      final aiVariationsEnabled = remoteConfig?.getBool('ai_variations_enabled') ?? defaultAiVariationsEnabled;
      final useRcPaywalls = remoteConfig?.getBool('use_rc_paywalls') ?? defaultUseRcPaywalls;
      final onboardingV2Enabled = remoteConfig?.getBool('onboarding_v2_enabled') ?? defaultOnboardingV2Enabled;

      final entity = StartupConfigEntity(
        topImageLink: topImageLink,
        bannerText: bannerText,
        bannerTextOn: bannerTextOn,
        bannerUrl: bannerUrl,
        obsoleteAppVersion: obsoleteVersion,
        verifiedUsers: verifiedUsers,
        premiumCollections: premiumCollections,
        aiEnabled: aiEnabled,
        aiRolloutPercent: aiRolloutPercent,
        aiSubmitEnabled: aiSubmitEnabled,
        aiVariationsEnabled: aiVariationsEnabled,
        useRcPaywalls: useRcPaywalls,
        onboardingV2Enabled: onboardingV2Enabled,
      );

      _currentConfig = entity;

      unawaited(syncInAppNotificationsFromRemote());
      if (getIt.isRegistered<InAppNotificationsBloc>()) {
        getIt<InAppNotificationsBloc>().add(const InAppNotificationsEvent.localReloadRequested());
      }

      return Result.success(entity);
    } catch (error) {
      return Result.error(ServerFailure('Startup bootstrap failed: $error'));
    }
  }
}
