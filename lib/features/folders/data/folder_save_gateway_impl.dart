import 'dart:async';
import 'dart:io';

import 'package:Prism/analytics/analytics_service.dart';
import 'package:Prism/core/analytics/events/events.dart';
import 'package:Prism/core/coins/coin_action.dart';
import 'package:Prism/core/coins/coins_service.dart';
import 'package:Prism/core/di/injection.dart';
import 'package:Prism/core/firestore/firestore_client.dart';
import 'package:Prism/core/firestore/firestore_collections.dart';
import 'package:Prism/core/firestore/firestore_query_specs.dart';
import 'package:Prism/core/platform/pigeon/prism_media_api.g.dart';
import 'package:Prism/core/state/app_state.dart' as app_state;
import 'package:Prism/core/utils/url_utils.dart';
import 'package:Prism/core/view_stats/view_stats_repository.dart';
import 'package:Prism/core/wallpaper/original_access_service.dart';
import 'package:Prism/core/wallpaper/wallpaper_source.dart';
import 'package:Prism/features/ads/biz/coin_gate.dart';
import 'package:Prism/features/ads/biz/coin_gate_port.dart';
import 'package:Prism/features/folders/domain/entities/folder_save_plan.dart';
import 'package:Prism/features/folders/domain/entities/folder_save_run.dart';
import 'package:Prism/features/folders/domain/repositories/folder_save_gateway.dart';
import 'package:Prism/features/wallpaper_detail/data/downloaded_wall_index.dart';
import 'package:Prism/features/wallpaper_detail/domain/usecases/wallpaper_stats_usecases.dart';
import 'package:Prism/logger/logger.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:collection/collection.dart';
import 'package:injectable/injectable.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

/// How the server sees a wall doc. The same checks as `resolveOriginalAccess`, so the plan matches what it serves.
WallAccess wallAccessOf(Map<String, dynamic> data, Iterable<String> premiumCollections) {
  if (data['review'] != true || data['originalProtected'] != true) return WallAccess.removed;
  final Object? dropWeek = data['dropWeek'];
  if (data['is_streak_exclusive'] == true ||
      data['dropReserved'] == true ||
      (dropWeek != null && dropWeek != false && dropWeek != '' && dropWeek != 0)) {
    return WallAccess.protected;
  }
  final Object? collections = data['collections'];
  if (collections is! List || collections.any((value) => value is! String)) return WallAccess.removed;
  final Set<String> premium = premiumCollections.toSet();
  return collections.cast<String>().any((collection) => premium.contains(collection.trim()))
      ? WallAccess.premium
      : WallAccess.open;
}

/// The folder name as one Pictures folder name: no path characters, at most 60 characters.
String folderAlbumDirectory(String name) {
  final String cleaned = name
      .replaceAll(RegExp(r'[\x00-\x1f/\\:*?"<>|]'), ' ')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim()
      .replaceAll(RegExp(r'^\.+|\.+$'), '')
      .trim();
  final String short = cleaned.length > 60 ? cleaned.substring(0, 60).trim() : cleaned;
  return short.isEmpty ? 'Folder' : short;
}

/// The coin gate with no toasts and no ads. The plan sheet was the prompt, and the run ends with one summary.
class _QuietCoinGatePort extends AppCoinGatePort {
  _QuietCoinGatePort() : super(() => throw UnsupportedError('A folder save never shows an ad'));

  @override
  Future<void> presentLowBalancePaywall({required String source}) async {}

  @override
  void showError(String message) {}

  @override
  void showSuccess(String message) {}

  @override
  void showInfo(String message) {}
}

class _HttpStatusException implements Exception {
  const _HttpStatusException(this.statusCode);

  final int statusCode;

  bool get retryable => statusCode >= 500 || statusCode == 408 || statusCode == 429;
}

/// One at a time, so the server prices each charge after the one before it: free downloads go to the walls the plan
/// showed as free.
class _SerialLock {
  Future<void> _tail = Future<void>.value();

  Future<T> run<T>(Future<T> Function() task) {
    final Future<T> result = _tail.then((_) => task());
    _tail = result.then<void>((_) {}, onError: (Object _) {});
    return result;
  }
}

@LazySingleton(as: FolderSaveGateway)
class FolderSaveGatewayImpl implements FolderSaveGateway {
  FolderSaveGatewayImpl(this._firestore, this._index);

  static const int _whereInLimit = 30;
  static const String _sourceTag = 'folder_save';
  static const CoinGateTags _tags = CoinGateTags(
    spend: 'coins.download.folder_save.spend',
    ad: 'coins.download.folder_save.rewarded_ad',
    insufficient: 'coins.download.folder_save.insufficient_balance',
  );

