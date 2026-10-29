// ignore_for_file: depend_on_referenced_packages
import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:Prism/core/cache/prism_image_cache.dart';
import 'package:Prism/core/widgets/prism_sheet/device_corner_radius.dart';
import 'package:Prism/features/ai_wallpaper/domain/entities/ai_style_preset.dart';
import 'package:Prism/features/ai_wallpaper/views/widgets/ai_pickers.dart';
import 'package:Prism/features/ai_wallpaper/views/widgets/ai_style_sheet.dart';
import 'package:Prism/l10n/l10n.dart';
import 'package:file/local.dart' as local;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockCacheManager extends Mock implements BaseCacheManager {}

/// A 1x1 transparent PNG that the image codec can decode.
const String _pngBase64 =
    'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNkYAAAAAYAAjCB0C8AAAAASUVORK5CYII=';

const String _subject = 'Every preview shows the same scene: a lighthouse on a cliff at dusk.';

Widget _host({required Widget home, bool reduceMotion = false}) => MaterialApp(
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  supportedLocales: AppLocalizations.supportedLocales,
  locale: const Locale('en'),
  builder: (context, child) => MediaQuery(
    data: MediaQuery.of(context).copyWith(disableAnimations: reduceMotion),
    child: child!,
  ),
  home: home,
);

Widget _sampleHost(AiStylePreset style, AiStyleSampleSize size) => _host(
  home: Scaffold(
    body: Center(
      child: SizedBox(
        width: AiStylePicker.tileWidth,
        height: AiStylePicker.tileHeight,
        child: AiStyleSample(style: style, size: size),
      ),
    ),
  ),
);

Widget _pickerHost({required AiStylePreset selected, ValueChanged<AiStylePreset>? onSelected, bool enabled = true}) =>
    _host(
      home: Scaffold(
        body: Center(
          child: AiStylePicker(selected: selected, onSelected: onSelected ?? (_) {}, enabled: enabled),
        ),
      ),
    );

/// The RawImages that currently carry a decoded image.
List<RawImage> _loadedImages(WidgetTester tester) =>
    tester.widgetList<RawImage>(find.byType(RawImage)).where((RawImage image) => image.image != null).toList();

Future<void> _pumpUntilLoaded(WidgetTester tester) async {
  final Stopwatch timeout = Stopwatch()..start();
  while (_loadedImages(tester).isEmpty && timeout.elapsed < const Duration(seconds: 2)) {
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 10)));
    await tester.pump();
  }
  await tester.pumpAndSettle();
}

Finder _gradientOf(AiStylePreset style) => find.byWidgetPredicate(
  (Widget widget) =>
      widget is DecoratedBox &&
      widget.decoration is BoxDecoration &&
      (widget.decoration as BoxDecoration).gradient is LinearGradient &&
      listEquals(((widget.decoration as BoxDecoration).gradient! as LinearGradient).colors, style.swatchColors),
);

Finder _semanticsLabel(String label) =>
    find.byWidgetPredicate((Widget widget) => widget is Semantics && widget.properties.label == label);

Finder _rowTile(AiStylePreset style) =>
    find.descendant(of: find.byType(AiStylePicker), matching: _semanticsLabel('Style: ${style.label}'));

/// Asserts that the whole [tile] sits inside the row's viewport.
void _expectTileInRowViewport(WidgetTester tester, Finder tile) {
  final Rect viewport = tester.getRect(
    find.descendant(of: find.byType(AiStylePicker), matching: find.byType(Scrollable)),
  );
  final Rect rect = tester.getRect(tile);
  expect(rect.left, greaterThanOrEqualTo(viewport.left), reason: 'tile starts before the viewport');
  expect(rect.right, lessThanOrEqualTo(viewport.right), reason: 'tile ends after the viewport');
}

double _rowPixels(WidgetTester tester) => tester
    .state<ScrollableState>(find.descendant(of: find.byType(AiStylePicker), matching: find.byType(Scrollable)))
    .position
    .pixels;

