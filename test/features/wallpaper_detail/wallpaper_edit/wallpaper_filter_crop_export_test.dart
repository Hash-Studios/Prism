import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:Prism/core/analytics/analytics_runtime.dart';
import 'package:Prism/core/constants/app_constants.dart' as app_constants;
import 'package:Prism/core/platform/pigeon/prism_media_api.g.dart';
import 'package:Prism/core/state/app_state.dart' as app_state;
import 'package:Prism/core/widgets/menu_button/set_wallpaper_button.dart';
import 'package:Prism/features/wallpaper_detail/views/pages/wallpaper_filter_screen.dart';
import 'package:Prism/features/wallpaper_detail/views/widgets/crop_frame_view.dart';
import 'package:Prism/l10n/generated/app_localizations_en.dart';
import 'package:Prism/l10n/l10n.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:share_plus/share_plus.dart';

import '../../../support/fake_app_analytics.dart';
import '../../../support/profile_user_fixture.dart';
import '../../../support/wait_for_real_io.dart';

const String _mediaChannel = 'dev.flutter.pigeon.Prism.PrismMediaHostApi.saveMedia';
const MethodChannel _toastChannel = MethodChannel('PonnamKarthik/fluttertoast');
const MethodChannel _pathProviderChannel = MethodChannel('plugins.flutter.io/path_provider');
const String _timeoutMessage = 'Saving took too long. Try a smaller crop or fewer filters.';
const String _tinyJpeg =
    '/9j/4AAQSkZJRgABAgAAAQABAAD//gAQTGF2YzYwLjMxLjEwMgD/2wBDAAgEBAQEBAUFBQUFBQYGBgYGBgYGBgYHBwcICAgHBwcGBgcH'
    'CAgICAkJCQgICAgJCQoKCgwMCwsODg4RERT/xACBAAEBAQEBAAAAAAAAAAAAAAAABgUIBwEBAQEBAQEBAQAAAAAAAAAAAAcGBQgDAgEQAQAABwEA'
    'AAAAAAAAAAAAAACj42RlFhfkpBEAAQEDCAYIBgMBAAAAAAAAAAIEAwE1MnJ0sbMFGJQW0RETEhdVVmVkohSjgQcVMTQhCEFRBv/AABEIACgA'
    'UAMBEgACEgADEgD/2gAMAwEAAhEDEQA/AIsZQF/AAAAAAAAAH8VMVRVYFTFUVWHxxGT2urvrtQxGT2urvrtR6SMvGcqkq0RnKpKtPDzV+c'
    '311rvlhq/Ob6613ywAPwAAAAAAAADx/KqOPJY6+ZZo9pHmjJ2lXPT2YWPUC9ITsJwbGVUceSx0oyzR7SPNGTtKuUfMLHqBekJ2E4NjKq'
    'OPJY6UZZo9pHmjJ2lXKPmFj1AvSE7CcGxlVHHksdKMs0e0jzRk7SrlHzCx6gXpCdhODYyqjjyWOkjT/GuLhmfvdY1x5HTxe70yf3ypjH'
    '/SqYnJrbVn92oor/5/xaHLxz9BWnioU73+oh+ueHLv+39bydQnIpJtOn9c3PydKmeIWn/ovTtTQ6izwjw3z1G/m+/KuMN/xOZicpNtZf3ij'
    'kvfkbxnz599d5eM9eP+XgzeKqK93w3m+hNRRTYTOubn5OlTOhrP4bzHIMB0E9/eyb8mdc3PydKmdfWfw3mOQYDoJ7+9k35M65ufk6VM6'
    '+s/hvMcgwHQT397JvyZ1zc/J0qZ19Z/DeY5BgOgnv72TfnHQ9/gy4AAAAAAAAA+GJya21Z/dqGJya21Z/dqEJyKSbRCcikm07FHg7E5Sbay'
    '/vFDE5Sbay/vFGohNRRTYITUUU2AfAAAAAAAAAAH/9k=';

class _Decoded {
  const _Decoded(this.width, this.height, this.centre);

  final int width;
  final int height;

  /// RGBA of the centre pixel.
  final List<int> centre;

  bool get isRed => centre[0] > 200 && centre[1] < 50 && centre[2] < 50;

  bool get isBlue => centre[0] < 50 && centre[1] < 50 && centre[2] > 200;
}

