import 'dart:async';
import 'dart:io';

import 'package:Prism/core/auth/require_signed_in_action.dart';
import 'package:Prism/core/constants/app_constants.dart' as app_constants;
import 'package:Prism/core/di/injection.dart';
import 'package:Prism/core/haptics/prism_haptics.dart';
import 'package:Prism/core/persistence/data_sources/settings_local_data_source.dart';
import 'package:Prism/core/platform/ios_wallpaper_guide.dart';
import 'package:Prism/core/platform/pigeon/prism_media_api.g.dart';
import 'package:Prism/core/state/app_state.dart' as app_state;
import 'package:Prism/core/wallpaper/wall_depth.dart';
import 'package:Prism/core/wallpaper/wall_spatial.dart';
import 'package:Prism/core/wallpaper/wallpaper_source.dart';
import 'package:Prism/core/widgets/menu_button/circular_menu_button.dart';
import 'package:Prism/core/widgets/prism/prism_ui.dart';
import 'package:Prism/features/ads/ads.dart';
import 'package:Prism/features/ads/data/ad_consent.dart';
import 'package:Prism/features/ads/views/widgets/download_button.dart';
import 'package:Prism/l10n/generated/app_localizations_en.dart';
import 'package:Prism/l10n/l10n.dart';
import 'package:bloc_test/bloc_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import '../../support/in_memory_local_store.dart';
import '../../support/offline_asset_fixture.dart';
import '../../support/profile_user_fixture.dart';

class _ThrowingSettings extends SettingsLocalDataSource {
  _ThrowingSettings() : super(InMemoryLocalStore());

  @override
  bool get isOpen => throw StateError('settings unavailable');
}

class _MockAdsBloc extends MockBloc<AdsEvent, AdsState> implements AdsBloc {}

