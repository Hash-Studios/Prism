import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:Prism/core/constants/app_constants.dart' as app_constants;
import 'package:Prism/core/di/injection.dart';
import 'package:Prism/core/offline/offline_asset_store.dart';
import 'package:Prism/core/router/app_router.dart';
import 'package:Prism/core/state/app_state.dart' as app_state;
import 'package:Prism/core/wallpaper/wallpaper_source.dart';
import 'package:Prism/core/widgets/menu_button/circular_menu_button.dart';
import 'package:Prism/core/widgets/menu_button/edit_button.dart';
import 'package:Prism/l10n/l10n.dart';
import 'package:auto_route/auto_route.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import '../../../support/coins_test_backend.dart';
import '../../../support/wait_for_real_io.dart';

class _MockStackRouter extends Mock implements StackRouter {}

class _MockCacheManager extends Mock implements BaseCacheManager {}

class _MockFile extends Mock implements File {}

class _PendingOfflineAssetStore extends OfflineAssetStore {
  _PendingOfflineAssetStore(this.resolution) : super();

  final Completer<File> resolution;
  final Completer<void> resolveStarted = Completer<void>();

  @override
  Future<File> resolve(String source, {bool allowNetwork = true}) {
    if (!resolveStarted.isCompleted) resolveStarted.complete();
    return resolution.future;
  }
}

const String _tinyGif = 'R0lGODlhAQABAAD/ACwAAAAAAQABAAACADs=';

