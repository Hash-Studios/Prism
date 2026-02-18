import 'dart:convert';

import 'package:Prism/core/error/failure.dart';
import 'package:Prism/core/utils/result.dart';
import 'package:Prism/data/categories/categories.dart' as category_data;
import 'package:Prism/data/notifications/notifications.dart';
import 'package:Prism/features/startup/domain/entities/startup_config_entity.dart';
import 'package:Prism/features/startup/domain/repositories/startup_repository.dart';
import 'package:Prism/global/globals.dart' as globals;
import 'package:firebase_remote_config/firebase_remote_config.dart';
import 'package:hive_io/hive_io.dart';
import 'package:injectable/injectable.dart';

@LazySingleton(as: StartupRepository)
class StartupRepositoryImpl implements StartupRepository {
  StartupRepositoryImpl(this._remoteConfig, @Named('prefsBox') this._prefsBox);

  final FirebaseRemoteConfig _remoteConfig;
  final Box<dynamic> _prefsBox;

  List<String> _parseStringList(String raw) {
    var normalized = raw.replaceAll('"', '');
    normalized = normalized.replaceAll('[', '');
    normalized = normalized.replaceAll(',]', '');
    if (normalized.trim().isEmpty) {
      return <String>[];
    }
    return normalized.split(',').map((e) => e.trim()).where((e) => e.isNotEmpty).toList(growable: false);
  }

  List<Map<String, dynamic>> _parseCategories(String raw) {
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
      return category_data.categories.whereType<Map<String, dynamic>>().toList(growable: false);
    }

    return parsed;
  }

  @override
  Future<Result<StartupConfigEntity>> bootstrap() async {
    try {
      await _remoteConfig.setConfigSettings(
        RemoteConfigSettings(fetchTimeout: const Duration(seconds: 30), minimumFetchInterval: const Duration(hours: 6)),
      );
      await _remoteConfig.setDefaults(<String, dynamic>{
        'topImageLink': globals.topImageLink,
        'bannerText': globals.bannerText,
        'bannerTextOn': globals.bannerTextOn,
        'bannerURL': globals.bannerURL,
        'latestCategories': category_data.categories.toString(),
        'currentVersion': globals.currentAppVersion,
        'obsoleteVersion': globals.obsoleteAppVersion,
        'topTitleText': globals.topTitleText.toString(),
        'premiumCollections': globals.premiumCollections.toString(),
        'verifiedUsers': globals.verifiedUsers.toString(),
        'ai_enabled': globals.aiEnabled,
        'ai_rollout_percent': globals.aiRolloutPercent,
        'ai_submit_enabled': globals.aiSubmitEnabled,
        'ai_variations_enabled': globals.aiVariationsEnabled,
      });
      await _remoteConfig.fetchAndActivate();

      final topImageLink = _remoteConfig.getString('topImageLink');
      final bannerText = _remoteConfig.getString('bannerText');
      final bannerTextOn = _remoteConfig.getString('bannerTextOn');
      final bannerUrl = _remoteConfig.getString('bannerURL');
      final obsoleteVersion = _remoteConfig.getString('obsoleteVersion');
      final verifiedUsers = _parseStringList(_remoteConfig.getString('verifiedUsers'));
      final premiumCollections = _parseStringList(_remoteConfig.getString('premiumCollections'));
      final topTitleText = _parseStringList(_remoteConfig.getString('topTitleText'));
      final aiEnabled = _remoteConfig.getBool('ai_enabled');
      final aiRolloutPercent = _remoteConfig.getInt('ai_rollout_percent').clamp(0, 100);
      final aiSubmitEnabled = _remoteConfig.getBool('ai_submit_enabled');
      final aiVariationsEnabled = _remoteConfig.getBool('ai_variations_enabled');
      topTitleText.shuffle();
      final categories = _parseCategories(_remoteConfig.getString('latestCategories'));
      categories.removeWhere((element) => element['name'] == 'Trending');

      globals.topImageLink = topImageLink;
      globals.bannerText = bannerText;
      globals.bannerTextOn = bannerTextOn;
      globals.bannerURL = bannerUrl;
      globals.obsoleteAppVersion = obsoleteVersion;
      globals.verifiedUsers = verifiedUsers;
      globals.premiumCollections = premiumCollections;
      globals.topTitleText = topTitleText;
      globals.aiEnabled = aiEnabled;
      globals.aiRolloutPercent = aiRolloutPercent;
      globals.aiSubmitEnabled = aiSubmitEnabled;
      globals.aiVariationsEnabled = aiVariationsEnabled;
      category_data.categories = categories;

      final followersTab = (_prefsBox.get('followersTab', defaultValue: true) as bool?) ?? true;
      globals.followersTab = followersTab;
      await getNotifs();

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
      );

      return Result.success(entity);
    } catch (error) {
      return Result.error(ServerFailure('Startup bootstrap failed: $error'));
    }
  }
}
