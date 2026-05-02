import 'dart:async';
import 'dart:convert';

import 'package:Prism/core/constants/app_constants.dart';
import 'package:Prism/core/di/injection.dart';
import 'package:Prism/core/error/failure.dart';
import 'package:Prism/core/persistence/data_sources/settings_local_data_source.dart';
import 'package:Prism/core/startup/firebase_init.dart';
import 'package:Prism/core/utils/result.dart';
import 'package:Prism/data/categories/categories.dart' as category_data;
import 'package:Prism/data/notifications/notifications.dart';
import 'package:Prism/features/in_app_notifications/biz/bloc/in_app_notifications_bloc.j.dart';
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
  StartupRepositoryImpl(this._settingsLocal);

  final SettingsLocalDataSource _settingsLocal;
  final StreamController<StartupConfigEntity> _configController = StreamController<StartupConfigEntity>.broadcast();

  StartupConfigEntity? _currentConfig;

  @override
  StartupConfigEntity? get currentConfig => _currentConfig;

  @override
  Stream<StartupConfigEntity> watchConfig() async* {
    if (_currentConfig != null) {
      yield _currentConfig!;
    }
    yield* _configController.stream;
  }

  List<String> _parseStringList(String raw) {
    var normalized = raw.replaceAll('"', '');
    normalized = normalized.replaceAll('[', '');
    normalized = normalized.replaceAll(',]', '');
    if (normalized.trim().isEmpty) {
      return <String>[];
    }
    return normalized.split(',').map((e) => e.trim()).where((e) => e.isNotEmpty).toList(growable: false);
  }

  List<Map<String, dynamic>> _parseStarterPack(String raw) {
    try {
      final decoded = json.decode(raw);
      if (decoded is List) {
        return decoded.whereType<Map<String, dynamic>>().toList(growable: false);
      }
    } catch (_) {
      // Fallback to legacy parser below.
    }

    final parsed = <Map<String, dynamic>>[];
    var temp = raw.replaceAll('[', '').replaceAll(']', '').split('},');
    if (temp.length > 1) {
      temp = temp.sublist(0, temp.length - 1);
    }
    for (final element in temp) {
      try {
        final map = json.decode('$element}') as Map<String, dynamic>;
        parsed.add(map);
      } catch (_) {}
    }

    if (parsed.isEmpty) {
      return <Map<String, dynamic>>[];
    }

    return parsed;
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
          'currentVersion': currentAppVersion,
          'obsoleteVersion': defaultObsoleteAppVersion,
          'topTitleText': defaultTopTitleText.toString(),
          'premiumCollections': defaultPremiumCollections.toString(),
          'verifiedUsers': defaultVerifiedUsers.toString(),
          'ai_enabled': defaultAiEnabled,
          'ai_rollout_percent': defaultAiRolloutPercent,
          'ai_submit_enabled': defaultAiSubmitEnabled,
          'ai_variations_enabled': defaultAiVariationsEnabled,
          'use_rc_paywalls': defaultUseRcPaywalls,
          'onboarding_v2_enabled': defaultOnboardingV2Enabled,
          'onboarding_starter_pack_v1': defaultOnboardingStarterPack.toString(),
          personalizedInterestsRemoteConfigKey: defaultPersonalizedInterestsJson,
        });
        await remoteConfig.fetchAndActivate();
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
      final topTitleText = _parseStringList(remoteConfig?.getString('topTitleText') ?? defaultTopTitleText.toString());
      final aiEnabled = remoteConfig?.getBool('ai_enabled') ?? defaultAiEnabled;
      final aiRolloutPercent = (remoteConfig?.getInt('ai_rollout_percent') ?? defaultAiRolloutPercent).clamp(0, 100);
      final aiSubmitEnabled = remoteConfig?.getBool('ai_submit_enabled') ?? defaultAiSubmitEnabled;
      final aiVariationsEnabled = remoteConfig?.getBool('ai_variations_enabled') ?? defaultAiVariationsEnabled;
      final useRcPaywalls = remoteConfig?.getBool('use_rc_paywalls') ?? defaultUseRcPaywalls;
      topTitleText.shuffle();
      final categories = category_data.categoryDefinitions
          .map(
            (def) => <String, dynamic>{
              'name': def.name,
              'source': def.source.name,
              'searchType': def.searchType.name,
              'imageUrl': def.imageUrl,
              'secondaryImageUrl': def.secondaryImageUrl,
            },
          )
          .toList(growable: false);

      final followersTab = _settingsLocal.get<bool>('followersTab', defaultValue: true);
      final onboardingV2Enabled = remoteConfig?.getBool('onboarding_v2_enabled') ?? defaultOnboardingV2Enabled;
      final onboardingStarterPack = _parseStarterPack(
        remoteConfig?.getString('onboarding_starter_pack_v1') ?? defaultOnboardingStarterPack.toString(),
      );

      final entity = StartupConfigEntity(
        topImageLink: topImageLink,
        bannerText: bannerText,
        bannerTextOn: bannerTextOn,
        bannerUrl: bannerUrl,
        obsoleteAppVersion: obsoleteVersion,
        verifiedUsers: verifiedUsers,
        premiumCollections: premiumCollections,
        topTitleText: topTitleText,
        categories: categories,
        followersTab: followersTab,
        aiEnabled: aiEnabled,
        aiRolloutPercent: aiRolloutPercent,
        aiSubmitEnabled: aiSubmitEnabled,
        aiVariationsEnabled: aiVariationsEnabled,
        useRcPaywalls: useRcPaywalls,
        onboardingV2Enabled: onboardingV2Enabled,
        onboardingStarterPack: onboardingStarterPack,
      );

      _currentConfig = entity;
      if (!_configController.isClosed) {
        _configController.add(entity);
      }

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
