import 'dart:io';
import 'dart:ui' as ui;

import 'package:Prism/core/constants/app_constants.dart' as app_constants;
import 'package:Prism/core/state/app_state.dart' as app_state;
import 'package:Prism/features/wallpaper_detail/domain/entities/crop_spec.dart';
import 'package:Prism/features/wallpaper_detail/views/pages/wallpaper_filter_screen.dart';
import 'package:Prism/features/wallpaper_detail/views/widgets/crop_frame_view.dart';
import 'package:Prism/l10n/l10n.dart';
import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../support/profile_user_fixture.dart';
import '../../../support/wait_for_real_io.dart';

const Size _viewSize = Size(800, 1200);

/// 40 by 80 pixels: the top half red, the bottom half blue.
Future<List<int>> _sourcePng() async {
  final ui.PictureRecorder recorder = ui.PictureRecorder();
  Canvas(recorder)
    ..drawRect(const Rect.fromLTWH(0, 0, 40, 40), Paint()..color = const Color(0xFFFF0000))
    ..drawRect(const Rect.fromLTWH(0, 40, 40, 40), Paint()..color = const Color(0xFF0000FF));
  final ui.Picture picture = recorder.endRecording();
  final ui.Image image = await picture.toImage(40, 80);
  picture.dispose();
  final ByteData data = (await image.toByteData(format: ui.ImageByteFormat.png))!;
  image.dispose();
  return data.buffer.asUint8List();
}

Future<void> _waitForReady(WidgetTester tester) async {
  await waitForRealIo(tester, () {
    expect(find.text("Couldn't open this wallpaper."), findsNothing);
    final Finder downloadButton = find.ancestor(of: find.byTooltip('Download'), matching: find.byType(IconButton));
    return tester.widget<IconButton>(downloadButton).onPressed != null;
  }, reason: 'decoded source image and enabled Download');
}

Widget _screenHost(String sourcePath, {bool reduceMotion = false, TextScaler textScaler = TextScaler.noScaling}) =>
    MediaQuery(
      data: MediaQueryData(
        size: _viewSize,
        devicePixelRatio: 1,
        disableAnimations: reduceMotion,
        textScaler: textScaler,
      ),
      child: MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: WallpaperFilterScreen(filePath: sourcePath),
      ),
    );

Future<void> _pumpScreen(
  WidgetTester tester, {
  bool reduceMotion = false,
  TextScaler textScaler = TextScaler.noScaling,
}) async {
  tester.view.physicalSize = _viewSize;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  final Directory directory = Directory.systemTemp.createTempSync('wallpaper_filter_crop_ui_');
  addTearDown(() => directory.deleteSync(recursive: true));
  final File source = File('${directory.path}/source.png')..writeAsBytesSync((await tester.runAsync(_sourcePng))!);

  app_state.prismUser = profileUser(premium: true);
  addTearDown(() => app_state.prismUser = app_constants.createGuestPrismUser());

  const MethodChannel pathProviderChannel = MethodChannel('plugins.flutter.io/path_provider');
  const MethodChannel toastChannel = MethodChannel('PonnamKarthik/fluttertoast');
  tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(pathProviderChannel, (_) async => directory.path);
  tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(toastChannel, (_) async => true);
  addTearDown(() {
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(pathProviderChannel, null);
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(toastChannel, null);
  });

  await tester.pumpWidget(_screenHost(source.path, reduceMotion: reduceMotion, textScaler: textScaler));
  await _waitForReady(tester);
}

Future<void> _openCropTab(WidgetTester tester) async {
  await tester.tap(find.text('Crop'));
  await tester.pumpAndSettle();
}

({int width, int height}) _cropSize(WidgetTester tester) {
  final String text = tester.widget<Text>(find.textContaining(' × ')).data!;
  final RegExpMatch match = RegExp(r'^(\d+) × (\d+) px$').firstMatch(text)!;
  return (width: int.parse(match.group(1)!), height: int.parse(match.group(2)!));
}

Finder _handle(CropCorner corner) => find.byKey(ValueKey<CropCorner>(corner));

Rect _handleRect(WidgetTester tester, CropCorner corner) => tester.getRect(_handle(corner));

Future<void> _tapPreset(WidgetTester tester, String label) async {
  await tester.ensureVisible(find.text(label));
  await tester.tap(find.text(label));
}

Finder _reset() => find.ancestor(of: find.byTooltip('Reset crop'), matching: find.byType(IconButton));