void main() {
  late OfflineAssetFixture offlineFixture;
  const BasicMessageChannel<Object?> listDownloadsChannel = BasicMessageChannel<Object?>(
    'dev.flutter.pigeon.Prism.PrismMediaHostApi.listDownloads',
    PrismMediaHostApi.pigeonChannelCodec,
  );

  setUp(() async {
    offlineFixture = await OfflineAssetFixture.create(cacheMissByDefault: true);
    offlineFixture.install(immediateResolver: true);
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockDecodedMessageHandler<Object?>(
      listDownloadsChannel,
      (_) async => <Object?>[DownloadItemsResult(success: true, items: const <String>[])],
    );
  });

  tearDown(() async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockDecodedMessageHandler<Object?>(
      listDownloadsChannel,
      null,
    );
    await offlineFixture.dispose();
  });

  AdConsent consent({required bool canRequestAds}) => AdConsent(
    requestInfoUpdate: () async {},
    showFormIfRequired: () async {},
    canRequestAds: () async => canRequestAds,
  );

  Future<void> flushIo(WidgetTester tester) async {
    await tester.runAsync(() => Future<void>.delayed(Duration.zero));
  }

  List<String> recordHaptics(WidgetTester tester) {
    const MethodChannel channel = MethodChannel('prism/haptics');
    final bool wasEnabled = PrismHaptics.enabled;
    PrismHaptics.enabled = true;
    final List<String> events = <String>[];
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(channel, (call) async {
      if (call.method == 'play') events.add(call.arguments! as String);
      return null;
    });
    addTearDown(() {
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(channel, null);
      PrismHaptics.enabled = wasEnabled;
    });
    return events;
  }

  for (final source in <String, bool>{
    'absolute local file': true,
    'file URI': true,
    'Android-style local file': true,
    'remote URL': false,
  }.entries) {
    testWidgets('downloads a ${source.key} with the correct native source kind', (tester) async {
      getIt.registerSingleton<SettingsLocalDataSource>(_ThrowingSettings());
      app_state.prismUser = profileUser(premium: true);
      final File image = (await tester.runAsync(() => offlineFixture.createImage('filtered wall.png')))!;
      final String link = switch (source.key) {
        'absolute local file' => image.path,
        'file URI' => image.uri.toString(),
        'Android-style local file' => image.path,
        _ => 'https://example.com/com.hash.prism/wall.jpg',
      };
      final String expectedLink = source.value ? image.path : link;
      final requests = <Object?>[];
      final channels = <BasicMessageChannel<Object?>>[
        for (final method in <String>['saveMedia', 'enqueueDownload'])
          BasicMessageChannel<Object?>(
            'dev.flutter.pigeon.Prism.PrismMediaHostApi.$method',
            PrismMediaHostApi.pigeonChannelCodec,
          ),
      ];
      for (final channel in channels) {
        tester.binding.defaultBinaryMessenger.setMockDecodedMessageHandler<Object?>(channel, (message) async {
          requests.add((message! as List<Object?>).single);
          return <Object?>[OperationResult(success: true)];
        });
      }
      addTearDown(() async {
        for (final channel in channels) {
          tester.binding.defaultBinaryMessenger.setMockDecodedMessageHandler<Object?>(channel, null);
        }
        app_state.prismUser = app_constants.createGuestPrismUser();
        await getIt.reset();
      });

      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,

          home: Scaffold(
            body: DownloadButton(wallpaperSource: source.value ? null : WallpaperSource.wallhaven, link: link),
          ),
        ),
      );
      await tester.tap(find.byType(CircularMenuButton));
      await flushIo(tester);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(requests, hasLength(1));
      final DownloadRequest request = requests.single! as DownloadRequest;
      expect(request.link, expectedLink);
      expect(request.isLocalFile, source.value);
      expect(request.filenameWithoutExtension, source.value ? 'filtered wall' : 'wall');
    });
  }

  testWidgets('tapping the label beside the circle starts the download', (tester) async {
    getIt.registerSingleton<SettingsLocalDataSource>(_ThrowingSettings());
    app_state.prismUser = profileUser(premium: true);
    const BasicMessageChannel<Object?> channel = BasicMessageChannel<Object?>(
      'dev.flutter.pigeon.Prism.PrismMediaHostApi.enqueueDownload',
      PrismMediaHostApi.pigeonChannelCodec,
    );
    var requestCount = 0;
    tester.binding.defaultBinaryMessenger.setMockDecodedMessageHandler<Object?>(channel, (_) async {
      requestCount++;
      return <Object?>[OperationResult(success: true)];
    });
    addTearDown(() async {
      tester.binding.defaultBinaryMessenger.setMockDecodedMessageHandler<Object?>(channel, null);
      app_state.prismUser = app_constants.createGuestPrismUser();
      await getIt.reset();
    });

    await tester.pumpWidget(
      const MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,

        home: Scaffold(
          body: DownloadButton(
            wallpaperSource: WallpaperSource.wallhaven,
            link: 'https://example.com/wall.jpg',
            label: 'Save',
          ),
        ),
      ),
    );
    await tester.tap(find.text('Free with Pro'));
    await flushIo(tester);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(requestCount, 1);
  });

  testWidgets('successful download records callback when permission prompt fails', (tester) async {
    getIt.registerSingleton<SettingsLocalDataSource>(_ThrowingSettings());
    app_state.prismUser = profileUser(premium: true);
    const BasicMessageChannel<Object?> channel = BasicMessageChannel<Object?>(
      'dev.flutter.pigeon.Prism.PrismMediaHostApi.enqueueDownload',
      PrismMediaHostApi.pigeonChannelCodec,
    );
    tester.binding.defaultBinaryMessenger.setMockDecodedMessageHandler<Object?>(
      channel,
      (_) async => <Object?>[OperationResult(success: true)],
    );
    addTearDown(() async {
      tester.binding.defaultBinaryMessenger.setMockDecodedMessageHandler<Object?>(channel, null);
      app_state.prismUser = app_constants.createGuestPrismUser();
      await getIt.reset();
    });
    var callbackCount = 0;

    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,

        home: Scaffold(
          body: DownloadButton(
            wallpaperSource: WallpaperSource.wallhaven,
            link: 'https://example.com/wall.jpg',
            onDownloaded: () => callbackCount++,
          ),
        ),
      ),
    );
    await tester.tap(find.byType(CircularMenuButton));
    await flushIo(tester);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(callbackCount, 1);
  });

  testWidgets('maps native storage failures to localized copy instead of the native message', (tester) async {
    getIt.registerSingleton<SettingsLocalDataSource>(_ThrowingSettings());
    app_state.prismUser = profileUser(premium: true);
    const BasicMessageChannel<Object?> channel = BasicMessageChannel<Object?>(
      'dev.flutter.pigeon.Prism.PrismMediaHostApi.enqueueDownload',
      PrismMediaHostApi.pigeonChannelCodec,
    );
    const MethodChannel toastChannel = MethodChannel('PonnamKarthik/fluttertoast');
    final List<String> toastMessages = <String>[];
    tester.binding.defaultBinaryMessenger.setMockDecodedMessageHandler<Object?>(
      channel,
      (_) async => <Object?>[
        OperationResult(
          success: false,
          errorCode: 'STORAGE_PERMISSION_REQUIRED',
          message: 'Allow storage access to save wallpapers on this Android version',
        ),
      ],
    );
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(toastChannel, (call) async {
      if (call.method == 'showToast') toastMessages.add((call.arguments as Map<Object?, Object?>)['msg']! as String);
      return true;
    });
    addTearDown(() async {
      tester.binding.defaultBinaryMessenger.setMockDecodedMessageHandler<Object?>(channel, null);
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(toastChannel, null);
      app_state.prismUser = app_constants.createGuestPrismUser();
      await getIt.reset();
    });

    await tester.pumpWidget(
      const MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: DownloadButton(wallpaperSource: WallpaperSource.wallhaven, link: 'https://example.com/wall.jpg'),
        ),
      ),
    );
    await tester.tap(find.byType(CircularMenuButton));
    await flushIo(tester);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(toastMessages, <String>['Check your storage access and try again.']);
    await tester.pump(const Duration(seconds: 1));
  });

  testWidgets('primary draws a compact accent button instead of a round one', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,

        home: Scaffold(
          body: DownloadButton(
            wallpaperSource: WallpaperSource.wallhaven,
            link: 'https://example.com/wall.jpg',
            primary: true,
          ),
        ),
      ),
    );

    expect(find.widgetWithText(FilledButton, 'Download'), findsOneWidget);
    expect(find.byType(CircularMenuButton), findsNothing);
    expect(tester.widget<PrismButton>(find.byType(PrismButton)).size, PrismButtonSize.compact);
  });

  testWidgets('labelled puts the name under the round button', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,

        home: Scaffold(
          body: DownloadButton(
            wallpaperSource: WallpaperSource.wallhaven,
            link: 'https://example.com/wall.jpg',
            labelled: true,
          ),
        ),
      ),
    );

    expect(find.text('Download'), findsOneWidget);
    expect(find.byType(CircularMenuButton), findsOneWidget);
  });

  for (final bool semanticTap in <bool>[false, true]) {
    testWidgets('primary guest download requests sign-in (${semanticTap ? 'semantics' : 'touch'})', (tester) async {
      final handle = tester.ensureSemantics();
      final List<String> haptics = recordHaptics(tester);
      app_state.prismUser = app_constants.createGuestPrismUser();
      final AdConsent original = AdConsent.instance;
      AdConsent.instance = consent(canRequestAds: false);
      addTearDown(() => AdConsent.instance = original);
      await tester.pumpWidget(
        const MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,

          home: Scaffold(
            body: DownloadButton(
              wallpaperSource: WallpaperSource.wallhaven,
              link: 'https://example.com/wall.jpg',
              primary: true,
            ),
          ),
        ),
      );

      if (semanticTap) {
        final node = tester.getSemantics(find.bySemanticsLabel('Download'));
        tester.binding.performSemanticsAction(
          SemanticsActionEvent(type: SemanticsAction.tap, viewId: tester.view.viewId, nodeId: node.id),
        );
      } else {
        await tester.tap(find.widgetWithText(FilledButton, 'Download'));
      }
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 600));

      expect(find.text('Sign in to Prism'), findsOneWidget);
      expect(haptics, semanticTap ? isEmpty : <String>['tap']);
      handle.dispose();
    });
  }

  testWidgets('download that finishes after leaving the page still shows the saved toast', (tester) async {
    getIt.registerSingleton<SettingsLocalDataSource>(_ThrowingSettings());
    app_state.prismUser = profileUser(premium: true);
    const BasicMessageChannel<Object?> channel = BasicMessageChannel<Object?>(
      'dev.flutter.pigeon.Prism.PrismMediaHostApi.enqueueDownload',
      PrismMediaHostApi.pigeonChannelCodec,
    );
    const MethodChannel toastChannel = MethodChannel('PonnamKarthik/fluttertoast');
    final Completer<void> downloadFinished = Completer<void>();
    final List<Object?> toastMessages = <Object?>[];
    tester.binding.defaultBinaryMessenger.setMockDecodedMessageHandler<Object?>(channel, (_) async {
      await downloadFinished.future;
      return <Object?>[OperationResult(success: true)];
    });
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(toastChannel, (call) async {
      if (call.method == 'showToast') toastMessages.add((call.arguments as Map<Object?, Object?>)['msg']);
      return true;
    });
    addTearDown(() async {
      tester.binding.defaultBinaryMessenger.setMockDecodedMessageHandler<Object?>(channel, null);
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(toastChannel, null);
      app_state.prismUser = app_constants.createGuestPrismUser();
      await getIt.reset();
    });

    await tester.pumpWidget(
      const MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,

        home: Scaffold(
          body: DownloadButton(wallpaperSource: WallpaperSource.wallhaven, link: 'https://example.com/wall.jpg'),
        ),
      ),
    );
    await tester.tap(find.byType(CircularMenuButton));
    await flushIo(tester);
    await tester.pump();
    await tester.pumpWidget(
      const MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: SizedBox(),
      ),
    );
    downloadFinished.complete();
    await tester.pump(const Duration(milliseconds: 100));

    expect(toastMessages, contains(AppLocalizationsEn().coreWallpaperDownloadedPictures));
    await tester.pump(const Duration(seconds: 1));
  });

  testWidgets('a signed-out user sees sign-in, not the old ad gate', (tester) async {
    final AdConsent original = AdConsent.instance;
    AdConsent.instance = consent(canRequestAds: true);
    addTearDown(() => AdConsent.instance = original);
    app_state.prismUser = app_constants.createGuestPrismUser();
    await tester.pumpWidget(
      const MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,

        home: Scaffold(
          body: DownloadButton(wallpaperSource: WallpaperSource.wallhaven, link: 'https://example.com/wall.jpg'),
        ),
      ),
    );

    await tester.tap(find.byType(CircularMenuButton));
    // The button shows its own spinner while the gate is open, so settle by time.
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600));

    expect(find.text('Sign in to Prism'), findsOneWidget);
    expect(find.text('Download this wallpaper'), findsNothing);
    expect(find.widgetWithText(FilledButton, 'Watch ad'), findsNothing);
    expect(find.widgetWithText(FilledButton, 'Buy premium'), findsNothing);
    expect(find.byType(Dialog), findsNothing);
  });

  testWidgets('with ads refused guests still must sign in', (tester) async {
    final AdConsent original = AdConsent.instance;
    AdConsent.instance = consent(canRequestAds: false);
    addTearDown(() => AdConsent.instance = original);
    app_state.prismUser = app_constants.createGuestPrismUser();
    await tester.pumpWidget(
      const MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,

        home: Scaffold(
          body: DownloadButton(wallpaperSource: WallpaperSource.wallhaven, link: 'https://example.com/wall.jpg'),
        ),
      ),
    );

    await tester.tap(find.byType(CircularMenuButton));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600));

    expect(find.text('Sign in to Prism'), findsOneWidget);
    expect(find.textContaining('Ads are off. Change this in Settings > Privacy.'), findsNothing);
    expect(find.widgetWithText(FilledButton, 'Watch ad'), findsNothing);
    expect(find.widgetWithText(FilledButton, 'Buy premium'), findsNothing);
  });

  testWidgets('guest download never requests an ad before sign-in', (tester) async {
    final List<String> haptics = recordHaptics(tester);
    final AdConsent original = AdConsent.instance;
    AdConsent.instance = consent(canRequestAds: true);
    addTearDown(() => AdConsent.instance = original);
    app_state.prismUser = app_constants.createGuestPrismUser();
    final _MockAdsBloc bloc = _MockAdsBloc();
    whenListen(bloc, const Stream<AdsState>.empty(), initialState: AdsState.initial());
    const MethodChannel toastChannel = MethodChannel('PonnamKarthik/fluttertoast');
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(toastChannel, (_) async => true);
    addTearDown(() => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(toastChannel, null));
    await tester.pumpWidget(
      BlocProvider<AdsBloc>.value(
        value: bloc,
        child: const MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,

          home: Scaffold(
            body: DownloadButton(wallpaperSource: WallpaperSource.wallhaven, link: 'https://example.com/wall.jpg'),
          ),
        ),
      ),
    );
    await tester.tap(find.byType(CircularMenuButton));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600));

    expect(haptics, isEmpty, reason: 'a guest tap must not play the download haptic');
    verifyNever(() => bloc.add(const AdsEvent.started()));
    expect(find.text('Sign in to Prism'), findsOneWidget);
    await tester.pump(const Duration(seconds: 2));
  });

  testWidgets('repeated taps share a pending sign-in request and retry after cancellation', (tester) async {
    app_state.prismUser = app_constants.createGuestPrismUser();
    final Future<bool> Function(BuildContext context) originalSignIn = signedInActionSignIn;
    addTearDown(() => signedInActionSignIn = originalSignIn);
    final List<Completer<bool>> signInRequests = <Completer<bool>>[];
    signedInActionSignIn = (_) {
      final Completer<bool> request = Completer<bool>();
      signInRequests.add(request);
      return request.future;
    };
    await tester.pumpWidget(
      const MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: DownloadButton(wallpaperSource: WallpaperSource.wallhaven, link: 'https://example.com/wall.jpg'),
        ),
      ),
    );

    await tester.tap(find.byType(CircularMenuButton));
    await tester.pump();
    await tester.tap(find.byType(CircularMenuButton));
    await tester.pump();
    expect(signInRequests, hasLength(1));

    signInRequests.single.complete(false);
    await tester.pump();
    await tester.runAsync(() => Future<void>.delayed(Duration.zero));
    await tester.pump();
    await tester.tap(find.byType(CircularMenuButton));
    await tester.pump();

    expect(signInRequests, hasLength(2));
    signInRequests.last.complete(false);
    await tester.runAsync(() => Future<void>.delayed(Duration.zero));
    await tester.pump();
  });

  testWidgets('guest download opens sign-in without offering a purchase first', (tester) async {
    final List<String> haptics = recordHaptics(tester);
    final AdConsent original = AdConsent.instance;
    AdConsent.instance = consent(canRequestAds: false);
    addTearDown(() => AdConsent.instance = original);
    app_state.prismUser = app_constants.createGuestPrismUser();
    await tester.pumpWidget(
      const MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,

        home: Scaffold(
          body: DownloadButton(wallpaperSource: WallpaperSource.wallhaven, link: 'https://example.com/wall.jpg'),
        ),
      ),
    );
    await tester.tap(find.byType(CircularMenuButton));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600));

    expect(find.widgetWithText(FilledButton, 'Buy premium'), findsNothing);
    expect(haptics, isEmpty, reason: 'a guest tap must not play the download haptic');
    expect(find.text('Sign in to Prism'), findsOneWidget);
  });

  group('on iOS', () {
    const BasicMessageChannel<Object?> channel = BasicMessageChannel<Object?>(
      'dev.flutter.pigeon.Prism.PrismMediaHostApi.enqueueDownload',
      PrismMediaHostApi.pigeonChannelCodec,
    );
    const MethodChannel toastChannel = MethodChannel('PonnamKarthik/fluttertoast');

    final List<String> toastMessages = <String>[];

    Future<void> download(
      WidgetTester tester,
      OperationResult result, {
      WallDepthTier? depthTier,
      WallSpatialTier? spatialTier,
      bool guideShown = false,
    }) async {
      getIt.registerSingleton<SettingsLocalDataSource>(_ThrowingSettings());
      app_state.prismUser = profileUser(premium: true);
      IosWallpaperGuideSession.shown = guideShown;
      toastMessages.clear();
      tester.binding.defaultBinaryMessenger.setMockDecodedMessageHandler<Object?>(
        channel,
        (_) async => <Object?>[result],
      );
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(toastChannel, (call) async {
        if (call.method == 'showToast') toastMessages.add((call.arguments as Map<Object?, Object?>)['msg']! as String);
        return true;
      });
      addTearDown(() async {
        tester.binding.defaultBinaryMessenger.setMockDecodedMessageHandler<Object?>(channel, null);
        tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(toastChannel, null);
        app_state.prismUser = app_constants.createGuestPrismUser();
        await getIt.reset();
      });
      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,

          home: Scaffold(
            body: DownloadButton(
              wallpaperSource: WallpaperSource.wallhaven,
              link: 'https://example.com/wall.jpg',
              depthTier: depthTier,
              spatialTier: spatialTier,
            ),
          ),
        ),
      );
      await tester.tap(find.byType(CircularMenuButton));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      await tester.pump(const Duration(seconds: 2));
    }

    testWidgets('a saved wallpaper opens the Set as wallpaper guide', (tester) async {
      await download(tester, OperationResult(success: true));

      expect(find.text('Open Photos'), findsOneWidget);
    }, variant: TargetPlatformVariant.only(TargetPlatform.iOS));

    testWidgets('a saved Depth Effect wall ends the guide with the Depth Effect step', (tester) async {
      await download(tester, OperationResult(success: true), depthTier: WallDepthTier.menu);

      expect(find.text('Open Photos'), findsOneWidget);
      expect(find.text(AppLocalizationsEn().coreDepthEffectMenuShortTip), findsOneWidget);
      expect(toastMessages, <String>[AppLocalizationsEn().coreWallpaperSavedPhotos]);
    }, variant: TargetPlatformVariant.only(TargetPlatform.iOS));

    testWidgets('a saved Spatial Scene wall ends the guide with the Spatial Scene step', (tester) async {
      await download(tester, OperationResult(success: true), spatialTier: WallSpatialTier.great);

      expect(find.text('Open Photos'), findsOneWidget);
      expect(find.text(AppLocalizationsEn().wallpaperSpatialStepButton), findsOneWidget);
    }, variant: TargetPlatformVariant.only(TargetPlatform.iOS));

    testWidgets('once the guide has shown, the saved toast carries the Depth Effect step', (tester) async {
      await download(tester, OperationResult(success: true), depthTier: WallDepthTier.menu, guideShown: true);

      expect(find.text('Open Photos'), findsNothing);
      final AppLocalizationsEn l10n = AppLocalizationsEn();
      expect(toastMessages, <String>[
        l10n.coreWallpaperSavedWithTip(l10n.coreWallpaperSavedPhotos, l10n.coreDepthEffectMenuTip),
      ]);
    }, variant: TargetPlatformVariant.only(TargetPlatform.iOS));

    testWidgets('a wall without the Depth Effect keeps the plain toast after the guide', (tester) async {
      await download(tester, OperationResult(success: true), guideShown: true);

      expect(toastMessages, <String>[AppLocalizationsEn().coreWallpaperSavedPhotos]);
    }, variant: TargetPlatformVariant.only(TargetPlatform.iOS));

    testWidgets('a denied Photos permission offers Open settings', (tester) async {
      await download(tester, OperationResult(success: false, errorCode: photosPermissionDeniedCode));

      expect(find.text('Open settings'), findsOneWidget);
      expect(find.text('Open Photos'), findsNothing);
    }, variant: TargetPlatformVariant.only(TargetPlatform.iOS));
  });
}
