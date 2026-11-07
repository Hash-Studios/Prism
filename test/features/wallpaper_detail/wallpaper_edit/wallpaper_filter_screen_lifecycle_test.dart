import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:Prism/core/constants/app_constants.dart' as app_constants;
import 'package:Prism/core/platform/pigeon/prism_media_api.g.dart';
import 'package:Prism/core/platform/wallpaper_service.dart';
import 'package:Prism/core/state/app_state.dart' as app_state;
import 'package:Prism/core/widgets/menu_button/set_wallpaper_button.dart';
import 'package:Prism/core/widgets/prism/prism_slider.dart';
import 'package:Prism/features/wallpaper_detail/views/pages/wallpaper_filter_screen.dart';
import 'package:Prism/l10n/l10n.dart';
import 'package:async_wallpaper/async_wallpaper.dart' as aw;
import 'package:async_wallpaper/src/wallpaper_client.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../support/profile_user_fixture.dart';
import '../../../support/wait_for_real_io.dart';

Future<List<int>> _smallPng() async {
  final ui.PictureRecorder recorder = ui.PictureRecorder();
  Canvas(recorder).drawRect(const Rect.fromLTWH(0, 0, 8, 8), Paint()..color = const Color(0xFFFF0000));
  final ui.Picture picture = recorder.endRecording();
  final ui.Image image = await picture.toImage(8, 8);
  picture.dispose();
  final data = (await image.toByteData(format: ui.ImageByteFormat.png))!;
  image.dispose();
  return data.buffer.asUint8List();
}

Future<int> _centreRed(File file) async {
  final ui.Codec codec = await ui.instantiateImageCodec(file.readAsBytesSync());
  try {
    final ui.Image image = (await codec.getNextFrame()).image;
    try {
      final ByteData data = (await image.toByteData())!;
      final int offset = ((image.height ~/ 2) * image.width + image.width ~/ 2) * 4;
      return data.getUint8(offset);
    } finally {
      image.dispose();
    }
  } finally {
    codec.dispose();
  }
}

Future<void> _waitForReady(WidgetTester tester) async {
  await waitForRealIo(tester, () {
    expect(find.text("Couldn't open this wallpaper."), findsNothing);
    final Finder downloadButton = find.ancestor(of: find.byTooltip('Download'), matching: find.byType(IconButton));
    return tester.widget<IconButton>(downloadButton).onPressed != null;
  }, reason: 'decoded source image and enabled Download');
}

Future<void> _waitForFailure(WidgetTester tester) async {
  await waitForRealIo(
    tester,
    () => find.text("Couldn't open this wallpaper").evaluate().isNotEmpty,
    reason: 'source image decode error',
  );
}

Widget _screenHost(String sourcePath) => MaterialApp(
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  supportedLocales: AppLocalizations.supportedLocales,
  home: WallpaperFilterScreen(filePath: sourcePath),
);

class _PreviewWallpaperClient implements WallpaperClient {
  @override
  Future<aw.LiveWallpaperScreens> getLiveWallpaperScreens() async => const aw.LiveWallpaperScreens();

  final List<aw.StaticWallpaperRequest> requests = <aw.StaticWallpaperRequest>[];

  @override
  Future<aw.WallpaperCapabilities> getCapabilities() async => const aw.WallpaperCapabilities(
    supportsStaticWallpaper: true,
    supportsHomeWallpaper: true,
    supportsLockWallpaper: true,
    supportsBothWallpapers: true,
  );

  @override
  Future<aw.WallpaperOperationResult> applyWallpaper(aw.StaticWallpaperRequest request) async {
    requests.add(request);
    return aw.WallpaperOperationResult(
      status: aw.WallpaperOperationStatus.previewOpened,
      requestedTarget: request.target,
    );
  }

  @override
  Future<aw.WallpaperOperationResult> prepareVideoWallpaper(aw.VideoWallpaperRequest request) =>
      throw UnimplementedError();

  @override
  Future<aw.WallpaperOperationResult> openLiveWallpaperPreview(aw.VideoWallpaperRequest request) =>
      throw UnimplementedError();

