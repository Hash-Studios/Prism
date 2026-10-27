import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:Prism/core/di/injection.dart';
import 'package:Prism/core/persistence/data_sources/settings_local_data_source.dart';
import 'package:Prism/core/persistence/persistence_keys.dart';
import 'package:Prism/features/wallpaper_detail/views/widgets/clock_overlay.dart';
import 'package:Prism/features/wallpaper_detail/views/widgets/preview_layers.dart';
import 'package:Prism/l10n/l10n.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../../support/in_memory_local_store.dart';

Future<File> _solidPng(Directory directory, String name, Color color) async {
  final ui.PictureRecorder recorder = ui.PictureRecorder();
  Canvas(recorder).drawRect(const Rect.fromLTWH(0, 0, 40, 80), Paint()..color = color);
  final ui.Image image = await recorder.endRecording().toImage(40, 80);
  final ByteData data = (await image.toByteData(format: ui.ImageByteFormat.png))!;
  final File file = File('${directory.path}/$name.png');
  await file.writeAsBytes(data.buffer.asUint8List());
  image.dispose();
  return file;
}

Future<Object> _key(ImageProvider provider) => provider.obtainKey(ImageConfiguration.empty);

Future<void> _settleImages(WidgetTester tester) async {
  for (var i = 0; i < 20; i++) {
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 50)));
    await tester.pump();
  }
}

Future<void> _waitForPalette(WidgetTester tester, Object key) async {
  final ImageCache cache = PaintingBinding.instance.imageCache;
  ColorScheme? scheme() => tester.widget<HomePreviewLayer>(find.byType(HomePreviewLayer)).scheme;
  for (var i = 0; i < 60 && (!cache.containsKey(key) || scheme() == null); i++) {
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 50)));
    await tester.pump(const Duration(milliseconds: 100));
  }
  expect(cache.containsKey(key), isTrue, reason: 'The 64px wallpaper palette decode should be cached.');
  expect(scheme(), isNotNull, reason: 'The Home layer should receive its wallpaper palette.');
}

void main() {
  late SettingsLocalDataSource settings;

  setUp(() async {
    settings = SettingsLocalDataSource(InMemoryLocalStore());
    getIt.registerSingleton<SettingsLocalDataSource>(settings);
    await settings.set(PersistenceKeys.previewIconStyle, 'tinted');
    PaintingBinding.instance.imageCache
      ..clear()
      ..clearLiveImages();
  });

  tearDown(() async {
    PaintingBinding.instance.imageCache
      ..clear()
      ..clearLiveImages();
    await getIt.reset();
  });

  testWidgets('iOS Lock defers palette decode until Home and keeps decode sizes separate', (tester) async {
    tester.view.physicalSize = const Size(400, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final Directory directory = Directory.systemTemp.createTempSync('clock-palette-lock-');
    addTearDown(() => directory.deleteSync(recursive: true));
    final File wall = (await tester.runAsync(() => _solidPng(directory, 'red', const Color(0xFFFF0000))))!;

    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: ClockOverlay(link: wall.path, file: true),
      ),
    );
    await _settleImages(tester);

    final FileImage source = FileImage(wall);
    final Object sampleKey = await _key(ResizeImage(source, width: 32));
    final Object paletteKey = await _key(ResizeImage(source, width: 64));
    expect(sampleKey, isNot(paletteKey));
    expect(PaintingBinding.instance.imageCache.containsKey(sampleKey), isTrue);
    expect(PaintingBinding.instance.imageCache.containsKey(paletteKey), isFalse);
    expect(find.byType(LockPreviewLayer), findsOneWidget);

    await tester.tap(find.text('Home'));
    await tester.pumpAndSettle();
    await _waitForPalette(tester, paletteKey);

    expect(PaintingBinding.instance.imageCache.containsKey(sampleKey), isTrue);
    expect(PaintingBinding.instance.imageCache.containsKey(paletteKey), isTrue);
    expect(find.byType(HomePreviewLayer), findsOneWidget);
  }, variant: TargetPlatformVariant.only(TargetPlatform.iOS));

  testWidgets('replacing the mounted Home wallpaper refreshes its palette', (tester) async {
    tester.view.physicalSize = const Size(400, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final Directory directory = Directory.systemTemp.createTempSync('clock-palette-replace-');
    addTearDown(() => directory.deleteSync(recursive: true));
    final File red = (await tester.runAsync(() => _solidPng(directory, 'red', const Color(0xFFFF0000))))!;
    final File green = (await tester.runAsync(() => _solidPng(directory, 'green', const Color(0xFF00FF00))))!;

    Widget preview(File wall) => MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: ClockOverlay(link: wall.path, file: true),
    );

    await tester.pumpWidget(preview(red));
    await _settleImages(tester);
    await tester.tap(find.text('Home'));
    await tester.pumpAndSettle();
    final Object redPaletteKey = await _key(ResizeImage(FileImage(red), width: 64));
    await _waitForPalette(tester, redPaletteKey);
    final Color redPrimary = tester.widget<HomePreviewLayer>(find.byType(HomePreviewLayer)).scheme!.primary;
    expect(redPrimary.r, greaterThan(redPrimary.g));

    await tester.pumpWidget(preview(green));
    await tester.pumpAndSettle();
    final Object greenPaletteKey = await _key(ResizeImage(FileImage(green), width: 64));
    await _waitForPalette(tester, greenPaletteKey);
    final Color greenPrimary = tester.widget<HomePreviewLayer>(find.byType(HomePreviewLayer)).scheme!.primary;
    expect(greenPrimary.g, greaterThan(greenPrimary.r));
    expect(greenPrimary, isNot(redPrimary));
  }, variant: TargetPlatformVariant.only(TargetPlatform.iOS));
}