Future<Uint8List> _sourcePng() async {
  final ui.PictureRecorder recorder = ui.PictureRecorder();
  final Canvas canvas = Canvas(recorder);
  canvas.drawRect(const Rect.fromLTWH(0, 0, 40, 40), Paint()..color = const Color(0xFFFF0000));
  canvas.drawRect(const Rect.fromLTWH(0, 40, 40, 40), Paint()..color = const Color(0xFF0000FF));
  final ui.Picture picture = recorder.endRecording();
  final ui.Image image = await picture.toImage(40, 80);
  try {
    final ByteData data = (await image.toByteData(format: ui.ImageByteFormat.png))!;
    return data.buffer.asUint8List();
  } finally {
    image.dispose();
    picture.dispose();
  }
}

Future<_Decoded> _decode(WidgetTester tester, Uint8List bytes) async {
  final _Decoded? decoded = await tester.runAsync(() async {
    final ui.Codec codec = await ui.instantiateImageCodec(bytes);
    try {
      final ui.Image image = (await codec.getNextFrame()).image;
      try {
        final ByteData data = (await image.toByteData())!;
        final int offset = ((image.height ~/ 2) * image.width + image.width ~/ 2) * 4;
        return _Decoded(image.width, image.height, <int>[for (int i = 0; i < 4; i++) data.getUint8(offset + i)]);
      } finally {
        image.dispose();
      }
    } finally {
      codec.dispose();
    }
  });
  return decoded!;
}

Finder _downloadButton() => find.ancestor(of: find.byTooltip('Download'), matching: find.byType(IconButton));

Widget _screenHost(String sourcePath) => MaterialApp(
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  supportedLocales: AppLocalizations.supportedLocales,
  home: WallpaperFilterScreen(filePath: sourcePath),
);

/// Waits until the export or action has finished and the editor is idle again. Real IO only advances inside
/// [waitForRealIo], so a plain pumpAndSettle would spin on the busy spinner.
Future<void> _waitForIdle(WidgetTester tester) async {
  await waitForRealIo(tester, () {
    final Finder download = _downloadButton();
    return find.byType(CircularProgressIndicator).evaluate().isEmpty &&
        download.evaluate().isNotEmpty &&
        tester.widget<IconButton>(download).onPressed != null;
  }, reason: 'export finished and editor idle');
  await tester.pumpAndSettle();
}

Future<void> _waitForEditor(WidgetTester tester) async {
  await waitForRealIo(tester, () {
    final Finder download = _downloadButton();
    return download.evaluate().isNotEmpty && tester.widget<IconButton>(download).onPressed != null;
  }, reason: 'editor ready with enabled Download');
  await tester.pumpAndSettle();
}

Future<void> _cropSquare(WidgetTester tester) async {
  await tester.tap(find.text('Crop'));
  await tester.pumpAndSettle();
  await tester.tap(find.text('1:1'));
  await tester.pumpAndSettle();
}

Future<void> _dragFrame(WidgetTester tester, Offset total) async {
  final TestGesture gesture = await tester.startGesture(tester.getCenter(find.byType(CropFrameView)));
  for (int i = 0; i < 4; i++) {
    await gesture.moveBy(total / 4);
    await tester.pump();
  }
  await gesture.up();
  await tester.pumpAndSettle();
}

class _Saved {
  const _Saved(this.path, this.bytes);

  final String path;
  final Uint8List bytes;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory directory;
  late List<_Saved> saved;
  late List<Object?> toastCalls;

  setUp(() {
    directory = Directory.systemTemp.createTempSync('wallpaper_filter_crop_export_');
    saved = <_Saved>[];
    toastCalls = <Object?>[];
    AnalyticsRuntime.instance = FakeAppAnalytics();
    app_state.prismUser = profileUser(premium: true);
    final TestDefaultBinaryMessenger messenger = TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(_pathProviderChannel, (_) async => directory.path);
    messenger.setMockMethodCallHandler(_toastChannel, (call) {
      toastCalls.add(call.arguments);
      // fluttertoast starts a 1 s timer after its reply. A pending reply keeps that timer from outliving the test.
      return Completer<bool>().future;
    });
    messenger.setMockMessageHandler(_mediaChannel, (message) async {
      final List<Object?> arguments = PrismMediaHostApi.pigeonChannelCodec.decodeMessage(message)! as List<Object?>;
      final SaveMediaRequest request = arguments.single! as SaveMediaRequest;
      // The screen deletes the edited file once the save returns, so keep its bytes now.
      saved.add(_Saved(request.link, File(request.link).readAsBytesSync()));
      return PrismMediaHostApi.pigeonChannelCodec.encodeMessage(<Object?>[OperationResult(success: true)]);
    });
  });

  tearDown(() {
    AnalyticsRuntime.reset();
    app_state.prismUser = app_constants.createGuestPrismUser();
    final TestDefaultBinaryMessenger messenger = TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(_pathProviderChannel, null);
    messenger.setMockMethodCallHandler(_toastChannel, null);
    messenger.setMockMessageHandler(_mediaChannel, null);
    directory.deleteSync(recursive: true);
  });