  final FirestoreClient _firestore;
  final DownloadedWallIndex _index;
  final PrismMediaHostApi _media = PrismMediaHostApi();
  final CoinGate _gate = CoinGate(_QuietCoinGatePort());
  final _SerialLock _chargeLock = _SerialLock();

  @override
  String get ownerId => app_state.prismUser.loggedIn ? app_state.prismUser.id : '';

  @override
  FolderSaveAccount account() => FolderSaveAccount(
    isPro: app_state.prismUser.premium,
    premiumUnlocked: CoinsService.instance.premiumContentUnlocked,
    balance: CoinsService.instance.balanceNotifier.value,
    graceLeft: CoinsService.instance.graceDownloadsLeft,
    price: CoinSpendAction.wallpaperDownload.cost(),
  );

  @override
  Future<Map<String, WallAccess>> wallAccess(List<String> ids) async {
    final List<List<MapEntry<String, WallAccess>>> batches = await Future.wait(
      ids
          .slices(_whereInLimit)
          .map(
            (batch) => _firestore.query<MapEntry<String, WallAccess>>(
              FirestoreQuerySpec(
                collection: FirebaseCollections.walls,
                sourceTag: 'folders.save_plan',
                filters: <FirestoreFilter>[
                  const FirestoreFilter(field: 'review', op: FirestoreFilterOp.isEqualTo, value: true),
                  FirestoreFilter(field: 'id', op: FirestoreFilterOp.whereIn, value: batch),
                ],
                limit: _whereInLimit,
                cachePolicy: FirestoreCachePolicy.serverOnly,
              ),
              (data, docId) => MapEntry<String, WallAccess>(
                data['id'] is String ? data['id'] as String : docId,
                wallAccessOf(data, app_state.premiumCollections),
              ),
            ),
          ),
    );
    return Map<String, WallAccess>.fromEntries(batches.expand((batch) => batch));
  }

  @override
  Future<bool> isSaved(FolderSaveWall wall) async {
    if (!_index.hasAcquired(link: wall.identity, id: wall.id, source: wall.source)) return false;
    return await _index.localFileFor(link: wall.identity, id: wall.id, source: wall.source) != null;
  }

  @override
  Future<FolderSaveAccess> requestAccess(String album) async {
    try {
      final OperationResult result = await _media.prepareAlbumSave(_albumFor(album));
      if (result.success) return FolderSaveAccess.granted;
      return result.errorCode == 'PHOTO_PERMISSION_DENIED' ||
              result.errorCode == 'PHOTO_PERMISSION_RESTRICTED' ||
              result.errorCode == 'STORAGE_PERMISSION_REQUIRED'
          ? FolderSaveAccess.denied
          : FolderSaveAccess.failed;
    } catch (error, stackTrace) {
      logger.w('Could not ask for Photos access', error: error, stackTrace: stackTrace);
      return FolderSaveAccess.failed;
    }
  }

  @override
  Future<FolderWallOutcome> save(FolderSaveItem item, {required String album, required int maxCoins}) async {
    final String owner = ownerId;
    if (owner.isEmpty) return const FolderWallOutcome.failed(FolderSaveFailure.unknown);
    final File file = await _temporaryFile(item.wall);
    try {
      return item.wall.source == WallpaperSource.prism
          ? await _saveOriginal(item.wall, file, album: album, maxCoins: maxCoins, owner: owner)
          : await _saveOpen(item.wall, file, album: album, maxCoins: maxCoins, owner: owner);
    } finally {
      await _delete(file);
    }
  }

  @override
  Future<void> clearTemporaryFiles() async {
    try {
      final Directory directory = await _temporaryDirectory();
      if (directory.existsSync()) await directory.delete(recursive: true);
    } catch (error, stackTrace) {
      logger.w('Could not clear folder save files', error: error, stackTrace: stackTrace);
    }
  }

