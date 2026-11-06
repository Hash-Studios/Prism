import 'dart:async';
import 'dart:io';

import 'package:Prism/core/coins/coins_service.dart';
import 'package:Prism/core/coins/pending_download.dart';
import 'package:Prism/core/di/injection.dart';
import 'package:Prism/core/persistence/data_sources/settings_local_data_source.dart';
import 'package:Prism/core/platform/pigeon/prism_media_api.g.dart';
import 'package:Prism/core/state/app_state.dart' as app_state;
import 'package:Prism/core/utils/result.dart';
import 'package:Prism/core/view_stats/view_stats_repository.dart';
import 'package:Prism/core/wallpaper/wallpaper_source.dart';
import 'package:Prism/features/ads/data/ad_consent.dart';
import 'package:Prism/features/folders/data/folder_save_gateway_impl.dart';
import 'package:Prism/features/folders/domain/entities/folder_save_plan.dart';
import 'package:Prism/features/folders/domain/entities/folder_save_run.dart';
import 'package:Prism/features/wallpaper_detail/data/downloaded_wall_index.dart';
import 'package:Prism/features/wallpaper_detail/domain/usecases/wallpaper_stats_usecases.dart';
import 'package:cloud_functions/cloud_functions.dart' show FirebaseFunctionsException;
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../support/coins_test_backend.dart';
import '../../../support/in_memory_local_store.dart';

class _FailingSettings extends SettingsLocalDataSource {
  _FailingSettings(super.store);
  @override
  Future<void> set(String key, Object? value) {
    if (key == 'pendingDownloads_v2') throw StateError('ledger unavailable');
    return super.set(key, value);
  }
}

class _Index extends DownloadedWallIndex {
  _Index(super.settingsLocal);
  Future<void> Function()? onRemember;
  File? acquired;

  @override
  Future<File?> localFileForIdentity({required String id, required WallpaperSource source}) async => acquired;

  @override
  Future<void> remember({
    required String link,
    required String id,
    required WallpaperSource source,
    String? ownerId,
    bool original = true,
  }) async => onRemember?.call();
}

class _Http extends HttpOverrides {
  int requests = 0;
  int status = HttpStatus.ok;
  Stream<List<int>> Function(int)? body;
  @override
  HttpClient createHttpClient(SecurityContext? context) => _Client(this);
}

class _Client extends Fake implements HttpClient {
  _Client(this.http);
  final _Http http;
  @override
  set connectionTimeout(Duration? value) {}
  @override
  Future<HttpClientRequest> getUrl(Uri url) async => _Request(http);
  @override
  void close({bool force = false}) {}
}

class _Request extends Fake implements HttpClientRequest {
  _Request(this.http);
  final _Http http;
  @override
  Future<HttpClientResponse> close() async {
    final int request = ++http.requests;
    return _Response(http.body?.call(request) ?? Stream<List<int>>.value(<int>[1, 2, 3]), http.status);
  }
}

