import 'package:Prism/core/analytics/analytics_correlation.dart';
import 'package:Prism/core/coins/coins_service.dart';
import 'package:Prism/core/constants/app_functions.dart';
import 'package:Prism/core/di/injection.dart';
import 'package:Prism/core/persistence/data_sources/settings_local_data_source.dart';
import 'package:Prism/core/state/app_state.dart' as app_state;
import 'package:Prism/core/wallpaper/wallpaper_source.dart';
import 'package:Prism/data/offline/bundled_wallpapers.dart';
import 'package:Prism/features/wallpaper_detail/data/downloaded_wall_index.dart';
import 'package:cloud_functions/cloud_functions.dart';

enum OriginalAccessAction { download, set, edit, live }

class OriginalAccessInsufficientBalance implements Exception {
  const OriginalAccessInsufficientBalance(this.requiredCoins, this.currentBalance);
  final int requiredCoins;
  final int currentBalance;
}

class OriginalAccessQuote {
  const OriginalAccessQuote(this.requiredCoins, this.currentBalance);
  final int requiredCoins;
  final int currentBalance;
}

class OriginalAccessService {
  OriginalAccessService({
    Future<Map<String, dynamic>> Function(Map<String, dynamic>)? call,
    String Function()? owner,
    DateTime Function()? now,
  }) : _call = call ?? _resolve,
       _owner = owner ?? (() => app_state.prismUser.id),
       _now = now ?? DateTime.now;

  static final OriginalAccessService instance = OriginalAccessService();
  final Future<Map<String, dynamic>> Function(Map<String, dynamic>) _call;
  final String Function() _owner;
  final DateTime Function() _now;
  String get ownerId => _owner();
  final Map<String, String> _pending = {};
  final Map<String, int> _pendingUntil = {};

  SettingsLocalDataSource? get _settings =>
      getIt.isRegistered<SettingsLocalDataSource>() ? getIt<SettingsLocalDataSource>() : null;

  String _key(String owner, String id, OriginalAccessAction action) => 'originalAccess.$owner.$id.${action.name}';

  Future<String?> _acquiredLocal(String id) async {
    if (!getIt.isRegistered<DownloadedWallIndex>()) return null;
    final owner = _owner();
    final file = await getIt<DownloadedWallIndex>().localFileForIdentity(id: id, source: WallpaperSource.prism);
    if (_owner() != owner) throw StateError('Original access unavailable');
    return file?.path;
  }

  Future<Map<String, dynamic>> _callForOperation(
    Map<String, dynamic> input,
    String owner,
    String id,
    OriginalAccessAction action,
  ) async {
    try {
      return await _call(input);
    } on FirebaseFunctionsException catch (error) {
      if (const {
        'invalid-argument',
        'unauthenticated',
        'permission-denied',
        'not-found',
        'failed-precondition',
      }.contains(error.code)) {
        await complete(owner: owner, wallpaperId: id, action: action);
      }
      rethrow;
    }
  }

  Future<String> _requestId(
    String owner,
    String id,
    OriginalAccessAction action,
    String? preferred, {
    bool acquire = true,
  }) async {
    final key = _key(owner, id, action);
    final settings = _settings;
    final stored = settings?.get<String?>(key, hasDefault: true);
    final until = _pendingUntil[key] ?? settings?.get<int?>('$key.until', hasDefault: true);
    if (until != null && until <= _now().millisecondsSinceEpoch) {
      await complete(owner: owner, wallpaperId: id, action: action);
      if (acquire) throw StateError('Previous original access attempt expired. Please try again.');
      return _requestId(owner, id, action, null, acquire: false);
    }
    final value = _pending[key] ?? stored ?? preferred ?? AnalyticsCorrelation.newId();
    final deadline = until ?? (acquire ? _now().add(const Duration(minutes: 5)).millisecondsSinceEpoch : null);
    _pending[key] = value;
    if (deadline != null) _pendingUntil[key] = deadline;
    if (settings != null) {
      await settings.set(key, value);
      if (deadline != null) await settings.set('$key.until', deadline);
    }
    return value;
  }

  Future<void> complete({String? owner, required String wallpaperId, required OriginalAccessAction action}) async {
    final key = _key(owner ?? _owner(), wallpaperId, action);
    _pending.remove(key);
    _pendingUntil.remove(key);
    await _settings?.delete(key);
    await _settings?.delete('$key.until');
  }

