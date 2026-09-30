import 'dart:io';
import 'dart:ui' as ui;

import 'package:Prism/core/widgets/prism/prism_ui.dart';
import 'package:Prism/features/wallpaper_upload/views/pages/edit_wall_screen.dart';
import 'package:extended_image/extended_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image_editor/image_editor.dart' show ImageEditorOption, ImageEditorPlatform, ImageMergeOption;

class _FailingImageEditorPlatform extends ImageEditorPlatform {
  final List<({Uint8List image, ImageEditorOption option})> calls = <({Uint8List image, ImageEditorOption option})>[];

  @override
  Future<Uint8List?> editImage({required Uint8List image, required ImageEditorOption imageEditorOption}) {
    calls.add((image: image, option: imageEditorOption));
    return Future<Uint8List?>.error(PlatformException(code: 'native_edit_failed'));
  }

  @override
  Future<Uint8List?> editFileImage({required File file, required ImageEditorOption imageEditorOption}) async =>
      throw UnimplementedError();

  @override
  Future<File?> editFileImageAndGetFile({required File file, required ImageEditorOption imageEditorOption}) async =>
      throw UnimplementedError();

  @override
  Future<File> editImageAndGetFile({required Uint8List image, required ImageEditorOption imageEditorOption}) async =>
      throw UnimplementedError();

  @override
  Future<File?> mergeToFile({required ImageMergeOption option}) async => throw UnimplementedError();

  @override
  Future<Uint8List?> mergeToMemory({required ImageMergeOption option}) async => throw UnimplementedError();
}

void main() {
  Future<Uint8List> makePng() async {
    final ui.PictureRecorder recorder = ui.PictureRecorder();
    ui.Canvas(recorder).drawRect(const ui.Rect.fromLTWH(0, 0, 8, 8), ui.Paint()..color = const Color(0xFFFF0000));
    final ui.Picture picture = recorder.endRecording();
    final ui.Image image = await picture.toImage(8, 8);
    picture.dispose();
    final ByteData data = (await image.toByteData(format: ui.ImageByteFormat.png))!;
    image.dispose();
    return data.buffer.asUint8List();
  }

  Future<File> makeImage(WidgetTester tester) async {
    final Directory dir = (await tester.runAsync(() => Directory.systemTemp.createTemp('prism-edit-wall-')))!;
    addTearDown(() => tester.runAsync(() => dir.delete(recursive: true)));
    final File image = File('${dir.path}/pixel.png');
    final Uint8List bytes = (await tester.runAsync(makePng))!;
    await tester.runAsync(() => image.writeAsBytes(bytes));
    return image;
  }

  Future<void> pumpScreen(WidgetTester tester) async {
    tester.platformDispatcher.accessibilityFeaturesTestValue = const FakeAccessibilityFeatures(disableAnimations: true);
    addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final File image = await makeImage(tester);
    await tester.pumpWidget(MaterialApp(home: EditWallScreen(image: image)));
    await tester.pump();
  }

  testWidgets('shows the crop shapes, the three adjustments and one Save action', (tester) async {
    await pumpScreen(tester);

    expect(find.text('Edit wallpaper'), findsOneWidget);
    for (final String label in <String>['9:18', '9:16', '9:21', '9:19.5']) {
      expect(find.text(label), findsOneWidget);
    }
    expect(find.text('Saturation'), findsOneWidget);
    expect(find.text('Brightness'), findsOneWidget);
    expect(find.text('Contrast'), findsOneWidget);
    expect(find.byType(Slider), findsNWidgets(3));
    expect(find.byTooltip('Flip'), findsOneWidget);
    expect(find.byTooltip('Rotate left'), findsOneWidget);
    expect(find.byTooltip('Rotate right'), findsOneWidget);
    expect(find.byTooltip('Reset adjustments'), findsOneWidget);
    expect(find.widgetWithText(PrismButton, 'Save'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('reset puts the adjustments back to their defaults', (tester) async {
    await pumpScreen(tester);

    await tester.drag(find.byType(Slider).first, const Offset(60, 0));
    await tester.pump();
    expect(find.text('1.00'), findsNWidgets(1));

    await tester.tap(find.byTooltip('Reset adjustments'));
    await tester.pump();

    expect(find.text('1.00'), findsNWidgets(2));
    expect(find.text('0.00'), findsOneWidget);
  });

  testWidgets('leaving after an edit asks before discarding', (tester) async {
    await pumpScreen(tester);

    await tester.drag(find.byType(Slider).first, const Offset(60, 0));
    await tester.pump();
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();

    expect(find.text('Discard your edits?'), findsOneWidget);
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(find.text('Edit wallpaper'), findsOneWidget);
  });

  testWidgets('a native edit error releases Save so the user can retry', (tester) async {
    await pumpScreen(tester);
    final ImageEditorPlatform previousPlatform = ImageEditorPlatform.instance;
    final _FailingImageEditorPlatform platform = _FailingImageEditorPlatform();
    ImageEditorPlatform.instance = platform;
    addTearDown(() => ImageEditorPlatform.instance = previousPlatform);
    final List<String> toastMessages = <String>[];
    const MethodChannel toastChannel = MethodChannel('PonnamKarthik/fluttertoast');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(toastChannel, (
      call,
    ) async {
      final Map<Object?, Object?> arguments = call.arguments as Map<Object?, Object?>;
      toastMessages.add(arguments['msg']! as String);
      return true;
    });
    addTearDown(
      () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
        toastChannel,
        null,
      ),
    );

    for (int attempt = 0; attempt < 20; attempt++) {
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 25)));
      await tester.pump();
      final Finder editor = find.byType(ExtendedImageEditor);
      if (editor.evaluate().isNotEmpty) {
        final ExtendedImageEditorState state = tester.state<ExtendedImageEditorState>(editor);
        if (state.getCropRect() != null && state.editAction != null && state.rawImageData.isNotEmpty) break;
      }
      if (attempt == 19) fail('Editor image did not become ready');
    }
    await tester.tap(find.widgetWithText(PrismButton, 'Save'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    final PrismButton failedSave = tester.widget<PrismButton>(find.widgetWithText(PrismButton, 'Save'));
    expect(failedSave.loading, isFalse);
    expect(failedSave.onPressed, isNotNull);
    expect(toastMessages, contains('Could not save your edits. Try again.'));
    expect(platform.calls, hasLength(1));
    expect(tester.takeException(), isNull);
    await tester.tap(find.widgetWithText(PrismButton, 'Save'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(platform.calls, hasLength(2));
    for (final ({Uint8List image, ImageEditorOption option}) call in platform.calls) {
      expect(call.image, isNotEmpty);
      expect(call.option.options, isNotEmpty);
    }
    final PrismButton save = tester.widget<PrismButton>(find.widgetWithText(PrismButton, 'Save'));
    expect(save.loading, isFalse);
    expect(save.onPressed, isNotNull);
  });
}