class _Response extends Stream<List<int>> implements HttpClientResponse {
  _Response(this.body, this.statusCode);
  final Stream<List<int>> body;
  @override
  final int statusCode;
  @override
  StreamSubscription<List<int>> listen(
    void Function(List<int>)? onData, {
    Function? onError,
    void Function()? onDone,
    bool? cancelOnError,
  }) => body.listen(onData, onError: onError, onDone: onDone, cancelOnError: cancelOnError);
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Sink extends Fake implements IOSink {
  _Sink(this.sink, {this.onClosed});
  final IOSink sink;
  final void Function()? onClosed;
  bool closed = false;
  @override
  Future<void> addStream(Stream<List<int>> stream) => sink.addStream(stream);
  @override
  Future<void> close() async {
    closed = true;
    await sink.close();
    onClosed?.call();
  }
}

class _Stats extends Fake implements ViewStatsRepository {
  @override
  Future<Result<WallpaperActionReceipt>> recordWallpaperAction(String id, WallpaperAction action) async =>
      throw StateError('stats unavailable');
}

FolderSaveItem _open(String id) => FolderSaveItem(
  wall: FolderSaveWall(id: id, source: WallpaperSource.wallhaven, link: 'https://wall.test/$id.jpg'),
  kind: FolderSaveKind.coins,
  cost: 10,
);

FolderSaveItem _original(String id) => FolderSaveItem(
  wall: FolderSaveWall(id: id, source: WallpaperSource.prism),
  kind: FolderSaveKind.coins,
  cost: 10,
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final CoinsTestBackend backend = CoinsTestBackend();
  late Directory temporary;
  late _Http http;
  late _Index index;
  late FolderSaveGatewayImpl gateway;
  late HttpOverrides? oldHttp;
  late List<String> calls;
  late List<List<int>> storedFiles;
  Future<OperationResult> Function()? saveNative;

  void channel(String method, Future<Object?> Function(Object?) handle) {
    final BasicMessageChannel<Object?> message = BasicMessageChannel<Object?>(
      'dev.flutter.pigeon.Prism.PrismMediaHostApi.$method',
      PrismMediaHostApi.pigeonChannelCodec,
    );
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockDecodedMessageHandler<Object?>(
      message,
      handle,
    );
    addTearDown(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockDecodedMessageHandler<Object?>(
        message,
        null,
      );
    });
  }