  Future<File> openEditor(WidgetTester tester, {String fileName = 'source.png', List<int>? sourceBytes}) async {
    tester.view.physicalSize = const Size(800, 1200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final List<int> bytes = sourceBytes ?? (await tester.runAsync(_sourcePng))!;
    final File source = File('${directory.path}/$fileName')..writeAsBytesSync(bytes);
    await tester.pumpWidget(_screenHost(source.path));
    await _waitForEditor(tester);
    return source;
  }

  testWidgets('download saves the cropped file at crop size', (tester) async {
    await openEditor(tester);
    await _cropSquare(tester);

    await tester.tap(find.byTooltip('Download'));
    await waitForRealIo(tester, () => saved.isNotEmpty, reason: 'saveMedia called');
    await _waitForIdle(tester);

    final _Decoded decoded = await _decode(tester, saved.single.bytes);
    expect(decoded.width, 40);
    expect(decoded.height, 40);
  });

  testWidgets('download after dragging the frame up saves the red top half', (tester) async {
    await openEditor(tester);
    await _cropSquare(tester);
    await _dragFrame(tester, const Offset(0, -2000));

    await tester.tap(find.byTooltip('Download'));
    await waitForRealIo(tester, () => saved.isNotEmpty, reason: 'saveMedia called');
    await _waitForIdle(tester);

    final _Decoded decoded = await _decode(tester, saved.single.bytes);
    expect(decoded.width, 40);
    expect(decoded.height, 40);
    expect(decoded.isRed, isTrue, reason: 'centre pixel ${decoded.centre}');
  });

  testWidgets('download after dragging the frame down saves the blue bottom half', (tester) async {
    await openEditor(tester);
    await _cropSquare(tester);
    await _dragFrame(tester, const Offset(0, 2000));

    await tester.tap(find.byTooltip('Download'));
    await waitForRealIo(tester, () => saved.isNotEmpty, reason: 'saveMedia called');
    await _waitForIdle(tester);

    final _Decoded decoded = await _decode(tester, saved.single.bytes);
    expect(decoded.width, 40);
    expect(decoded.height, 40);
    expect(decoded.isBlue, isTrue, reason: 'centre pixel ${decoded.centre}');
  });

  testWidgets('set as wallpaper passes the cropped file to the set screen', (tester) async {
    final originalScreenOpener = SetWallpaperFlow.screenOpener;
    addTearDown(() => SetWallpaperFlow.screenOpener = originalScreenOpener);
    final List<String> requestUrls = <String>[];
    final List<Uint8List> screenBytes = <Uint8List>[];
    final List<SetScreenRequest> requests = <SetScreenRequest>[];
    SetWallpaperFlow.screenOpener = (context, request) async {
      requests.add(request);
      requestUrls.add(request.url);
      screenBytes.add(File(request.url).readAsBytesSync());
      return null;
    };

    await openEditor(tester);
    await _cropSquare(tester);

    await tester.tap(find.byTooltip('Set as wallpaper'));
    await waitForRealIo(tester, () => requests.isNotEmpty, reason: 'set screen opened');
    await _waitForIdle(tester);

    final _Decoded decoded = await _decode(tester, screenBytes.single);
    expect(decoded.width, 40);
    expect(decoded.height, 40);
    expect(requests.single.onAdjust, isNotNull);
  });

  testWidgets('adjust in the set screen opens the studio with the cropped file', (tester) async {
    final originalScreenOpener = SetWallpaperFlow.screenOpener;
    final originalStudioOpener = SetWallpaperFlow.studioOpener;
    addTearDown(() {
      SetWallpaperFlow.screenOpener = originalScreenOpener;
      SetWallpaperFlow.studioOpener = originalStudioOpener;
    });
    final List<String> requestUrls = <String>[];
    final List<String> studioUrls = <String>[];
    final List<Uint8List> studioBytes = <Uint8List>[];
    SetWallpaperFlow.screenOpener = (context, request) async {
      requestUrls.add(request.url);
      await request.onAdjust!(context);
      return null;
    };
    SetWallpaperFlow.studioOpener = (context, {required url, thumbnailUrl, entryPoint}) async {
      studioUrls.add(url);
      studioBytes.add(File(url).readAsBytesSync());
      return null;
    };

    await openEditor(tester);
    await _cropSquare(tester);

    await tester.tap(find.byTooltip('Set as wallpaper'));
    await waitForRealIo(tester, () => studioUrls.isNotEmpty, reason: 'studio opened');
    await _waitForIdle(tester);

    expect(studioUrls.single, requestUrls.single);
    final _Decoded decoded = await _decode(tester, studioBytes.single);
    expect(decoded.width, 40);
    expect(decoded.height, 40);
  });

  testWidgets('share sends the cropped file at crop size', (tester) async {
    final originalShare = WallpaperFilterScreen.share;
    addTearDown(() => WallpaperFilterScreen.share = originalShare);
    final List<String> sharedPaths = <String>[];
    final List<String?> sharedMimeTypes = <String?>[];
    final List<Uint8List> sharedBytes = <Uint8List>[];
    WallpaperFilterScreen.share = (params) async {
      final String path = params.files!.single.path;
      sharedPaths.add(path);
      sharedMimeTypes.add(params.files!.single.mimeType);
      sharedBytes.add(File(path).readAsBytesSync());
      return const ShareResult('', ShareResultStatus.success);
    };

    await openEditor(tester);
    await _cropSquare(tester);

    await tester.tap(find.byTooltip('Share'));
    await waitForRealIo(tester, () => sharedBytes.isNotEmpty, reason: 'share called');
    await _waitForIdle(tester);

    final _Decoded decoded = await _decode(tester, sharedBytes.single);
    expect(decoded.width, 40);
    expect(decoded.height, 40);
    expect(sharedMimeTypes.single, 'image/png');
  });

  testWidgets('share without any edit sends the source file unchanged', (tester) async {
    final originalShare = WallpaperFilterScreen.share;
    addTearDown(() => WallpaperFilterScreen.share = originalShare);
    final List<String> sharedPaths = <String>[];
    final List<String?> sharedMimeTypes = <String?>[];
    WallpaperFilterScreen.share = (params) async {
      sharedPaths.add(params.files!.single.path);
      sharedMimeTypes.add(params.files!.single.mimeType);
      return const ShareResult('', ShareResultStatus.success);
    };

    final File source = await openEditor(tester, fileName: 'source.img', sourceBytes: base64Decode(_tinyJpeg));

    await tester.tap(find.byTooltip('Share'));
    await waitForRealIo(tester, () => sharedPaths.isNotEmpty, reason: 'share called');
    await _waitForIdle(tester);

    expect(sharedPaths.single, source.path);
    expect(sharedMimeTypes.single, 'image/*');
  });

  testWidgets('a timed-out render blocks duplicate exports until the late render finishes', (tester) async {
    final originalRender = WallpaperFilterScreen.renderFile;
    final originalLimit = WallpaperFilterScreen.exportTimeLimit;
    addTearDown(() {
      WallpaperFilterScreen.renderFile = originalRender;
      WallpaperFilterScreen.exportTimeLimit = originalLimit;
    });
    final Completer<Uint8List> lateRender = Completer<Uint8List>();
    int renderCalls = 0;
    WallpaperFilterScreen.renderFile =
        (path, {required stack, required adjustments, crop, previewPixelShortSide, deviceLongSidePx = 0}) {
          renderCalls++;
          return lateRender.future;
        };
    WallpaperFilterScreen.exportTimeLimit = const Duration(milliseconds: 50);

    await openEditor(tester);
    await _cropSquare(tester);

    await tester.tap(find.byTooltip('Download'));
    await waitForRealIo(
      tester,
      () => toastCalls.any((arguments) => arguments.toString().contains(_timeoutMessage)),
      reason: 'timeout toast',
      pumpDuration: const Duration(milliseconds: 20),
    );
    expect(saved, isEmpty);

    await tester.tap(find.byTooltip('Download'), warnIfMissed: false);
    await tester.pump();
    expect(renderCalls, 1);
    expect(tester.widget<IconButton>(_downloadButton()).onPressed, isNull);

    lateRender.complete((await tester.runAsync(_sourcePng))!);
    await waitForRealIo(
      tester,
      () => _downloadButton().evaluate().isNotEmpty && tester.widget<IconButton>(_downloadButton()).onPressed != null,
      reason: 'Download enabled after late render settles',
      pumpDuration: const Duration(milliseconds: 20),
    );
    expect(renderCalls, 1);
    expect(saved, isEmpty);
    expect(Directory('${directory.path}/prism_edit').existsSync(), isFalse);
  });

  testWidgets('crop alone does not charge a non-premium user', (tester) async {
    app_state.prismUser = profileUser();
    await openEditor(tester);
    await _cropSquare(tester);

    await tester.tap(find.byTooltip('Download'));
    await waitForRealIo(tester, () => saved.isNotEmpty, reason: 'saveMedia called');
    await _waitForIdle(tester);

    final _Decoded decoded = await _decode(tester, saved.single.bytes);
    expect(decoded.width, 40);
    expect(decoded.height, 40);
    expect(find.text(AppLocalizationsEn().wallpaperFilterNeedCoins), findsNothing);
  });
}
