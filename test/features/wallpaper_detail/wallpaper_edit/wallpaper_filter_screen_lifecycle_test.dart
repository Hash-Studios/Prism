import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:Prism/core/constants/app_constants.dart' as app_constants;
import 'package:Prism/core/platform/pigeon/prism_media_api.g.dart';
import 'package:Prism/core/state/app_state.dart' as app_state;
import 'package:Prism/features/wallpaper_detail/views/pages/wallpaper_filter_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

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
  for (int attempt = 0; attempt < 20; attempt++) {
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 25)));
    await tester.pump();
    final Finder downloadButton = find.ancestor(of: find.byTooltip('Download'), matching: find.byType(IconButton));
    if (tester.widget<IconButton>(downloadButton).onPressed != null) return;
  }
  fail('Valid preview did not become ready');
}

Future<void> _waitForFailure(WidgetTester tester) async {
  for (int attempt = 0; attempt < 20; attempt++) {
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 25)));
    await tester.pump();
    if (find.text("Couldn't open this wallpaper.").evaluate().isNotEmpty) return;
  }
  fail('Invalid preview did not show its error state');
}

Widget _screenHost(String sourcePath) => MaterialApp(home: WallpaperFilterScreen(filePath: sourcePath));

void main() {
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
    expect(tester.getSemantics(sliderFinder).label, contains('Lightness'));
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

    app_state.prismUser = app_constants.createGuestPrismUser()..premium = true;
    addTearDown(() => app_state.prismUser = app_constants.createGuestPrismUser());

    final Completer<void> allowSave = Completer<void>();
    final Completer<SaveMediaRequest> requestReceived = Completer<SaveMediaRequest>();
    const MethodChannel pathProviderChannel = MethodChannel('plugins.flutter.io/path_provider');
    const MethodChannel toastChannel = MethodChannel('PonnamKarthik/fluttertoast');
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(pathProviderChannel, (_) async => directory.path);
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(toastChannel, (_) async => true);
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
    for (int attempt = 0; attempt < 100 && !requestReceived.isCompleted; attempt++) {
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 25)));
      await tester.pump();
    }
    expect(requestReceived.isCompleted, isTrue);
    final SaveMediaRequest request = await requestReceived.future;
    await tester.pump();

    final Finder resetFinder = find.ancestor(of: find.byTooltip('Reset'), matching: find.byType(IconButton));
    expect(tester.widget<IconButton>(resetFinder).onPressed, isNull);
    expect(File(request.link).existsSync(), isTrue);
    expect(await tester.runAsync(() => _centreRed(File(request.link))), 255);

    allowSave.complete();
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 50)));
    await tester.pump();

    expect(File(request.link).existsSync(), isFalse);
    expect(Directory(File(request.link).parent.path).existsSync(), isFalse);
  });
}