  Future<OriginalAccessQuote> quote({required String wallpaperId, required OriginalAccessAction action}) async {
    final owner = _owner();
    if (await _acquiredLocal(wallpaperId) != null) return OriginalAccessQuote(0, app_state.prismUser.coins);
    final requestId = await _requestId(owner, wallpaperId, action, null, acquire: false);
    if (_owner() != owner) throw StateError('Original access unavailable');
    final reply = await _callForOperation(
      {'assetId': wallpaperId, 'action': action.name, 'requestId': requestId, 'mode': 'quote'},
      owner,
      wallpaperId,
      action,
    );
    if (_owner() != owner ||
        reply['status'] != 'quoted' ||
        reply['requiredCoins'] is! num ||
        reply['currentBalance'] is! num) {
      throw StateError('Original access unavailable');
    }
    return OriginalAccessQuote((reply['requiredCoins'] as num).toInt(), (reply['currentBalance'] as num).toInt());
  }

  String _pairId(List<String> ids) => 'pair:${ids.join(',')}';

  Future<OriginalAccessQuote> quotePair(List<String> assetIds) async {
    final owner = _owner();
    final remoteIds = <String>[];
    for (final id in assetIds) {
      if (await _acquiredLocal(id) == null) remoteIds.add(id);
      if (_owner() != owner) throw StateError('Original access unavailable');
    }
    assetIds = remoteIds;
    if (assetIds.isEmpty) return OriginalAccessQuote(0, app_state.prismUser.coins);
    if (assetIds.length == 1) return quote(wallpaperId: assetIds.single, action: OriginalAccessAction.set);
    final requestId = await _requestId(owner, _pairId(assetIds), OriginalAccessAction.set, null, acquire: false);
    if (owner != _owner()) throw StateError('Original access unavailable');
    final reply = await _callForOperation(
      {
        'assets': [
          for (final id in assetIds) {'assetId': id, 'action': 'set'},
        ],
        'mode': 'quote',
        'requestId': requestId,
      },
      owner,
      _pairId(assetIds),
      OriginalAccessAction.set,
    );
    if (owner != _owner() ||
        reply['status'] != 'quoted' ||
        reply['requiredCoins'] is! num ||
        reply['currentBalance'] is! num) {
      throw StateError('Original access unavailable');
    }
    return OriginalAccessQuote((reply['requiredCoins'] as num).toInt(), (reply['currentBalance'] as num).toInt());
  }

  Future<Map<String, String>> resolvePair(List<String> assetIds, {required int maxCoins}) async {
    final owner = _owner();
    final local = <String, String>{};
    final remoteIds = <String>[];
    for (final id in assetIds) {
      final path = await _acquiredLocal(id);
      if (_owner() != owner) throw StateError('Original access unavailable');
      if (path == null) {
        remoteIds.add(id);
      } else {
        local[id] = path;
      }
    }
    assetIds = remoteIds;
    if (assetIds.isEmpty) return local;
    if (assetIds.length == 1) {
      return {
        ...local,
        assetIds.single: await resolve(
          url: '',
          wallpaperId: assetIds.single,
          wallpaperSource: WallpaperSource.prism,
          action: OriginalAccessAction.set,
          maxCoins: maxCoins,
        ),
      };
    }
    final requestId = await _requestId(owner, _pairId(assetIds), OriginalAccessAction.set, null);
    if (owner != _owner()) throw StateError('Original access unavailable');
    final reply = await _callForOperation(
      {
        'assets': [
          for (final id in assetIds) {'assetId': id, 'action': 'set'},
        ],
        'requestId': requestId,
        'maxCoins': maxCoins,
      },
      owner,
      _pairId(assetIds),
      OriginalAccessAction.set,
    );
    if (owner != _owner()) throw StateError('Original access unavailable');
    if (reply['status'] == 'insufficient_balance' || reply['status'] == 'price_changed') {
      await completePair(assetIds, owner: owner);
      throw OriginalAccessInsufficientBalance(
        (reply['requiredCoins'] as num).toInt(),
        (reply['currentBalance'] as num).toInt(),
      );
    }
    final grants = reply['grants'];
    final balance = _grantBalance(reply);
    if (reply['status'] != 'granted' || grants is! List || grants.length != assetIds.length) {
      throw StateError('Original access unavailable');
    }
    final result = <String, String>{};
    for (final grant in grants) {
      if (grant is! Map ||
          !assetIds.contains(grant['assetId']) ||
          grant['url'] is! String ||
          grant['expiresAt'] is! num ||
          (grant['expiresAt'] as num) <= _now().millisecondsSinceEpoch) {
        throw StateError('Original access unavailable');
      }
      final uri = Uri.tryParse(grant['url'] as String);
      if (uri == null || uri.scheme != 'https' || uri.host.isEmpty) throw StateError('Original access unavailable');
      result[grant['assetId'] as String] = grant['url'] as String;
    }
    if (result.length != assetIds.length) throw StateError('Original access unavailable');
    CoinsService.instance.applyServerBalance(balance, ownerId: owner);
    return {...local, ...result};
  }