  @override
  Future<aw.WallpaperOperationResult> applyOpenGlWallpaper(aw.OpenGlLiveWallpaperRequest request) =>
      throw UnimplementedError();
}

/// Refuses the lock screen as some phones (Xiaomi, MIUI) do, and opens the phone's own screen for the system cropper.
class _LockRefusingClient extends _PreviewWallpaperClient {
  @override
  Future<aw.WallpaperOperationResult> applyWallpaper(aw.StaticWallpaperRequest request) async {
    requests.add(request);
    final bool systemScreen = request.strategy == aw.WallpaperApplyStrategy.systemCropper;
    return aw.WallpaperOperationResult(
      status: systemScreen ? aw.WallpaperOperationStatus.awaitingUserConfirmation : aw.WallpaperOperationStatus.failed,
      requestedTarget: request.target,
      errorCode: systemScreen ? null : 'wallpaper-apply-failed',
    );
  }
}

class _DeferredLockRefusingClient extends _LockRefusingClient {
  final Completer<void> allowFailure = Completer<void>();

  @override
  Future<aw.WallpaperOperationResult> applyWallpaper(aw.StaticWallpaperRequest request) async {
    final Future<aw.WallpaperOperationResult> result = super.applyWallpaper(request);
    await allowFailure.future;
    return result;
  }
}

Future<File> _startLockFailure(WidgetTester tester, _LockRefusingClient client) async {
  tester.view.physicalSize = const Size(800, 1200);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  final Directory directory = Directory.systemTemp.createTempSync('wallpaper_filter_pending_');
  addTearDown(() => directory.deleteSync(recursive: true));
  final File source = File('${directory.path}/source.png')..writeAsBytesSync((await tester.runAsync(_smallPng))!);
  app_state.prismUser = profileUser(premium: true);
  addTearDown(() => app_state.prismUser = app_constants.createGuestPrismUser());
  aw.AsyncWallpaper.debugSetClient(client);
  addTearDown(aw.AsyncWallpaper.debugResetClient);
  final originalOpener = SetWallpaperFlow.screenOpener;
  SetWallpaperFlow.screenOpener = (context, request) async => const SetWallpaperChoice(WallpaperTarget.lock);
  addTearDown(() => SetWallpaperFlow.screenOpener = originalOpener);
  const MethodChannel pathProviderChannel = MethodChannel('plugins.flutter.io/path_provider');
  const MethodChannel toastChannel = MethodChannel('PonnamKarthik/fluttertoast');
  tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(pathProviderChannel, (_) async => directory.path);
  tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(toastChannel, (_) async => true);
  addTearDown(() {
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(pathProviderChannel, null);
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(toastChannel, null);
  });
  await tester.pumpWidget(_screenHost(source.path));
  await _waitForReady(tester);
  await tester.tap(find.text('AddictiveBlue'));
  await tester.pump();
  await tester.tap(find.byTooltip('Set as wallpaper'));
  await waitForRealIo(tester, () => client.requests.isNotEmpty, reason: 'initial native lock screen request');
  return File(client.requests.first.source.filePath!);
}

Future<void> _openPhoneFallback(WidgetTester tester) async {
  await waitForRealIo(tester, () => find.text('Set with phone').evaluate().isNotEmpty, reason: 'phone fallback action');
  await tester.pump(const Duration(milliseconds: 500));
  await tester.tap(find.text('Set with phone'));
  await tester.pump();
}