  /// A Prism wall. The server charges when it grants the link, so a wall that is not saved after that keeps its grant
  /// for 5 minutes and a retry in that time is free.
  Future<FolderWallOutcome> _saveOriginal(
    FolderSaveWall wall,
    File file, {
    required String album,
    required int maxCoins,
    required String owner,
  }) async {
    FolderSaveFailure? failure;
    String? granted;
    final CoinGateResult result = await _gate.run(
      _spec(
        wall,
        owner: owner,
        premiumBypass: false,
        refundOnFailure: false,
        spend: (_) => _chargeLock.run(() async {
          final int before = CoinsService.instance.balanceNotifier.value;
          try {
            granted = await OriginalAccessService.instance.resolve(
              url: wall.link,
              wallpaperId: wall.id,
              wallpaperSource: WallpaperSource.prism,
              action: OriginalAccessAction.download,
              maxCoins: maxCoins,
            );
          } on OriginalAccessInsufficientBalance catch (error) {
            failure = error.requiredCoins > maxCoins
                ? FolderSaveFailure.priceChanged
                : FolderSaveFailure.notEnoughCoins;
            return CoinMutationResult(
              success: false,
              changed: false,
              previousBalance: error.currentBalance,
              currentBalance: error.currentBalance,
              delta: 0,
              insufficientBalance: true,
            );
          } on FirebaseFunctionsException catch (error) {
            failure = const <String>{'unavailable', 'deadline-exceeded', 'internal'}.contains(error.code)
                ? FolderSaveFailure.network
                : FolderSaveFailure.unavailable;
            rethrow;
          }
          final int after = CoinsService.instance.balanceNotifier.value;
          return CoinMutationResult(
            success: true,
            changed: false,
            previousBalance: before,
            currentBalance: after,
            delta: after - before,
          );
        }),
        perform: () async {
          failure = await _download(granted!, file);
          if (failure != null) return false;
          failure = await _store(wall, file, album: album, owner: owner);
          if (failure != null) return false;
          await OriginalAccessService.instance.complete(
            owner: owner,
            wallpaperId: OriginalAccessService.grantKey(wall.id),
            action: OriginalAccessAction.download,
          );
          return true;
        },
      ),
    );
    return _outcome(result, failure);
  }

  /// A Wallhaven or Pexels wall. It downloads before the charge, so a download that fails costs nothing. A save that
  /// fails after the charge is refunded by the gate.
  Future<FolderWallOutcome> _saveOpen(
    FolderSaveWall wall,
    File file, {
    required String album,
    required int maxCoins,
    required String owner,
  }) async {
    final FolderSaveFailure? downloadFailure = await _download(wall.link, file);
    if (downloadFailure != null) return FolderWallOutcome.failed(downloadFailure);
    FolderSaveFailure? failure;
    String? paidTxId;
    final bool pro = app_state.prismUser.premium;
    final CoinGateResult result = await _gate.run(
      _spec(
        wall,
        owner: owner,
        premiumBypass: true,
        refundOnFailure: true,
        onPaid: (txId) => paidTxId = txId,
        spend: pro
            ? null
            : (tag) => _chargeLock.run(() async {
                final int balance = CoinsService.instance.balanceNotifier.value;
                final bool free = CoinsService.instance.graceDownloadsLeft > 0;
                if (!free && CoinSpendAction.wallpaperDownload.cost() > maxCoins) {
                  failure = FolderSaveFailure.priceChanged;
                  return CoinMutationResult(
                    success: false,
                    changed: false,
                    previousBalance: balance,
                    currentBalance: balance,
                    delta: 0,
                    insufficientBalance: true,
                  );
                }
                final CoinMutationResult spent = await CoinsService.instance.spend(
                  CoinSpendAction.wallpaperDownload,
                  sourceTag: tag,
                  reason: 'content_${wall.id}',
                  label: _label(wall),
                  pendingDownloadLink: wall.identity,
                );
                if (spent.insufficientBalance) failure = FolderSaveFailure.notEnoughCoins;
                return spent;
              }),
        perform: () async {
          failure = await _store(wall, file, album: album, owner: owner);
          if (failure != null) return false;
          final String? txId = paidTxId;
          if (txId != null) await CoinsService.instance.markPendingDownloadSaved(txId);
          return true;
        },
      ),
    );
    return _outcome(result, failure);
  }

  CoinGateSpec _spec(
    FolderSaveWall wall, {
    required String owner,
    required bool premiumBypass,
    required bool refundOnFailure,
    required Future<bool> Function() perform,
    Future<CoinMutationResult> Function(String sourceTag)? spend,
    void Function(String txId)? onPaid,
  }) => CoinGateSpec(
    action: CoinSpendAction.wallpaperDownload,
    tags: _tags,
    upsellSource: _sourceTag,
    upgradeSource: _sourceTag,
    perform: perform,
    spend: spend,
    choose: (_) async => CoinGateChoice.cancel,
    isMounted: () => ownerId == owner,
    reason: 'content_${wall.id}',
    label: _label(wall),
    pendingDownloadLink: wall.identity,
    premiumBypass: premiumBypass,
    refundOnFailure: refundOnFailure,
    onPaid: onPaid,
  );