  int _grantBalance(Map<String, dynamic> reply) {
    final balance = reply['currentBalance'];
    if (balance is! num || !balance.isFinite || balance < 0 || balance != balance.truncate()) {
      throw StateError('Original access unavailable');
    }
    return balance.toInt();
  }

  Future<void> completePair(List<String> assetIds, {String? owner}) async {
    for (final id in {...assetIds, if (assetIds.length > 1) _pairId(assetIds)}) {
      await complete(owner: owner, wallpaperId: id, action: OriginalAccessAction.set);
    }
  }

  static Future<Map<String, dynamic>> _resolve(Map<String, dynamic> input) async {
    final result = await appFunctions.httpsCallable('resolveOriginalAccess').call<Map<String, dynamic>>(input);
    return result.data;
  }

  /// True when [url] is the full url `unlockDrop` gave this account for Prism Drop wall [id]. That wall stays
  /// unreviewed and unprotected until its Drop is released, so neither the canonical lookup nor a grant can serve it.
  static bool isUnlockedDropUrl(String url, String? id, WallpaperSource? source) =>
      source == WallpaperSource.prism &&
      id != null &&
      url.isNotEmpty &&
      CoinsService.instance.currentDropUnlocks[id]?.url == url;

  static bool requiresGrant(String url, String? id, WallpaperSource? source) =>
      source == WallpaperSource.prism &&
      !(id != null && BundledWallpapers.isStarterIdentity(id, source!)) &&
      !isUnlockedDropUrl(url, id, source);

  Future<String> resolve({
    required String url,
    required String? wallpaperId,
    required WallpaperSource? wallpaperSource,
    required OriginalAccessAction action,
    String? requestId,
    int? maxCoins,
  }) async {
    final scheme = Uri.tryParse(url.trim())?.scheme.toLowerCase();
    if ((wallpaperSource == null ||
            wallpaperSource == WallpaperSource.unknown ||
            wallpaperSource == WallpaperSource.downloaded) &&
        (scheme == 'https' || scheme == 'http')) {
      throw StateError('Wallpaper source unavailable');
    }
    if (!requiresGrant(url, wallpaperId, wallpaperSource)) return url;
    final owner = _owner();
    if (owner.isEmpty || wallpaperId == null || wallpaperId.trim().isEmpty) {
      throw StateError('Original access unavailable');
    }
    final local = await _acquiredLocal(wallpaperId);
    if (local != null) return local;
    final stableRequestId = await _requestId(owner, wallpaperId, action, requestId);
    if (_owner() != owner) throw StateError('Original access unavailable');
    final reply = await _callForOperation(
      {
        'assetId': wallpaperId,
        'action': action.name,
        'requestId': stableRequestId,
        if (maxCoins != null) 'maxCoins': maxCoins,
      },
      owner,
      wallpaperId,
      action,
    );
    if (_owner() != owner) throw StateError('Original access unavailable');
    if (reply['status'] == 'insufficient_balance' || reply['status'] == 'price_changed') {
      await complete(owner: owner, wallpaperId: wallpaperId, action: action);
      throw OriginalAccessInsufficientBalance(
        (reply['requiredCoins'] as num).toInt(),
        (reply['currentBalance'] as num).toInt(),
      );
    }
    final grantedUrl = reply['url'];
    final balance = _grantBalance(reply);
    final expiresAt = reply['expiresAt'];
    final uri = grantedUrl is String ? Uri.tryParse(grantedUrl) : null;
    if (_owner() != owner ||
        reply['status'] != 'granted' ||
        uri == null ||
        uri.scheme != 'https' ||
        uri.host.isEmpty ||
        expiresAt is! num ||
        expiresAt <= _now().millisecondsSinceEpoch) {
      throw StateError('Original access unavailable');
    }
    CoinsService.instance.applyServerBalance(balance, ownerId: owner);
    return grantedUrl as String;
  }
}