  setUp(() async {
    await backend.install();
    CoinsService.instance.balanceNotifier.value = 100;
    temporary = await Directory.systemTemp.createTemp('folder-gateway-test-');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
      const MethodChannel('plugins.flutter.io/path_provider'),
      (call) async => temporary.path,
    );
    oldHttp = HttpOverrides.current;
    http = _Http();
    HttpOverrides.global = http;
    index = _Index(getIt<SettingsLocalDataSource>());
    getIt.registerSingleton<DownloadedWallIndex>(index);
    gateway = FolderSaveGatewayImpl(CoinsTestFirestore(), index);
    calls = <String>[];
    storedFiles = <List<int>>[];
    saveNative = null;
    backend.onCall = (name, parameters) async {
      calls.add(name);
      return <String, Object>{
        'success': true,
        'changed': true,
        'previousBalance': name == 'spendCoins' ? 100 : 90,
        'currentBalance': name == 'spendCoins' ? 90 : 100,
        'delta': name == 'spendCoins' ? -10 : 10,
        'transactionId': 'spend_${backend.userId}_${parameters['requestId']}',
      };
    };
    channel('enqueueDownload', (message) async {
      final DownloadRequest request = (message! as List<Object?>).single! as DownloadRequest;
      storedFiles.add(await File(request.link).readAsBytes());
      return <Object?>[await saveNative?.call() ?? OperationResult(success: true)];
    });
  });

  tearDown(() async {
    HttpOverrides.global = oldHttp;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
      const MethodChannel('plugins.flutter.io/path_provider'),
      null,
    );
    if (getIt.isRegistered<RecordWallpaperActionUseCase>()) await getIt.unregister<RecordWallpaperActionUseCase>();
    await getIt.unregister<DownloadedWallIndex>();
    await getIt<SettingsLocalDataSource>().delete('pendingDownloads_v2');
    await getIt<SettingsLocalDataSource>().delete('pendingAiRefunds');
    await temporary.delete(recursive: true);
  });

  test('an over-limit confirmed charge is refunded before saving', () async {
    final FolderWallOutcome result = await gateway.save(_open('cap'), album: 'Night', maxCoins: 0);

    expect(result.failure, FolderSaveFailure.priceChanged);
    expect(storedFiles, isEmpty);
    expect(calls, <String>['spendCoins', 'awardCoins']);
    expect(CoinsService.instance.balanceNotifier.value, 100);
  });

  test('a queued open spend never charges an account that did not start it', () async {
    final Completer<void> charged = Completer<void>();
    final Completer<void> resume = Completer<void>();
    final Completer<void> downloaded = Completer<void>();
    int downloads = 0;
    gateway = FolderSaveGatewayImpl(
      CoinsTestFirestore(),
      index,
      openDownloadSink: (file) => _Sink(
        file.openWrite(),
        onClosed: () {
          if (++downloads == 2) downloaded.complete();
        },
      ),
    );
    final originalCall = backend.onCall;
    backend.onCall = (name, parameters) async {
      if (name == 'spendCoins') {
        if (!charged.isCompleted) charged.complete();
        await resume.future;
      }
      return originalCall(name, parameters);
    };
    final first = gateway.save(_open('first'), album: 'Night', maxCoins: 10);
    await charged.future;
    final second = gateway.save(_open('second'), album: 'Night', maxCoins: 10);
    await downloaded.future;
    await Future<void>.delayed(Duration.zero);
    app_state.prismUser.id = 'switched-owner';
    resume.complete();
    await Future.wait(<Future<FolderWallOutcome>>[first, second]);

    expect(calls.where((name) => name == 'spendCoins'), hasLength(1));
    expect(storedFiles, isEmpty);
  });

  test('a queued original grant never charges an account that did not start it', () async {
    final Completer<void> charging = Completer<void>();
    final Completer<void> resume = Completer<void>();
    final originalCall = backend.onCall;
    backend.onCall = (name, parameters) async {
      if (name == 'resolveOriginalAccess') {
        calls.add(name);
        if (!charging.isCompleted) charging.complete();
        await resume.future;
        return <String, Object>{
          'status': 'granted',
          'url': 'https://wall.test/first.jpg',
          'expiresAt': DateTime.now().add(const Duration(minutes: 2)).millisecondsSinceEpoch,
          'currentBalance': 90,
        };
      }
      return originalCall(name, parameters);
    };
    final first = gateway.save(_original('first-original'), album: 'Night', maxCoins: 10);
    await charging.future;
    final second = gateway.save(_original('second-original'), album: 'Night', maxCoins: 10);
    await pumpEventQueue(times: 50);
    app_state.prismUser.id = 'switched-original-owner';
    resume.complete();
    await Future.wait(<Future<FolderWallOutcome>>[first, second]);

    expect(calls.where((name) => name == 'resolveOriginalAccess'), hasLength(1));
    expect(storedFiles, isEmpty);
  });

  test('native success is marked saved before waiting for the index', () async {
    final Completer<void> indexing = Completer<void>();
    final Completer<void> resume = Completer<void>();
    index.onRemember = () async {
      indexing.complete();
      await resume.future;
    };
    final save = gateway.save(_open('ledger'), album: 'Night', maxCoins: 10);
    await indexing.future;
    final String ledger = getIt<SettingsLocalDataSource>().get<String>('pendingDownloads_v2', defaultValue: '');
    final bool marked = ledger.isNotEmpty && PendingDownload.decodeList(ledger).single.saved;
    resume.complete();
    await save;

    expect(marked, isTrue);
    expect(getIt<SettingsLocalDataSource>().get<String>('pendingDownloads_v2', defaultValue: ''), isEmpty);
  });

  test('a failed native save refunds and clears only its own payment', () async {
    saveNative = () async => OperationResult(success: false);
    final result = await gateway.save(_open('failed-save'), album: 'Night', maxCoins: 10);

    expect(result.failure, FolderSaveFailure.storage);
    expect(calls, <String>['spendCoins', 'awardCoins']);
    expect(getIt<SettingsLocalDataSource>().get<String>('pendingDownloads_v2', defaultValue: ''), isEmpty);
    expect(CoinsService.instance.balanceNotifier.value, 100);
  });

  test('an unconfirmed refund blocks a fresh charge until recovery settles it', () async {
    final originalCall = backend.onCall;
    bool refundOffline = true;
    backend.onCall = (name, parameters) {
      if (name == 'awardCoins' && refundOffline) {
        throw FirebaseFunctionsException(code: 'unavailable', message: 'offline');
      }
      return originalCall(name, parameters);
    };
    saveNative = () async => OperationResult(success: false);
    await gateway.save(_open('retry'), album: 'Night', maxCoins: 10);
    final pending = PendingDownload.decodeList(
      getIt<SettingsLocalDataSource>().get<String>('pendingDownloads_v2', defaultValue: ''),
    );
    expect(pending, hasLength(1));
    expect(pending.single.saved, isFalse);
    saveNative = () async => OperationResult(success: true);
    final result = await gateway.save(_open('retry'), album: 'Night', maxCoins: 10);

    expect(result.status, FolderWallStatus.failed);
    expect(calls.where((name) => name == 'spendCoins'), hasLength(1));
    refundOffline = false;
    await CoinsService.instance.retryPendingRefunds();
    final recovered = await gateway.save(_open('retry'), album: 'Night', maxCoins: 10);
    expect(recovered.status, FolderWallStatus.saved);
    expect(calls.where((name) => name == 'spendCoins'), hasLength(2));
  });

  test('pending payments of another owner or wallpaper do not block a save', () async {
    await getIt<SettingsLocalDataSource>().set(
      'pendingDownloads_v2',
      PendingDownload.encodeList(<PendingDownload>[
        PendingDownload(
          txId: 'other-owner',
          userId: 'other',
          link: _open('separate').wall.identity,
          action: 'wallpaperDownload',
          at: DateTime.now().millisecondsSinceEpoch,
        ),
        PendingDownload(
          txId: 'other-wall',
          userId: backend.userId,
          link: 'https://wall.test/other.jpg',
          action: 'wallpaperDownload',
          at: DateTime.now().millisecondsSinceEpoch,
        ),
      ]),
    );
    final result = await gateway.save(_open('separate'), album: 'Night', maxCoins: 10);

    expect(result.status, FolderWallStatus.saved);
    expect(calls.where((name) => name == 'spendCoins'), hasLength(1));
  });

  test('a Prism storage failure retains the grant so retry does not charge again', () async {
    backend.originalAssets['retained'] = (premium: false, coins: 10);
    saveNative = () async => OperationResult(success: false);
    final failed = await gateway.save(_original('retained'), album: 'Night', maxCoins: 10);
    saveNative = () async => OperationResult(success: true);
    final retried = await gateway.save(_original('retained'), album: 'Night', maxCoins: 10);

    expect(failed.failure, FolderSaveFailure.storage);
    expect(retried.status, FolderWallStatus.saved);
    expect(backend.originalDebits, 1);
    expect(backend.originalCalls.map((call) => call['requestId']).toSet(), hasLength(1));
    expect(calls, isEmpty);
  });

  test('an unknown spend outcome retries the same id without another debit', () async {
    final originalCall = backend.onCall;
    final requestIds = <Object?>[];
    bool offline = true;
    backend.onCall = (name, parameters) {
      if (name == 'spendCoins') {
        requestIds.add(parameters['requestId']);
        if (offline) throw FirebaseFunctionsException(code: 'unavailable', message: 'lost reply');
      }
      return originalCall(name, parameters);
    };
    final failed = await gateway.save(_open('unknown'), album: 'Night', maxCoins: 10);
    offline = false;
    final retried = await gateway.save(_open('unknown'), album: 'Night', maxCoins: 10);

    expect(failed.status, FolderWallStatus.failed);
    expect(retried.status, FolderWallStatus.saved);
    expect(requestIds, hasLength(3));
    expect(requestIds.toSet(), hasLength(1));
    expect(storedFiles, hasLength(1));
  });

  test('a ledger persistence failure sends no coin spend or native save', () async {
    final settings = getIt<SettingsLocalDataSource>();
    await getIt.unregister<SettingsLocalDataSource>();
    getIt.registerSingleton<SettingsLocalDataSource>(_FailingSettings(InMemoryLocalStore()));
    try {
      final result = await gateway.save(_open('no-ledger'), album: 'Night', maxCoins: 10);
      expect(result.status, FolderWallStatus.failed);
      expect(calls, isEmpty);
      expect(storedFiles, isEmpty);
    } finally {
      await getIt.unregister<SettingsLocalDataSource>();
      getIt.registerSingleton<SettingsLocalDataSource>(settings);
    }
  });

  test('an acquired original with another identity is copied without network or coins', () async {
    index.acquired = File('${temporary.path}/original.jpg')..writeAsBytesSync(<int>[4, 5, 6]);
    final result = await gateway.save(_original('local'), album: 'Night', maxCoins: 0);

    expect(result.status, FolderWallStatus.saved);
    expect(storedFiles.single, <int>[4, 5, 6]);
    expect(http.requests, 0);
    expect(calls, isEmpty);
    expect(await index.acquired!.exists(), isTrue);
  });

  test('a bundled starter is restored from its catalog without coins or network', () async {
    final result = await gateway.save(
      const FolderSaveItem(
        wall: FolderSaveWall(id: 'starter-sunset', source: WallpaperSource.prism, link: 'https://stale.test/image.jpg'),
        kind: FolderSaveKind.free,
      ),
      album: 'Night',
      maxCoins: 0,
    );

    expect(result.status, FolderWallStatus.saved);
    expect(storedFiles.single, isNotEmpty);
    expect(http.requests, 0);
    expect(calls, isEmpty);
  });

  test('insufficient coins never opens ad consent during a folder save', () async {
    final oldConsent = AdConsent.instance;
    int forms = 0;
    AdConsent.instance = AdConsent(
      requestInfoUpdate: () async {},
      showFormIfRequired: () async {
        forms++;
      },
      canRequestAds: () async => true,
    );
    addTearDown(() => AdConsent.instance = oldConsent);
    backend.originalAssets['insufficient'] = (premium: false, coins: 10);
    backend.originalBalance = 0;
    final result = await gateway.save(_original('insufficient'), album: 'Night', maxCoins: 10);

    expect(result.failure, FolderSaveFailure.notEnoughCoins);
    expect(forms, 0);
  });

  test('a stats failure does not escape a successful save', () async {
    backend.originalAssets['stats'] = (premium: false, coins: 10);
    getIt.registerSingleton<RecordWallpaperActionUseCase>(RecordWallpaperActionUseCase(_Stats()));
    final errors = <Object>[];
    await runZonedGuarded(() async {
      final result = await gateway.save(_original('stats'), album: 'Night', maxCoins: 10);
      expect(result.status, FolderWallStatus.saved);
      await Future<void>.delayed(Duration.zero);
    }, (error, stack) => errors.add(error));

    expect(errors, isEmpty);
  });

  test('a partial network failure retries and leaves no temporary file', () async {
    http.body = (request) => request == 1
        ? (StreamController<List<int>>()
                ..add(<int>[9])
                ..addError(const SocketException('interrupted'))
                ..close())
              .stream
        : Stream<List<int>>.value(<int>[1, 2, 3]);
    final sinks = <_Sink>[];
    gateway = FolderSaveGatewayImpl(
      CoinsTestFirestore(),
      index,
      openDownloadSink: (file) {
        final sink = _Sink(file.openWrite());
        sinks.add(sink);
        return sink;
      },
    );
    final result = await gateway.save(_open('partial'), album: 'Night', maxCoins: 10);

    expect(result.status, FolderWallStatus.saved);
    expect(http.requests, 2);
    expect(storedFiles.single, <int>[1, 2, 3]);
    expect(await Directory('${temporary.path}/folder_save').list().toList(), isEmpty);
    expect(sinks.map((sink) => sink.closed), everyElement(isTrue));
  });

  test('a server error with an unfinished body retries without draining it', () async {
    final body = StreamController<List<int>>.broadcast();
    http.status = HttpStatus.internalServerError;
    http.body = (_) => body.stream;
    final save = gateway.save(_open('server-error'), album: 'Night', maxCoins: 10);
    try {
      final result = await save.timeout(const Duration(seconds: 2));
      expect(result.failure, FolderSaveFailure.network);
      expect(http.requests, 2);
      expect(calls, isEmpty);
      expect(storedFiles, isEmpty);
      expect(await Directory('${temporary.path}/folder_save').list().toList(), isEmpty);
    } finally {
      await body.close();
      await save;
    }
  });
}
