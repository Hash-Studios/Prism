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
import 'package:injectable/injectable.dart';

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
        await remoteConfig.setConfigSettings(
          RemoteConfigSettings(fetchTimeout: const Duration(seconds: 30), minimumFetchInterval: Duration.zero),
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
          await remoteConfig.fetchAndActivate();
        } catch (error) {
          // Offline or throttled: keep the defaults and last activated values instead of failing startup.
          logger.w('Remote Config fetch failed; using cached values.', tag: 'StartupRepository', error: error);
        }
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