void main() {
  late Directory directory;
  late _MockCacheManager cache;
  late File png;
  late List<String> requestedUrls;

  setUp(() {
    directory = Directory.systemTemp.createTempSync('prism-ai-style-picker-test-');
    png = File('${directory.path}/sample.png')..writeAsBytesSync(base64Decode(_pngBase64));
    cache = _MockCacheManager();
    requestedUrls = <String>[];
    PrismImageCache.testOverride = cache;
    PaintingBinding.instance.imageCache.clear();
  });

  tearDown(() {
    PrismImageCache.testOverride = null;
    PaintingBinding.instance.imageCache.clear();
    directory.deleteSync(recursive: true);
  });

  void stubCache(Stream<FileResponse> Function(String url) respond) {
    when(() => cache.getFileStream(any(), withProgress: true)).thenAnswer((Invocation invocation) {
      final String url = invocation.positionalArguments.first as String;
      requestedUrls.add(url);
      return respond(url);
    });
  }

  group('AiStylePreset sample keys', () {
    test('builds the stored sample URL for each style and size', () {
      expect(
        AiStylePreset.meshGradient.sampleUrl(AiStyleSampleSize.tile),
        'https://prismwalls.com/api/ai/assets/ai/studio/style-samples-v1-mesh-gradient-tile.webp',
      );
      expect(
        AiStylePreset.render3d.sampleUrl(AiStyleSampleSize.sheet),
        'https://prismwalls.com/api/ai/assets/ai/studio/style-samples-v1-3d-render-sheet.webp',
      );
    });

    test('derives the slugs from the API value', () {
      expect(AiStylePreset.ukiyoE.sampleSlug, 'ukiyo-e');
      expect(AiStylePreset.space.sampleSlug, 'space-art');
    });

    test('gives every style its own slug', () {
      final Set<String> slugs = AiStylePreset.values.map((AiStylePreset style) => style.sampleSlug).toSet();
      expect(AiStylePreset.values, hasLength(13));
      expect(slugs, hasLength(13));
    });
  });

  group('AiStyleSample', () {
    testWidgets('shows the loaded image at 96x120', (tester) async {
      stubCache(
        (String url) => Stream<FileResponse>.value(
          FileInfo(const local.LocalFileSystem().file(png.path), FileSource.Online, DateTime(2100), url),
        ),
      );

      await tester.pumpWidget(_sampleHost(AiStylePreset.anime, AiStyleSampleSize.tile));
      await _pumpUntilLoaded(tester);

      expect(_loadedImages(tester), hasLength(1));
      expect(tester.getSize(find.byType(AiStyleSample)), const Size(96, 120));
    });

    testWidgets('shows the gradient and no image while the download is pending', (tester) async {
      final StreamController<FileResponse> pending = StreamController<FileResponse>();
      addTearDown(pending.close);
      stubCache((_) => pending.stream);

      await tester.pumpWidget(_sampleHost(AiStylePreset.nature, AiStyleSampleSize.tile));
      await tester.pump();

      expect(_gradientOf(AiStylePreset.nature), findsOneWidget);
      expect(_loadedImages(tester), isEmpty);
      expect(tester.getSize(find.byType(AiStyleSample)), const Size(96, 120));
    });

    testWidgets('keeps the gradient when the download fails with an HTTP 404', (tester) async {
      stubCache(
        (String url) => Stream<FileResponse>.error(HttpExceptionWithStatus(404, 'Not found', uri: Uri.parse(url))),
      );

      await tester.pumpWidget(_sampleHost(AiStylePreset.nature, AiStyleSampleSize.tile));
      await _pumpUntilLoaded(tester);

      expect(_gradientOf(AiStylePreset.nature), findsOneWidget);
      expect(_loadedImages(tester), isEmpty);
      expect(tester.takeException(), isNull);
      expect(tester.getSize(find.byType(AiStyleSample)), const Size(96, 120));
    });

    testWidgets('keeps the gradient when the device is offline', (tester) async {
      stubCache((_) => Stream<FileResponse>.error(const SocketException('Failed host lookup')));

      await tester.pumpWidget(_sampleHost(AiStylePreset.nature, AiStyleSampleSize.tile));
      await _pumpUntilLoaded(tester);

      expect(_gradientOf(AiStylePreset.nature), findsOneWidget);
      expect(_loadedImages(tester), isEmpty);
      expect(tester.takeException(), isNull);
      expect(tester.getSize(find.byType(AiStyleSample)), const Size(96, 120));
    });

    testWidgets('requests the sample URL for its style and size', (tester) async {
      final StreamController<FileResponse> pending = StreamController<FileResponse>();
      addTearDown(pending.close);
      stubCache((_) => pending.stream);

      await tester.pumpWidget(_sampleHost(AiStylePreset.render3d, AiStyleSampleSize.sheet));
      await tester.pump();

      expect(requestedUrls, <String>[
        'https://prismwalls.com/api/ai/assets/ai/studio/style-samples-v1-3d-render-sheet.webp',
      ]);
    });
  });

  group('AiStylePicker', () {
    testWidgets('marks the selected tile and announces it as a selected button', (tester) async {
      final SemanticsHandle handle = tester.ensureSemantics();
      stubCache((_) => const Stream<FileResponse>.empty());

      await tester.pumpWidget(_pickerHost(selected: AiStylePreset.nature));

      expect(
        tester.getSemantics(_rowTile(AiStylePreset.nature)),
        matchesSemantics(
          label: 'Style: Nature',
          isButton: true,
          hasSelectedState: true,
          isSelected: true,
          hasTapAction: true,
        ),
      );
      expect(
        tester.getSemantics(_rowTile(AiStylePreset.anime)),
        matchesSemantics(label: 'Style: Anime', isButton: true, hasSelectedState: true, hasTapAction: true),
      );
      handle.dispose();
    });

    testWidgets('calls onSelected with the tapped style', (tester) async {
      stubCache((_) => const Stream<FileResponse>.empty());
      final List<AiStylePreset> picked = <AiStylePreset>[];

      await tester.pumpWidget(_pickerHost(selected: AiStylePreset.nature, onSelected: picked.add));
      await tester.tap(find.text('Anime'));
      await tester.pump();

      expect(picked, <AiStylePreset>[AiStylePreset.anime]);
    });

    testWidgets('ignores taps while disabled', (tester) async {
      stubCache((_) => const Stream<FileResponse>.empty());
      final List<AiStylePreset> picked = <AiStylePreset>[];

      await tester.pumpWidget(_pickerHost(selected: AiStylePreset.nature, onSelected: picked.add, enabled: false));
      await tester.tap(find.text('Anime'));
      await tester.pump();

      expect(picked, isEmpty);
    });

    testWidgets('scrolls a newly selected tile fully into view', (tester) async {
      tester.view
        ..physicalSize = const Size(360, 800)
        ..devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      stubCache((_) => const Stream<FileResponse>.empty());

      await tester.pumpWidget(_pickerHost(selected: AiStylePreset.anime));
      await tester.pump();
      expect(_rowPixels(tester), 0.0);

      await tester.pumpWidget(_pickerHost(selected: AiStylePreset.ukiyoE));
      await tester.pumpAndSettle();

      expect(_rowPixels(tester), greaterThan(0));
      _expectTileInRowViewport(tester, _rowTile(AiStylePreset.ukiyoE));
    });

    testWidgets('reaches every tile from every starting tile', (tester) async {
      tester.view
        ..physicalSize = const Size(393, 800)
        ..devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      stubCache((_) => const Stream<FileResponse>.empty());

      for (final AiStylePreset from in AiStylePreset.values) {
        for (final AiStylePreset to in AiStylePreset.values) {
          await tester.pumpWidget(const SizedBox.shrink());
          await tester.pumpWidget(_pickerHost(selected: from));
          await tester.pumpAndSettle();
          await tester.pumpWidget(_pickerHost(selected: to));
          await tester.pumpAndSettle();
          _expectTileInRowViewport(tester, _rowTile(to));
        }
      }
    });

    testWidgets('opens already scrolled to an initially selected style', (tester) async {
      tester.view
        ..physicalSize = const Size(360, 800)
        ..devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      stubCache((_) => const Stream<FileResponse>.empty());

      await tester.pumpWidget(_pickerHost(selected: AiStylePreset.ukiyoE));
      await tester.pumpAndSettle();

      expect(_rowPixels(tester), greaterThan(0));
      _expectTileInRowViewport(tester, _rowTile(AiStylePreset.ukiyoE));
    });

    testWidgets('lands on the selected tile in one frame under reduce motion', (tester) async {
      tester.view
        ..physicalSize = const Size(360, 800)
        ..devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      stubCache((_) => const Stream<FileResponse>.empty());

      await tester.pumpWidget(_pickerHost(selected: AiStylePreset.anime));
      await tester.pump();

      await tester.pumpWidget(
        _host(
          reduceMotion: true,
          home: Scaffold(
            body: Center(
              child: AiStylePicker(selected: AiStylePreset.ukiyoE, onSelected: (_) {}),
            ),
          ),
        ),
      );
      await tester.pump();

      expect(_rowPixels(tester), greaterThan(0));
      _expectTileInRowViewport(tester, _rowTile(AiStylePreset.ukiyoE));
    });
  });

  group('showAiStyleSheet', () {
    testWidgets('picks a style from the sheet and scrolls the row to it', (tester) async {
      tester.view
        ..physicalSize = const Size(360, 800)
        ..devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final SemanticsHandle handle = tester.ensureSemantics();
      PrismDeviceCornerRadius.setValueForTesting(48);
      stubCache((_) => const Stream<FileResponse>.empty());

      await tester.pumpWidget(_host(home: const _SheetHost()));
      await tester.pump();

      await tester.tap(find.text('Open styles'));
      await tester.pumpAndSettle();

      expect(find.text('Choose a style'), findsOneWidget);
      expect(find.text(_subject), findsOneWidget);

      final Finder sheetGrid = find.byType(AiStyleGrid);
      expect(
        tester.getSemantics(find.descendant(of: sheetGrid, matching: _semanticsLabel('Style: Anime'))),
        matchesSemantics(
          label: 'Style: Anime',
          isButton: true,
          hasSelectedState: true,
          isSelected: true,
          hasTapAction: true,
        ),
      );

      final Finder sheetUkiyoE = find.descendant(of: sheetGrid, matching: find.text('Ukiyo-e'));
      await tester.scrollUntilVisible(
        sheetUkiyoE,
        300,
        scrollable: find.descendant(of: sheetGrid, matching: find.byType(Scrollable)),
      );
      await tester.ensureVisible(sheetUkiyoE);
      await tester.pump();
      await tester.tap(sheetUkiyoE);
      await tester.pumpAndSettle();

      expect(find.text('Choose a style'), findsNothing);
      expect(find.text('Current: Ukiyo-e'), findsOneWidget);
      expect(_rowPixels(tester), greaterThan(0));
      _expectTileInRowViewport(tester, _rowTile(AiStylePreset.ukiyoE));
      handle.dispose();
    });
  });
}

/// Hosts a row picker and a button that opens the sheet, and keeps the picked style as the row selection.
class _SheetHost extends StatefulWidget {
  const _SheetHost();

  @override
  State<_SheetHost> createState() => _SheetHostState();
}

class _SheetHostState extends State<_SheetHost> {
  AiStylePreset _current = AiStylePreset.anime;

  Future<void> _open() async {
    final AiStylePreset? picked = await showAiStyleSheet(context, selected: _current);
    if (picked != null) setState(() => _current = picked);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: <Widget>[
          TextButton(onPressed: _open, child: const Text('Open styles')),
          Text('Current: ${_current.label}'),
          AiStylePicker(selected: _current, onSelected: (AiStylePreset style) => setState(() => _current = style)),
        ],
      ),
    );
  }
}
