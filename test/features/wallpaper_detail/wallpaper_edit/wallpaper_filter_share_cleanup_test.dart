import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:Prism/core/analytics/analytics_runtime.dart';
import 'package:Prism/core/constants/app_constants.dart' as app_constants;
import 'package:Prism/core/state/app_state.dart' as app_state;
import 'package:Prism/features/wallpaper_detail/domain/entities/crop_spec.dart';
import 'package:Prism/features/wallpaper_detail/views/pages/wallpaper_filter_screen.dart';
import 'package:Prism/features/wallpaper_detail/views/wallpaper_edit/wallpaper_filters.dart';
import 'package:Prism/l10n/l10n.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:share_plus/share_plus.dart';

import '../../../support/fake_app_analytics.dart';
import '../../../support/profile_user_fixture.dart';
import '../../../support/wait_for_real_io.dart';

const MethodChannel _pathProviderChannel = MethodChannel('plugins.flutter.io/path_provider');
const MethodChannel _toastChannel = MethodChannel('PonnamKarthik/fluttertoast');

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

Widget _screenHost(String path) => MaterialApp(
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  supportedLocales: AppLocalizations.supportedLocales,
  home: WallpaperFilterScreen(filePath: path),
);

Future<void> _openEditor(WidgetTester tester, String path) async {
  tester.view.physicalSize = const Size(800, 1200);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(_screenHost(path));
  await waitForRealIo(tester, () {
    final Finder download = find.ancestor(of: find.byTooltip('Download'), matching: find.byType(IconButton));
    return download.evaluate().isNotEmpty && tester.widget<IconButton>(download).onPressed != null;
  }, reason: 'source image decoded and editor ready');
  await tester.pumpAndSettle();
}

Future<void> _cropSquare(WidgetTester tester) async {
  await tester.tap(find.text('Crop'));
  await tester.pumpAndSettle();
  await tester.tap(find.text('1:1'));
  await tester.pumpAndSettle();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory temporaryDirectory;
  late Future<ShareResult> Function(ShareParams) originalShare;
  late Future<Uint8List> Function(
    String, {
    required List<WallpaperFilter> stack,
    required WallpaperAdjustments adjustments,
    CropSpec? crop,
    double? previewPixelShortSide,
    double deviceLongSidePx,
  })
  originalRender;

  setUp(() {
    temporaryDirectory = Directory.systemTemp.createTempSync('wallpaper_filter_share_cleanup_');
    originalShare = WallpaperFilterScreen.share;
    originalRender = WallpaperFilterScreen.renderFile;
    AnalyticsRuntime.instance = FakeAppAnalytics();
    app_state.prismUser = profileUser();
    final TestDefaultBinaryMessenger messenger = TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(_pathProviderChannel, (_) async => temporaryDirectory.path);
    // Keep the toast channel reply pending so fluttertoast's timer cannot outlive the test.
    messenger.setMockMethodCallHandler(_toastChannel, (_) => Completer<bool>().future);
  });

  tearDown(() {
    WallpaperFilterScreen.share = originalShare;
    WallpaperFilterScreen.renderFile = originalRender;
    AnalyticsRuntime.reset();
    app_state.prismUser = app_constants.createGuestPrismUser();
    final TestDefaultBinaryMessenger messenger = TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(_pathProviderChannel, null);
    messenger.setMockMethodCallHandler(_toastChannel, null);
    if (temporaryDirectory.existsSync()) temporaryDirectory.deleteSync(recursive: true);
  });

  testWidgets('shared crop survives share return and is removed only when the editor closes', (tester) async {
    final Uint8List sourceBytes = (await tester.runAsync(_sourcePng))!;
    final File source = File('${temporaryDirectory.path}/source.png')..writeAsBytesSync(sourceBytes);
    final File sibling = File('${temporaryDirectory.path}/sibling.txt')..writeAsStringSync('keep');
    String? sharedPath;
    Uint8List? sharedBytes;
    WallpaperFilterScreen.share = (params) async {
      sharedPath = params.files!.single.path;
      sharedBytes = File(sharedPath!).readAsBytesSync();
      return const ShareResult('', ShareResultStatus.success);
    };

    await _openEditor(tester, source.path);
    await _cropSquare(tester);
    await tester.tap(find.byTooltip('Share'));
    await waitForRealIo(tester, () => sharedPath != null, reason: 'share receives cropped export');
    await tester.pumpAndSettle();

    final File export = File(sharedPath!);
    final Directory exportDirectory = export.parent;
    expect(sharedBytes, isNotNull);
    expect(export.existsSync(), isTrue, reason: 'the receiver may read the file after share() returns');
    expect(exportDirectory.existsSync(), isTrue);
    expect(source.readAsBytesSync(), sourceBytes);
    expect(sibling.readAsStringSync(), 'keep');

    await tester.pumpWidget(const SizedBox.shrink());
    await waitForRealIo(
      tester,
      () => !export.existsSync() && !exportDirectory.existsSync(),
      reason: 'shared export cleanup after editor disposal',
    );

    expect(source.existsSync(), isTrue);
    expect(source.readAsBytesSync(), sourceBytes);
    expect(sibling.existsSync(), isTrue);
    expect(sibling.readAsStringSync(), 'keep');
  });

  testWidgets('late render after disposal does not write an export or call share', (tester) async {
    final Uint8List sourceBytes = (await tester.runAsync(_sourcePng))!;
    final File source = File('${temporaryDirectory.path}/source.png')..writeAsBytesSync(sourceBytes);
    final Completer<Uint8List> lateRender = Completer<Uint8List>();
    final Completer<void> renderStarted = Completer<void>();
    int shareCalls = 0;
    WallpaperFilterScreen.share = (_) async {
      shareCalls++;
      return const ShareResult('', ShareResultStatus.success);
    };
    WallpaperFilterScreen.renderFile =
        (path, {required stack, required adjustments, crop, previewPixelShortSide, deviceLongSidePx = 0}) {
          renderStarted.complete();
          return lateRender.future;
        };

    await _openEditor(tester, source.path);
    await _cropSquare(tester);
    await tester.tap(find.byTooltip('Share'));
    await waitForRealIo(tester, () => renderStarted.isCompleted, reason: 'share render started');
    await tester.pumpWidget(const SizedBox.shrink());

    lateRender.complete(sourceBytes);
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 40)));
    await tester.pump();

    expect(shareCalls, 0);
    expect(Directory('${temporaryDirectory.path}/prism_edit').existsSync(), isFalse);
    expect(source.existsSync(), isTrue);
    expect(source.readAsBytesSync(), sourceBytes);
  });
}