Widget _host(
  StackRouter router,
  String? url, {
  Future<String> Function()? prepareSource,
  Future<String> Function(String)? prepareAuthorized,
  WallpaperSource? source = WallpaperSource.wallhaven,
  String? wallpaperId,
}) => MaterialApp(
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  supportedLocales: AppLocalizations.supportedLocales,

  home: StackRouterScope(
    controller: router,
    stateHash: 0,
    child: Scaffold(
      body: EditButton(
        url: url,
        wallpaperId: wallpaperId,
        wallpaperSource: source,
        prepareSource: prepareSource,
        prepareAuthorized: prepareAuthorized,
      ),
    ),
  ),
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() => registerFallbackValue(WallpaperFilterRoute(filePath: 'unused')));

  late Directory directory;
  late _MockCacheManager cacheManager;
  int temporaryDirectoryCalls = 0;
  const MethodChannel pathChannel = MethodChannel('plugins.flutter.io/path_provider');
  const MethodChannel toastChannel = MethodChannel('PonnamKarthik/fluttertoast');
  final messenger = TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;

  setUp(() {
    directory = Directory.systemTemp.createTempSync('edit_button_test_');
    cacheManager = _MockCacheManager();
    temporaryDirectoryCalls = 0;
    OfflineAssetStore.testOverride = OfflineAssetStore(
      directory: Directory('${directory.path}/retained'),
      cacheManager: cacheManager,
    );
    when(() => cacheManager.getFileFromCache(any())).thenAnswer((_) async => null);
    when(() => cacheManager.getSingleFile(any())).thenThrow(StateError('Unexpected network request in edit test.'));
    messenger.setMockMethodCallHandler(pathChannel, (_) async {
      temporaryDirectoryCalls++;
      return directory.path;
    });
    messenger.setMockMethodCallHandler(toastChannel, (_) async => true);
  });

  tearDown(() async {
    app_state.prismUser = app_constants.createGuestPrismUser();
    await getIt.reset();
    OfflineAssetStore.testOverride = null;
    messenger.setMockMethodCallHandler(pathChannel, null);
    messenger.setMockMethodCallHandler(toastChannel, null);
    directory.deleteSync(recursive: true);
  });

  for (final source in <WallpaperSource?>[null, WallpaperSource.unknown, WallpaperSource.downloaded]) {
    testWidgets('rejects remote $source before preparing or loading an editor source', (tester) async {
      final router = _MockStackRouter();
      var preparations = 0;
      await tester.pumpWidget(
        _host(
          router,
          'https://img.test/original.jpg',
          source: source,
          prepareAuthorized: (_) async {
            preparations++;
            return '${directory.path}/export.png';
          },
        ),
      );
      await tester.tap(find.byType(EditButton));
      await tester.pump();
      await tester.pump();

      expect(preparations, 0);
      verifyNever(() => cacheManager.getSingleFile(any()));
      verifyNever(() => cacheManager.getFileFromCache(any()));
      verifyNever(() => router.push(any()));
      expect(temporaryDirectoryCalls, 0);
      expect(tester.widget<CircularMenuButton>(find.byType(CircularMenuButton)).isLoading, isFalse);
      expect(tester.takeException(), isNull);
      await tester.pump(const Duration(seconds: 1));
    });
  }

  for (final code in <String>['unauthenticated', 'permission-denied']) {
    testWidgets('a $code original grant cannot prepare or fall back to the public URL', (tester) async {
      final backend = CoinsTestBackend();
      await backend.install();
      final calls = <Map<String, dynamic>>[];
      backend.onCall = (name, input) async {
        expect(name, 'resolveOriginalAccess');
        calls.add(input);
        if (input['mode'] == 'quote') {
          return <String, dynamic>{'status': 'quoted', 'requiredCoins': 0, 'currentBalance': 100};
        }
        throw FirebaseFunctionsException(code: code, message: 'Denied');
      };
      final router = _MockStackRouter();
      var preparations = 0;
      await tester.pumpWidget(
        _host(
          router,
          'https://img.test/public-original.jpg',
          source: WallpaperSource.prism,
          wallpaperId: 'protected-edit-$code',
          prepareSource: () async {
            preparations++;
            return '${directory.path}/export.png';
          },
        ),
      );
      await tester.tap(find.byType(EditButton));
      await tester.pumpAndSettle();

      expect(calls, hasLength(2));
      expect(calls.every((call) => call['action'] == 'edit'), isTrue);
      expect(calls.last['maxCoins'], 0);
      expect(preparations, 0);
      verifyNever(() => cacheManager.getSingleFile(any()));
      verifyNever(() => cacheManager.getFileFromCache(any()));
      verifyNever(() => router.push(any()));
      expect(temporaryDirectoryCalls, 0);
      expect(tester.widget<CircularMenuButton>(find.byType(CircularMenuButton)).isLoading, isFalse);
      expect(tester.takeException(), isNull);
      await tester.pump(const Duration(seconds: 1));
    });
  }

  testWidgets('keeps another editor source and removes only its own session after the route closes', (tester) async {
    final Directory editDirectory = Directory('${directory.path}/prism_edit')..createSync();
    final File activeSource = File('${editDirectory.path}/source_active.img')..writeAsBytesSync(<int>[9, 8, 7]);
    final _MockStackRouter router = _MockStackRouter();
    final List<Object?> hapticTypes = <Object?>[];
    messenger.setMockMethodCallHandler(SystemChannels.platform, (call) async {
      if (call.method == 'HapticFeedback.vibrate') hapticTypes.add(call.arguments);
      return null;
    });
    addTearDown(() => messenger.setMockMethodCallHandler(SystemChannels.platform, null));
    final Completer<WallpaperFilterRoute> pushed = Completer<WallpaperFilterRoute>();
    final Completer<Object?> routeResult = Completer<Object?>();
    when(() => router.push(any())).thenAnswer((invocation) {
      pushed.complete(invocation.positionalArguments.single as WallpaperFilterRoute);
      return routeResult.future;
    });
    final downloaded = (await tester.runAsync(() async {
      final file = await IOFileSystem(directory.path).createFile('downloaded.gif');
      await file.writeAsBytes(base64Decode(_tinyGif));
      return file;
    }))!;
    when(() => cacheManager.getSingleFile(any())).thenAnswer((_) async => downloaded);

    await tester.pumpWidget(_host(router, 'https://img.test/wallpaper.gif'));
    await tester.tap(find.byType(EditButton));
    await waitForRealIo(tester, () => pushed.isCompleted, reason: 'edit route push after source preparation');
    final WallpaperFilterRoute route = await pushed.future;
    final File source = File(route.args!.filePath);
    expect(activeSource.readAsBytesSync(), <int>[9, 8, 7]);
    expect(hapticTypes.where((type) => type == 'HapticFeedbackType.lightImpact'), hasLength(1));
    expect(source.readAsBytesSync(), downloaded.readAsBytesSync());
    expect(source.parent.path, isNot(editDirectory.path));

    routeResult.complete();
    await waitForRealIo(tester, () => !source.parent.existsSync(), reason: 'edit session cleanup after route close');
    expect(source.parent.existsSync(), isFalse);
    expect(activeSource.readAsBytesSync(), <int>[9, 8, 7]);
    expect(tester.takeException(), isNull);
    expect(hapticTypes, <Object?>['HapticFeedbackType.lightImpact']);
    await tester.pump(const Duration(seconds: 1));
  }, variant: TargetPlatformVariant.only(TargetPlatform.iOS));

  group('prepareSource', () {
    testWidgets('opens the editor on the prepared file without fetching the url or deleting the file', (tester) async {
      final _MockStackRouter router = _MockStackRouter();
      final File prepared = File('${directory.path}/prism_tint/1_0.png')
        ..createSync(recursive: true)
        ..writeAsBytesSync(<int>[4, 5, 6]);
      final Completer<Object?> routeResult = Completer<Object?>();
      WallpaperFilterRoute? pushed;
      when(() => router.push(any())).thenAnswer((invocation) {
        pushed = invocation.positionalArguments.single as WallpaperFilterRoute;
        return routeResult.future;
      });
      int calls = 0;

      await tester.pumpWidget(
        _host(
          router,
          prepared.path,
          source: WallpaperSource.downloaded,
          prepareSource: () async {
            calls++;
            return prepared.path;
          },
        ),
      );
      await tester.tap(find.byType(EditButton));
      await tester.pump();
      await tester.pump();
      routeResult.complete();
      await tester.pump();

      expect(calls, 1);
      expect(pushed!.args!.filePath, prepared.path);
      expect(prepared.readAsBytesSync(), <int>[4, 5, 6]);
      expect(Directory('${directory.path}/prism_edit').existsSync(), isFalse);
      expect(tester.takeException(), isNull);
      await tester.pump(const Duration(seconds: 1));
    });

    testWidgets('a failed prepare tells the user, does not open the editor and can be tried again', (tester) async {
      final _MockStackRouter router = _MockStackRouter();
      final List<Object?> toastMessages = <Object?>[];
      messenger.setMockMethodCallHandler(toastChannel, (call) async {
        if (call.method == 'showToast') toastMessages.add((call.arguments as Map<Object?, Object?>)['msg']);
        return true;
      });
      int calls = 0;

      await tester.pumpWidget(
        _host(
          router,
          'http://127.0.0.1:9/wallpaper',
          prepareSource: () {
            calls++;
            return Future<String>.error(StateError('render failed'));
          },
        ),
      );
      await tester.tap(find.byType(EditButton));
      await tester.pump();
      await tester.pump();

      expect(toastMessages, contains("Couldn't apply the colour. Try again."));
      verifyNever(() => router.push(any()));
      expect(tester.widget<CircularMenuButton>(find.byType(CircularMenuButton)).isLoading, isFalse);

      await tester.tap(find.byType(EditButton));
      await tester.pump();
      await tester.pump();
      expect(calls, 2);
      await tester.pump(const Duration(seconds: 1));
    });
  });

  testWidgets('missing wallpaper URL only plays the error haptic', (tester) async {
    final _MockStackRouter router = _MockStackRouter();
    final List<Object?> hapticTypes = <Object?>[];
    messenger.setMockMethodCallHandler(SystemChannels.platform, (call) async {
      if (call.method == 'HapticFeedback.vibrate') hapticTypes.add(call.arguments);
      return null;
    });
    addTearDown(() => messenger.setMockMethodCallHandler(SystemChannels.platform, null));

    await tester.pumpWidget(_host(router, null));
    await tester.tap(find.byType(EditButton));
    await tester.pump();

    expect(hapticTypes, <Object?>['HapticFeedbackType.errorNotification']);
    expect(hapticTypes.where((type) => type == 'HapticFeedbackType.lightImpact'), isEmpty);
    await tester.pump(const Duration(seconds: 1));
  }, variant: TargetPlatformVariant.only(TargetPlatform.iOS));

  testWidgets('does not create a source or route after disposal while the download is pending', (tester) async {
    final _MockStackRouter router = _MockStackRouter();
    when(() => router.push(any())).thenAnswer((_) async => null);
    final Completer<File> resolution = Completer<File>();
    final _PendingOfflineAssetStore assetStore = _PendingOfflineAssetStore(resolution);
    OfflineAssetStore.testOverride = assetStore;
    final Completer<void> readStarted = Completer<void>();
    final _MockFile resolvedFile = _MockFile();
    when(() => resolvedFile.readAsBytes()).thenAnswer((_) async {
      if (!readStarted.isCompleted) readStarted.complete();
      return Uint8List.fromList(<int>[1, 2, 3]);
    });

    await tester.pumpWidget(_host(router, 'https://img.test/pending.gif'));
    await tester.tap(find.byType(EditButton));
    await waitForRealIo(tester, () => assetStore.resolveStarted.isCompleted, reason: 'asset resolution starts');
    await tester.pumpWidget(const SizedBox());
    await tester.runAsync(() async {
      resolution.complete(resolvedFile);
    });
    await waitForRealIo(tester, () => readStarted.isCompleted, reason: 'resolved file read starts after disposal');
    await tester.pump();

    expect(temporaryDirectoryCalls, 0);
    expect(Directory('${directory.path}/prism_edit').existsSync(), isFalse);
    verifyNever(() => router.push(any()));
    expect(tester.takeException(), isNull);
    await tester.pump(const Duration(seconds: 1));
  });
}
