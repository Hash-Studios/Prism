import 'dart:convert';

import 'package:Prism/core/constants/app_constants.dart';
import 'package:Prism/core/persistence/data_sources/settings_local_data_source.dart';
import 'package:Prism/core/wallpaper/wallpaper_source.dart';
import 'package:firebase_remote_config/firebase_remote_config.dart';

class PersonalizedInterest {
  const PersonalizedInterest({required this.name, required this.query, required this.imageUrl, required this.sources});

  final String name;
  final String query;
  final String imageUrl;
  final List<WallpaperSource> sources;

  bool supports(WallpaperSource source) => sources.contains(source);
}

class PersonalizedInterestsCatalog {
  const PersonalizedInterestsCatalog._();

  static Future<List<PersonalizedInterest>> load({
    required FirebaseRemoteConfig remoteConfig,
    required SettingsLocalDataSource settingsLocal,
  }) async {
    final remoteRaw = remoteConfig.getString(personalizedInterestsRemoteConfigKey).trim();
    final remote = _decode(remoteRaw);
    if (remote.isNotEmpty) {
      await settingsLocal.set(personalizedInterestsLocalCacheKey, remoteRaw);
      return remote;
    }

    final cachedRaw = settingsLocal.get<String>(personalizedInterestsLocalCacheKey, defaultValue: '').trim();
    final cached = _decode(cachedRaw);
    if (cached.isNotEmpty) {
      return cached;
    }

    return _decode(defaultPersonalizedInterestsJson);
  }

  static List<String> selectedFromLocal(SettingsLocalDataSource settingsLocal) {
    final raw = settingsLocal.get<String>('onboarding_v2_interests', defaultValue: '');
    return raw.split(',').map((e) => e.trim()).where((e) => e.isNotEmpty).toSet().toList(growable: false);
  }

  static List<String> defaultSelection(List<PersonalizedInterest> catalog) {
    if (catalog.isEmpty) {
      return const <String>['Nature', 'Abstract', 'Architecture', 'Minimal'];
    }
    return catalog.take(4).map((e) => e.name).toList(growable: false);
  }

  static List<PersonalizedInterest> _decode(String raw) {
    if (raw.isEmpty) {
      return const <PersonalizedInterest>[];
    }
    try {
      final decoded = json.decode(raw);
      if (decoded is! List) {
        return const <PersonalizedInterest>[];
      }
      final out = <PersonalizedInterest>[];
      for (final item in decoded) {
        if (item is! Map) {
          continue;
        }
        final map = item.map((key, value) => MapEntry(key.toString(), value));
        final name = map['name']?.toString().trim() ?? '';
        final query = (map['query']?.toString().trim() ?? name).trim();
        final imageUrl = map['imageUrl']?.toString().trim() ?? '';
        final sourceValues =
            (map['sources'] as List?)?.map((e) => e?.toString() ?? '').toList(growable: false) ?? const <String>[];
        if (name.isEmpty || query.isEmpty || imageUrl.isEmpty) {
          continue;
        }
        final sources = sourceValues
            .map(WallpaperSourceX.fromWire)
            .where((source) => source == WallpaperSource.wallhaven || source == WallpaperSource.pexels)
            .toSet()
            .toList(growable: false);
        out.add(
          PersonalizedInterest(
            name: name,
            query: query,
            imageUrl: imageUrl,
            sources: sources.isEmpty
                ? const <WallpaperSource>[WallpaperSource.wallhaven, WallpaperSource.pexels]
                : sources,
          ),
        );
      }
      return out;
    } catch (_) {
      return const <PersonalizedInterest>[];
    }
  }
}