  FolderWallOutcome _outcome(CoinGateResult result, FolderSaveFailure? failure) => switch (result) {
    CoinGateResult.performed || CoinGateResult.performedFree => const FolderWallOutcome.saved(),
    CoinGateResult.insufficient ||
    CoinGateResult.cancelled => FolderWallOutcome.failed(failure ?? FolderSaveFailure.notEnoughCoins),
    CoinGateResult.spendFailed ||
    CoinGateResult.failedRefunded ||
    CoinGateResult.failedNotRefunded => FolderWallOutcome.failed(failure ?? FolderSaveFailure.unknown),
  };

  /// Saves the downloaded file into Downloads and the album, and records it like the Save pill does.
  Future<FolderSaveFailure?> _store(
    FolderSaveWall wall,
    File file, {
    required String album,
    required String owner,
  }) async {
    if (ownerId != owner) return FolderSaveFailure.unknown;
    final OperationResult result;
    try {
      result = await _media.enqueueDownload(
        DownloadRequest(
          link: file.path,
          filenameWithoutExtension: downloadBaseName(wall.identity),
          isLocalFile: true,
          album: _albumFor(album),
        ),
      );
    } catch (error, stackTrace) {
      logger.w('A folder wall could not be stored', error: error, stackTrace: stackTrace);
      return FolderSaveFailure.storage;
    }
    if (!result.success) return FolderSaveFailure.storage;
    await _index.remember(link: wall.identity, id: wall.id, source: wall.source, ownerId: owner);
    try {
      unawaited(
        analytics.track(
          DownloadWallpaperEvent(
            link: wall.link,
            sourceContext: _sourceTag,
            premiumContent: false,
            itemId: wall.id,
            provider: wall.source.name,
            source: _sourceTag,
          ),
        ),
      );
    } catch (error, stackTrace) {
      logger.w('Folder save analytics failed', error: error, stackTrace: stackTrace);
    }
    if (wall.source == WallpaperSource.prism && getIt.isRegistered<RecordWallpaperActionUseCase>()) {
      unawaited(
        getIt<RecordWallpaperActionUseCase>()(wall.id, WallpaperAction.download).catchError((Object error) {
          logger.w('Folder save action record failed', error: error);
          throw error;
        }),
      );
    }
    return null;
  }

  /// Streams [url] into [file]. Tries twice when the network or the server fails.
  Future<FolderSaveFailure?> _download(String url, File file) async {
    final Uri? uri = Uri.tryParse(url);
    if (uri == null || (uri.scheme != 'https' && uri.scheme != 'http') || uri.host.isEmpty) {
      return FolderSaveFailure.unavailable;
    }
    for (int attempt = 0; attempt < 2; attempt++) {
      final HttpClient client = HttpClient()..connectionTimeout = const Duration(seconds: 15);
      try {
        final HttpClientRequest request = await client.getUrl(uri);
        final HttpClientResponse response = await request.close().timeout(const Duration(seconds: 30));
        if (response.statusCode != HttpStatus.ok) {
          await response.drain<void>();
          throw _HttpStatusException(response.statusCode);
        }
        await response.timeout(const Duration(seconds: 30)).pipe(file.openWrite());
        return null;
      } on _HttpStatusException catch (error) {
        if (!error.retryable) return FolderSaveFailure.unavailable;
      } on SocketException catch (_) {
      } on HttpException catch (_) {
      } on TimeoutException catch (_) {
      } on HandshakeException catch (_) {
      } finally {
        client.close(force: true);
      }
    }
    return FolderSaveFailure.network;
  }

  String _albumFor(String name) => Platform.isAndroid ? folderAlbumDirectory(name) : name.trim();

  String? _label(FolderSaveWall wall) {
    final String label = wall.label?.trim() ?? '';
    return label.isEmpty ? null : label;
  }

  Future<Directory> _temporaryDirectory() async =>
      Directory(p.join((await getTemporaryDirectory()).path, 'folder_save'));

  Future<File> _temporaryFile(FolderSaveWall wall) async {
    final Directory directory = await _temporaryDirectory();
    await directory.create(recursive: true);
    final String name = '${wall.source.name}-${wall.id}'.replaceAll(RegExp('[^A-Za-z0-9_-]'), '_');
    return File(p.join(directory.path, '$name-${DateTime.now().microsecondsSinceEpoch}.img'));
  }

  Future<void> _delete(File file) async {
    try {
      if (file.existsSync()) await file.delete();
    } catch (error, stackTrace) {
      logger.w('Could not delete a folder save file', error: error, stackTrace: stackTrace);
    }
  }
}
