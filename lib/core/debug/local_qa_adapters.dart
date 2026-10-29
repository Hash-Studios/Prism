import 'dart:io';

import 'package:Prism/core/network/connectivity_service.dart';
import 'package:Prism/core/persistence/local_store.dart';
import 'package:Prism/core/persistence/store_adapters/shared_prefs_store_adapter.dart';
import 'package:Prism/core/utils/result.dart';
import 'package:Prism/core/wallpaper/wallpaper_variants.dart';
import 'package:Prism/data/notifications/notifications.dart';
import 'package:Prism/features/ads/domain/entities/ads_entity.dart';
import 'package:Prism/features/ads/domain/repositories/ads_repository.dart';
import 'package:Prism/features/pexels_feed/domain/repositories/pexels_wallpaper_repository.dart';
import 'package:Prism/features/startup/domain/entities/startup_config_entity.dart';
import 'package:Prism/features/startup/domain/repositories/startup_repository.dart';
import 'package:Prism/features/wallhaven_feed/domain/repositories/wallhaven_wallpaper_repository.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

// All reads, writes, migrations and clears stay in the QA identity's namespace.
class LocalQaStore implements LocalStore {
  LocalQaStore(String identity) : _prefix = 'local_qa.demo-prism.$identity.';
  final String _prefix;
  final LocalStore _delegate = SharedPrefsStoreAdapter();
  @override
  Future<void> init() => _delegate.init();
  @override
  bool get isReady => _delegate.isReady;
  @override
  Object? get(String key) => _delegate.get('$_prefix$key');
  @override
  Future<void> set(String key, Object? value) => _delegate.set('$_prefix$key', value);
  @override
  Future<void> delete(String key) => _delegate.delete('$_prefix$key');
  @override
  Future<List<String>> keys() async => (await _delegate.keys())
      .where((key) => key.startsWith(_prefix))
      .map((key) => key.substring(_prefix.length))
      .toList();
  @override
  Future<void> clearPrefix(String prefix) => _delegate.clearPrefix('$_prefix$prefix');
  @override
  Future<void> clearAll() => clearPrefix('');
}

class LocalQaConnectivity implements ConnectivityService {
  @override
  Future<bool> hasConnection() async {
    final client = HttpClient();
    try {
      final request = await client.getUrl(Uri.parse('https://localhost:19375/health'));
      final response = await request.close().timeout(const Duration(seconds: 2));
      await response.drain<void>();
      return response.statusCode == 200;
    } catch (_) {
      return false;
    } finally {
      client.close(force: true);
    }
  }

  @override
  Stream<bool> get onConnectionChange =>
      Stream<int>.periodic(const Duration(seconds: 20), (tick) => tick).asyncMap((_) => hasConnection());
}

class LocalQaAds implements AdsRepository {
  static final _disabled = Result.success(
    AdsEntity.empty.copyWith(adFailed: true, failureReason: AdFailureReason.consent),
  );
  @override
  Future<Result<AdsEntity>> createRewardedAd() async => _disabled;
  @override
  Future<Result<AdsEntity>> showRewardedAd() async => _disabled;
}

class LocalQaPexels implements PexelsWallpaperRepository {
  @override
  Future<Result<List<PexelsWallpaper>>> fetchFeed({
    required String categoryName,
    required bool refresh,
    int startPage = 1,
    String? paginationKey,
    bool portraitOnly = true,
    String? color,
  }) async => Result.success(const <PexelsWallpaper>[]);
  @override
  Future<Result<PexelsWallpaper?>> fetchById(String id) async => Result.success<PexelsWallpaper?>(null);
  @override
  bool hasMoreForCategory(String categoryName, {String? paginationKey}) => false;
}

class LocalQaWallhaven implements WallhavenWallpaperRepository {
  @override
  Future<Result<List<WallhavenWallpaper>>> fetchFeed({
    required String categoryName,
    required bool refresh,
    int categories = 100,
    int purity = 100,
    int startPage = 1,
    String? paginationKey,
    bool portraitOnly = true,
    String? minResolution,
    String? sorting,
    String? colors,
  }) async => Result.success(const <WallhavenWallpaper>[]);
  @override
  Future<Result<List<WallhavenWallpaper>>> fetchToplist({int page = 1}) async =>
      Result.success(const <WallhavenWallpaper>[]);
  @override
  Future<Result<WallhavenWallpaper?>> fetchById(String id) async => Result.success<WallhavenWallpaper?>(null);
  @override
  bool hasMoreForCategory(String categoryName, {String? paginationKey}) => false;
}

class LocalQaStartup implements StartupRepository {
  @override
  final StartupConfigEntity currentConfig = const StartupConfigEntity(
    topImageLink: 'https://localhost:19375/wallpaper.jpg',
    bannerText: '',
    bannerTextOn: false,
    bannerUrl: '',
    obsoleteAppVersion: '0.0.0',
    verifiedUsers: <String>[],
    premiumCollections: <String>[],
    aiEnabled: true,
    aiRolloutPercent: 100,
    aiSubmitEnabled: true,
    aiVariationsEnabled: false,
    useRcPaywalls: false,
    onboardingV2Enabled: true,
  );
  @override
  Future<Result<StartupConfigEntity>> bootstrap() async {
    await syncInAppNotificationsFromRemote();
    return Result.success(currentConfig);
  }
}

// Home also starts FCM directly. Reject its native calls through Flutter's messenger seam.
// No fake token, permission, subscription, purchase or generation success is returned.
class LocalQaWidgetsBinding extends WidgetsFlutterBinding {
  @override
  BinaryMessenger createBinaryMessenger() => _LocalQaMessenger(super.createBinaryMessenger());
}

class _LocalQaMessenger implements BinaryMessenger {
  _LocalQaMessenger(this._delegate);
  final BinaryMessenger _delegate;
  static const _blocked = <String>[
    'plugins.flutter.io/firebase_messaging',
    'plugins.flutter.io/firebase_analytics',
    'plugins.flutter.io/firebase_remote_config',
    'plugins.flutter.io/google_mobile_ads',
    'purchases_flutter',
    'mixpanel_flutter',
    'sentry_flutter',
  ];
  @override
  Future<ByteData?>? send(String channel, ByteData? message) {
    if (_blocked.any(channel.startsWith)) {
      return Future<ByteData?>.value(
        const StandardMethodCodec().encodeErrorEnvelope(
          code: 'local-qa-disabled',
          message: 'This native service is disabled in local QA.',
        ),
      );
    }
    return _delegate.send(channel, message);
  }

  @override
  void setMessageHandler(String channel, MessageHandler? handler) => _delegate.setMessageHandler(channel, handler);
  @override
  Future<void> handlePlatformMessage(String channel, ByteData? data, PlatformMessageResponseCallback? callback) async {
    ServicesBinding.instance.channelBuffers.push(channel, data, callback ?? (_) {});
  }
}