void main() {
  testWidgets('presets snap the frame and each tap plays a selection haptic', (tester) async {
    final List<String> haptics = <String>[];
    const MethodChannel hapticsChannel = MethodChannel('prism/haptics');
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(hapticsChannel, (call) async {
      if (call.method == 'play') haptics.add(call.arguments! as String);
      return null;
    });
    addTearDown(() => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(hapticsChannel, null));

    await _pumpScreen(tester);
    await _openCropTab(tester);
    expect(find.text('40 × 80 px'), findsOneWidget);
    haptics.clear();

    await _tapPreset(tester, '1:1');
    await tester.pumpAndSettle();
    expect(find.text('40 × 40 px'), findsOneWidget);

    await _tapPreset(tester, '16:9 desktop');
    await tester.pumpAndSettle();
    expect(find.text('40 × 23 px'), findsOneWidget);

    await _tapPreset(tester, 'Original');
    await tester.pumpAndSettle();
    expect(find.text('40 × 80 px'), findsOneWidget);

    expect(haptics, <String>['selection', 'selection', 'selection']);
  });

  testWidgets('dragging a corner handle shrinks the free frame', (tester) async {
    await _pumpScreen(tester);
    await _openCropTab(tester);
    await _tapPreset(tester, 'Free');
    await tester.pumpAndSettle();

    await tester.drag(_handle(CropCorner.bottomRight), const Offset(-200, -400));
    await tester.pumpAndSettle();

    final ({int width, int height}) size = _cropSize(tester);
    expect(size.width, lessThan(40));
    expect(size.height, lessThan(80));
    expect(size.width, greaterThanOrEqualTo(4));
    expect(size.height, greaterThanOrEqualTo(4));
  });

  testWidgets('pinching the frame shrinks it on its aspect', (tester) async {
    await _pumpScreen(tester);
    await _openCropTab(tester);
    await _tapPreset(tester, '1:1');
    await tester.pumpAndSettle();

    final Offset centre = tester.getCenter(find.byType(CropFrameView));
    final TestGesture first = await tester.startGesture(centre + const Offset(-50, 0));
    final TestGesture second = await tester.startGesture(centre + const Offset(50, 0));
    for (int step = 1; step <= 10; step++) {
      final double offset = 50 - 4.0 * step;
      await first.moveTo(centre + Offset(-offset, 0));
      await second.moveTo(centre + Offset(offset, 0));
      await tester.pump();
    }
    await first.up();
    await second.up();
    await tester.pumpAndSettle();

    final ({int width, int height}) size = _cropSize(tester);
    expect(size.width, equals(size.height));
    expect(size.width, lessThan(40));
    expect(size.width, greaterThanOrEqualTo(4));
  });

  testWidgets('reset crop restores the whole image and disables reset', (tester) async {
    await _pumpScreen(tester);
    await _openCropTab(tester);
    await _tapPreset(tester, '1:1');
    await tester.pumpAndSettle();
    expect(tester.widget<IconButton>(_reset()).onPressed, isNotNull);

    await tester.tap(find.byTooltip('Reset crop'));
    await tester.pumpAndSettle();

    expect(find.text('40 × 80 px'), findsOneWidget);
    expect(tester.widget<IconButton>(_reset()).onPressed, isNull);
  });

  testWidgets('reduced motion moves the handle to its final place on the first frame', (tester) async {
    await _pumpScreen(tester, reduceMotion: true);
    await _openCropTab(tester);
    final Rect before = _handleRect(tester, CropCorner.bottomRight);

    await _tapPreset(tester, '1:1');
    await tester.pump();
    final Rect afterFirstFrame = _handleRect(tester, CropCorner.bottomRight);
    await tester.pumpAndSettle();

    expect(afterFirstFrame, _handleRect(tester, CropCorner.bottomRight));
    expect(afterFirstFrame, isNot(before));
  });

  testWidgets('the handle eases to its place when motion is allowed', (tester) async {
    await _pumpScreen(tester);
    await _openCropTab(tester);
    final Rect before = _handleRect(tester, CropCorner.bottomRight);

    await _tapPreset(tester, '1:1');
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 60));
    final Rect midway = _handleRect(tester, CropCorner.bottomRight);
    await tester.pumpAndSettle();
    final Rect settled = _handleRect(tester, CropCorner.bottomRight);

    expect(midway, isNot(before));
    expect(midway, isNot(settled));
  });

  testWidgets('large text keeps every preset and handle usable', (tester) async {
    await _pumpScreen(tester, textScaler: const TextScaler.linear(2.0));
    await _openCropTab(tester);

    for (final String label in <String>['Free', 'This phone', '9:16', '1:1', '16:9 desktop', 'Original']) {
      expect(find.text(label), findsOneWidget);
    }
    expect(tester.takeException(), isNull);
    for (final CropCorner corner in CropCorner.values) {
      final Size handle = tester.getSize(_handle(corner));
      expect(handle.width, greaterThanOrEqualTo(44));
      expect(handle.height, greaterThanOrEqualTo(44));
    }
  });

  testWidgets('semantics expose the corner handles and resize them with decrease', (tester) async {
    final SemanticsHandle semantics = tester.ensureSemantics();
    try {
      await _pumpScreen(tester);
      await _openCropTab(tester);
      for (final String label in <String>[
        'Top-left corner',
        'Top-right corner',
        'Bottom-left corner',
        'Bottom-right corner',
      ]) {
        expect(find.bySemanticsLabel(label), findsOneWidget);
      }

      await _tapPreset(tester, 'Free');
      await tester.pumpAndSettle();

      final SemanticsNode corner = tester.getSemantics(find.bySemanticsLabel('Bottom-right corner'));
      expect(corner.getSemanticsData().hasAction(SemanticsAction.decrease), isTrue);
      tester.binding.performSemanticsAction(
        SemanticsActionEvent(type: SemanticsAction.decrease, viewId: tester.view.viewId, nodeId: corner.id),
      );
      await tester.pumpAndSettle();

      final ({int width, int height}) size = _cropSize(tester);
      expect(size.width, lessThan(40));
      expect(size.height, lessThan(80));
    } finally {
      semantics.dispose();
    }
  });

  testWidgets('dragging inside the frame moves the kept area without resizing it', (tester) async {
    await _pumpScreen(tester);
    await _openCropTab(tester);
    await _tapPreset(tester, '1:1');
    await tester.pumpAndSettle();

    final Offset centre = tester.getCenter(find.byType(CropFrameView));
    final TestGesture drag = await tester.startGesture(centre);
    for (int step = 0; step < 10; step++) {
      await drag.moveBy(const Offset(0, -200));
      await tester.pump();
    }
    await drag.up();
    await tester.pumpAndSettle();

    expect(find.text('40 × 40 px'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