void main() {
  testWidgets('retry recovers a moved image and holding the preview compares the original', (tester) async {
    final directory = Directory.systemTemp.createTempSync('wallpaper_filter_retry_');
    final source = File('${directory.path}/source.png');
    addTearDown(() => directory.deleteSync(recursive: true));
    await tester.pumpWidget(_screenHost(source.path));
    await _waitForFailure(tester);
    source.writeAsBytesSync((await tester.runAsync(_smallPng))!);

    await tester.tap(find.text('Try again'));
    await _waitForReady(tester);
    expect(find.text("Couldn't open this wallpaper"), findsNothing);
    await tester.tap(find.text('Addictive Blue'));
    await tester.pump();
    final preview = find.descendant(of: find.byType(AspectRatio).first, matching: find.byType(Image)).first;
    final gesture = await tester.startGesture(tester.getCenter(preview));
    await tester.pump(const Duration(milliseconds: 600));
    expect(find.text('Original'), findsNWidgets(2));
    await gesture.up();
    await tester.pump();
    expect(find.text('Original'), findsOneWidget);
    expect(find.byType(ImageFiltered), findsWidgets);
    await tester.tap(find.byTooltip('Reset'));
    await tester.pump();
    final reset = find.ancestor(of: find.byTooltip('Reset'), matching: find.byType(IconButton));
    expect(tester.widget<IconButton>(reset).onPressed, isNull);
  });

  testWidgets('does not offer export while the source image cannot be decoded', (tester) async {
    final Directory directory = Directory.systemTemp.createTempSync('wallpaper_filter_test_');
    final File source = File('${directory.path}/invalid.img');
    source.writeAsBytesSync(<int>[1, 2, 3]);
    addTearDown(() => directory.deleteSync(recursive: true));

    await tester.pumpWidget(_screenHost(source.path));
    await _waitForFailure(tester);

    final Finder downloadButton = find.ancestor(of: find.byTooltip('Download'), matching: find.byType(IconButton));
    final IconButton download = tester.widget<IconButton>(downloadButton);
    expect(download.onPressed, isNull);
  });

  testWidgets('unsupported renderers explain the disabled lightness control', (tester) async {
    final directory = Directory.systemTemp.createTempSync('wallpaper_filter_test_');
    final source = File('${directory.path}/source.png');
    source.writeAsBytesSync((await tester.runAsync(_smallPng))!);
    addTearDown(() => directory.deleteSync(recursive: true));

    await tester.pumpWidget(_screenHost(source.path));
    await _waitForReady(tester);
    await tester.tap(find.text('Adjust'));
    await tester.pumpAndSettle();

    final row = find.ancestor(of: find.text('Lightness'), matching: find.byType(Row)).last;
    final sliderFinder = find.descendant(of: row, matching: find.byType(Slider));
    final slider = tester.widget<Slider>(sliderFinder);
    expect(slider.onChanged, isNull);
    expect(find.text('Lightness is unavailable on this device.'), findsOneWidget);
    expect(
      tester.getSemantics(find.descendant(of: row, matching: find.byType(PrismSlider))).label,
      contains('Lightness'),
    );
  }, skip: ui.ImageFilter.isShaderFilterSupported);

  testWidgets('adjustment callbacks keep edits from the same build', (tester) async {
    final Directory directory = Directory.systemTemp.createTempSync('wallpaper_filter_test_');
    final File source = File('${directory.path}/source.png');
    source.writeAsBytesSync((await tester.runAsync(_smallPng))!);
    addTearDown(() => directory.deleteSync(recursive: true));

    await tester.pumpWidget(_screenHost(source.path));
    await _waitForReady(tester);
    await tester.tap(find.text('Adjust'));
    await tester.pumpAndSettle();

    Finder sliderFor(String label) {
      final Finder row = find.ancestor(of: find.text(label), matching: find.byType(Row)).last;
      return find.descendant(of: row, matching: find.byType(Slider));
    }

    final Slider blur = tester.widget<Slider>(sliderFor('Blur'));
    final Slider hue = tester.widget<Slider>(sliderFor('Hue'));
    blur.onChanged!(50);
    hue.onChanged!(90);
    await tester.pump();

    expect(tester.widget<Slider>(sliderFor('Blur')).value, 50);
    expect(tester.widget<Slider>(sliderFor('Hue')).value, 90);

    final Slider saturation = tester.widget<Slider>(sliderFor('Saturation'));
    final Finder hueRow = find.ancestor(of: find.text('Hue'), matching: find.byType(Row)).last;
    final GestureDetector hueReset = tester.widget<GestureDetector>(
      find.descendant(of: hueRow, matching: find.byType(GestureDetector)).first,
    );
    saturation.onChanged!(25);
    hueReset.onDoubleTap!();
    await tester.pump();

    expect(tester.widget<Slider>(sliderFor('Saturation')).value, 25);
    expect(tester.widget<Slider>(sliderFor('Hue')).value, 0);

    await tester.scrollUntilVisible(
      find.text('Brightness'),
      100,
      scrollable: find.descendant(of: find.byType(ListView).last, matching: find.byType(Scrollable)).first,
    );
    final Slider brightness = tester.widget<Slider>(sliderFor('Brightness'));
    final Finder resetButton = find.ancestor(of: find.byTooltip('Reset'), matching: find.byType(IconButton));
    final IconButton reset = tester.widget<IconButton>(resetButton);
    reset.onPressed!();
    brightness.onChanged!(40);
    await tester.pump();

    expect(tester.widget<Slider>(sliderFor('Brightness')).value, 40);
    final Finder adjustmentsScrollable = find
        .descendant(of: find.byType(ListView).last, matching: find.byType(Scrollable))
        .first;
    tester.state<ScrollableState>(adjustmentsScrollable).position.jumpTo(0);
    await tester.pumpAndSettle();

    expect(tester.widget<Slider>(sliderFor('Blur')).value, 0);
    expect(tester.widget<Slider>(sliderFor('Hue')).value, 0);
    expect(tester.widget<Slider>(sliderFor('Saturation')).value, 0);
  });

  testWidgets('locks edits through export and removes its temp file after native save completes', (tester) async {
    final Directory directory = Directory.systemTemp.createTempSync('wallpaper_filter_test_');
    final File source = File('${directory.path}/source.png');
    source.writeAsBytesSync((await tester.runAsync(_smallPng))!);
    addTearDown(() => directory.deleteSync(recursive: true));

    app_state.prismUser = profileUser(premium: true);
    addTearDown(() => app_state.prismUser = app_constants.createGuestPrismUser());

    final Completer<void> allowSave = Completer<void>();
    final Completer<SaveMediaRequest> requestReceived = Completer<SaveMediaRequest>();
    const MethodChannel pathProviderChannel = MethodChannel('plugins.flutter.io/path_provider');
    const MethodChannel toastChannel = MethodChannel('PonnamKarthik/fluttertoast');
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(pathProviderChannel, (_) async => directory.path);
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(toastChannel, (_) => Completer<bool>().future);
    addTearDown(() {
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(pathProviderChannel, null);
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(toastChannel, null);
    });
    const String channelName = 'dev.flutter.pigeon.Prism.PrismMediaHostApi.saveMedia';
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMessageHandler(channelName, (
      message,
    ) async {
      final Object? decoded = PrismMediaHostApi.pigeonChannelCodec.decodeMessage(message);
      if (decoded is! List<Object?>) throw StateError('Unexpected saveMedia request');
      final List<Object?> args = decoded;
      final SaveMediaRequest request = args[0]! as SaveMediaRequest;
      requestReceived.complete(request);
      await allowSave.future;
      return PrismMediaHostApi.pigeonChannelCodec.encodeMessage(<Object?>[OperationResult(success: true)]);
    });
    addTearDown(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMessageHandler(channelName, null);
    });

    await tester.pumpWidget(_screenHost(source.path));
    await _waitForReady(tester);
    final Finder downloadButton = find.ancestor(of: find.byTooltip('Download'), matching: find.byType(IconButton));
    expect(tester.widget<IconButton>(downloadButton).onPressed, isNotNull);
    await tester.tap(find.text('Adjust'));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.text('Brightness'),
      100,
      scrollable: find.descendant(of: find.byType(ListView).last, matching: find.byType(Scrollable)).first,
    );
    final brightnessRow = find.ancestor(of: find.text('Brightness'), matching: find.byType(Row)).last;
    final Slider brightness = tester.widget<Slider>(find.descendant(of: brightnessRow, matching: find.byType(Slider)));
    brightness.onChanged!(20);
    await tester.pump();

    await tester.tap(find.byTooltip('Download'));
    brightness.onChanged!(-100);
    await tester.pump();
    await waitForRealIo(tester, () => requestReceived.isCompleted, reason: 'native save receives edited export');
    final SaveMediaRequest request = await requestReceived.future;
    await tester.pump();

    final Finder resetFinder = find.ancestor(of: find.byTooltip('Reset'), matching: find.byType(IconButton));
    expect(tester.widget<IconButton>(resetFinder).onPressed, isNull);
    expect(File(request.link).existsSync(), isTrue);
    expect(await tester.runAsync(() => _centreRed(File(request.link))), 255);

    allowSave.complete();
    await waitForRealIo(
      tester,
      () => !File(request.link).parent.existsSync(),
      reason: 'saved export directory cleanup',
    );

    expect(File(request.link).existsSync(), isFalse);
    expect(Directory(File(request.link).parent.path).existsSync(), isFalse);
    await tester.pump(const Duration(seconds: 1));
  });

  testWidgets('source replacement during native save never deletes the old source', (tester) async {
    final Directory directory = Directory.systemTemp.createTempSync('wallpaper_filter_source_replace_');
    addTearDown(() => directory.deleteSync(recursive: true));
    final List<int> png = (await tester.runAsync(_smallPng))!;
    final File first = File('${directory.path}/first.png')..writeAsBytesSync(png);
    final File second = File('${directory.path}/second.png')..writeAsBytesSync(png);
    app_state.prismUser = profileUser(premium: true);
    addTearDown(() => app_state.prismUser = app_constants.createGuestPrismUser());

    final Completer<void> allowSave = Completer<void>();
    final Completer<void> saveStarted = Completer<void>();
    const MethodChannel pathProviderChannel = MethodChannel('plugins.flutter.io/path_provider');
    const MethodChannel toastChannel = MethodChannel('PonnamKarthik/fluttertoast');
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(pathProviderChannel, (_) async => directory.path);
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(toastChannel, (_) => Completer<bool>().future);
    addTearDown(() {
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(pathProviderChannel, null);
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(toastChannel, null);
    });
    const String channelName = 'dev.flutter.pigeon.Prism.PrismMediaHostApi.saveMedia';
    tester.binding.defaultBinaryMessenger.setMockMessageHandler(channelName, (message) async {
      saveStarted.complete();
      await allowSave.future;
      return PrismMediaHostApi.pigeonChannelCodec.encodeMessage(<Object?>[OperationResult(success: true)]);
    });
    addTearDown(() {
      tester.binding.defaultBinaryMessenger.setMockMessageHandler(channelName, null);
    });

    await tester.pumpWidget(_screenHost(first.path));
    await _waitForReady(tester);
    await tester.tap(find.byTooltip('Download'));
    await waitForRealIo(tester, () => saveStarted.isCompleted, reason: 'save starts with source file');
    await tester.pumpWidget(_screenHost(second.path));
    allowSave.complete();
    await _waitForReady(tester);

    expect(first.existsSync(), isTrue);
    expect(second.existsSync(), isTrue);
  });

  testWidgets('removes the edited export after a pending wallpaper preview', (tester) async {
    tester.view.physicalSize = const Size(800, 1200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final Directory directory = Directory.systemTemp.createTempSync('wallpaper_filter_cropper_');
    final File source = File('${directory.path}/source.png');
    source.writeAsBytesSync((await tester.runAsync(_smallPng))!);
    addTearDown(() => directory.deleteSync(recursive: true));

    app_state.prismUser = profileUser(premium: true);
    addTearDown(() => app_state.prismUser = app_constants.createGuestPrismUser());

    final _PreviewWallpaperClient client = _PreviewWallpaperClient();
    aw.AsyncWallpaper.debugSetClient(client);
    addTearDown(aw.AsyncWallpaper.debugResetClient);

    final List<SetScreenRequest> opened = <SetScreenRequest>[];
    final originalOpener = SetWallpaperFlow.screenOpener;
    SetWallpaperFlow.screenOpener = (context, request) async {
      opened.add(request);
      return const SetWallpaperChoice(WallpaperTarget.home);
    };
    addTearDown(() => SetWallpaperFlow.screenOpener = originalOpener);

    const MethodChannel pathProviderChannel = MethodChannel('plugins.flutter.io/path_provider');
    const MethodChannel toastChannel = MethodChannel('PonnamKarthik/fluttertoast');
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(pathProviderChannel, (_) async => directory.path);
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(toastChannel, (_) async => true);
    addTearDown(() {
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(pathProviderChannel, null);
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(toastChannel, null);
    });

    await tester.pumpWidget(_screenHost(source.path));
    await _waitForReady(tester);
    await tester.tap(find.text('Addictive Blue'));
    await tester.pump();
    await tester.tap(find.byTooltip('Set as wallpaper'));
    await waitForRealIo(
      tester,
      () => client.requests.isNotEmpty && !File(client.requests.single.source.filePath!).existsSync(),
      reason: 'wallpaper preview request and edited export cleanup',
    );

    expect(opened, hasLength(1));
    expect(opened.single.onAdjust, isNotNull);
    expect(client.requests, hasLength(1));
    expect(opened.single.url, client.requests.single.source.filePath);
    expect(client.requests.single.source.filePath, isNotNull);
    expect(File(client.requests.single.source.filePath!).existsSync(), isFalse);
    await tester.pump(const Duration(seconds: 1));
  }, variant: TargetPlatformVariant.only(TargetPlatform.android));

  testWidgets('a refused lock screen keeps the edit for the phone own wallpaper screen (#545)', (tester) async {
    tester.view.physicalSize = const Size(800, 1200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final Directory directory = Directory.systemTemp.createTempSync('wallpaper_filter_lock_');
    final File source = File('${directory.path}/source.png');
    source.writeAsBytesSync((await tester.runAsync(_smallPng))!);
    addTearDown(() => directory.deleteSync(recursive: true));

    app_state.prismUser = profileUser(premium: true);
    addTearDown(() => app_state.prismUser = app_constants.createGuestPrismUser());

    final _LockRefusingClient client = _LockRefusingClient();
    aw.AsyncWallpaper.debugSetClient(client);
    addTearDown(aw.AsyncWallpaper.debugResetClient);

    final originalOpener = SetWallpaperFlow.screenOpener;
    SetWallpaperFlow.screenOpener = (context, request) async => const SetWallpaperChoice(WallpaperTarget.lock);
    addTearDown(() => SetWallpaperFlow.screenOpener = originalOpener);

    final List<bool> exportExistedAtCrop = <bool>[];
    const MethodChannel pathProviderChannel = MethodChannel('plugins.flutter.io/path_provider');
    const MethodChannel toastChannel = MethodChannel('PonnamKarthik/fluttertoast');
    const MethodChannel cropChannel = MethodChannel('prism/wallpaper_crop');
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(pathProviderChannel, (_) async => directory.path);
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(toastChannel, (_) async => true);
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(cropChannel, (MethodCall call) async {
      exportExistedAtCrop.add(File(call.arguments as String).existsSync());
      return 'content://com.hash.prism.wallpaper_crop/wallpaper_crop/edit.png';
    });
    addTearDown(() {
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(pathProviderChannel, null);
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(toastChannel, null);
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(cropChannel, null);
    });

    await tester.pumpWidget(_screenHost(source.path));
    await _waitForReady(tester);
    await tester.tap(find.text('AddictiveBlue'));
    await tester.pump();
    await tester.tap(find.byTooltip('Set as wallpaper'));
    await waitForRealIo(
      tester,
      () => find
          .text("Couldn't set the lock screen. Your phone's own wallpaper screen can set it.")
          .evaluate()
          .isNotEmpty,
      reason: 'lock screen fallback snackbar',
    );
    final String exportPath = client.requests.first.source.filePath!;
    expect(File(exportPath).existsSync(), isTrue);

    await tester.pump(const Duration(milliseconds: 500));
    await tester.tap(find.text('Set with phone'));
    await waitForRealIo(
      tester,
      () => client.requests.any((request) => request.strategy == aw.WallpaperApplyStrategy.systemCropper),
      reason: 'system cropper request',
    );

    expect(exportExistedAtCrop, <bool>[true]);
    expect(client.requests.last.target, aw.WallpaperTarget.lock);
    expect(client.requests.last.source.contentUri, startsWith('content://'));
    await tester.pump(const Duration(seconds: 1));
  }, variant: TargetPlatformVariant.only(TargetPlatform.android));

  testWidgets('cleans up when the editor closes before the initial lock failure', (tester) async {
    final _DeferredLockRefusingClient client = _DeferredLockRefusingClient();
    final File export = await _startLockFailure(tester, client);
    expect(export.existsSync(), isTrue);
    await tester.pumpWidget(const SizedBox());
    client.allowFailure.complete();
    await waitForRealIo(
      tester,
      () => !export.parent.existsSync(),
      timeout: const Duration(seconds: 2),
      reason: 'unmounted editor releases refused export',
    );
    await tester.pump(const Duration(seconds: 1));
  }, variant: TargetPlatformVariant.only(TargetPlatform.android));

  testWidgets('keeps the edit until a pending phone crop request finishes after disposal', (tester) async {
    final _LockRefusingClient client = _LockRefusingClient();
    final Completer<void> allowCrop = Completer<void>();
    final Completer<void> cropStarted = Completer<void>();
    bool? exportExistedAtCrop;
    const MethodChannel cropChannel = MethodChannel('prism/wallpaper_crop');
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(cropChannel, (MethodCall call) async {
      cropStarted.complete();
      await allowCrop.future;
      exportExistedAtCrop = File(call.arguments as String).existsSync();
      return 'content://com.hash.prism.wallpaper_crop/wallpaper_crop/edit.png';
    });
    addTearDown(() => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(cropChannel, null));
    final File export = await _startLockFailure(tester, client);
    await _openPhoneFallback(tester);
    await waitForRealIo(tester, () => cropStarted.isCompleted, reason: 'phone crop begins');
    await tester.pumpWidget(const SizedBox());
    // Give any disposal cleanup real I/O time before the native side reads the file.
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 50)));
    allowCrop.complete();
    await waitForRealIo(
      tester,
      () => client.requests.length == 3 && !export.parent.existsSync(),
      reason: 'phone request completes and releases export',
    );
    expect(exportExistedAtCrop, isTrue);
    await tester.pump(const Duration(seconds: 1));
  }, variant: TargetPlatformVariant.only(TargetPlatform.android));

  testWidgets('phone retry locks edits and rejects another export while native work is pending', (tester) async {
    final _LockRefusingClient client = _LockRefusingClient();
    final Completer<void> allowCrop = Completer<void>();
    const MethodChannel cropChannel = MethodChannel('prism/wallpaper_crop');
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(cropChannel, (_) async {
      await allowCrop.future;
      return 'content://com.hash.prism.wallpaper_crop/wallpaper_crop/edit.png';
    });
    addTearDown(() => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(cropChannel, null));
    await _startLockFailure(tester, client);
    await waitForRealIo(
      tester,
      () => find.text('Set with phone').evaluate().isNotEmpty,
      reason: 'phone fallback action',
    );
    await tester.pump(const Duration(milliseconds: 500));
    final Finder setButton = find.ancestor(of: find.byTooltip('Set as wallpaper'), matching: find.byType(IconButton));
    final VoidCallback startAnotherExport = tester.widget<IconButton>(setButton).onPressed!;
    await _openPhoneFallback(tester);
    final Finder reset = find.ancestor(of: find.byTooltip('Reset'), matching: find.byType(IconButton));
    final bool editsLocked = tester.widget<IconButton>(reset).onPressed == null;
    startAnotherExport();
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 50)));
    await tester.pump();
    final int requestsBeforeCrop = client.requests.length;
    allowCrop.complete();
    await waitForRealIo(tester, () => client.requests.length >= 3, reason: 'phone retry completes');
    await tester.pumpWidget(const SizedBox());
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 50)));
    expect(editsLocked, isTrue);
    expect(requestsBeforeCrop, 2);
    await tester.pump(const Duration(seconds: 1));
  }, variant: TargetPlatformVariant.only(TargetPlatform.android));
}
