// ignore_for_file: depend_on_referenced_packages
import 'dart:async';
import 'dart:collection';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:Prism/core/cache/prism_full_image_cache.dart';
import 'package:Prism/core/cache/prism_image_cache.dart';
import 'package:Prism/core/monitoring/error_reporter.dart';
import 'package:Prism/core/monitoring/monitoring_runtime.dart';
import 'package:Prism/core/wallpaper/wallpaper_display_source.dart';
import 'package:Prism/core/wallpaper/wallpaper_source.dart';
import 'package:Prism/core/widgets/progressive_wallpaper_image.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:file/local.dart' as local;
import 'package:flutter/material.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import '../../support/fake_error_reporter.dart';

const String _thumb = 'https://img.test/thumb.jpg';
const String _thumb2 = 'https://img.test/thumb-2.jpg';
const String _full = 'https://img.test/full.jpg';
const String _full2 = 'https://img.test/full-2.jpg';

final List<int> _png = base64Decode(
  'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNkYAAAAAYAAjCB0C8AAAAASUVORK5CYII=',
);

Future<List<int>> _pngOf(int width, int height) async {
  final ui.PictureRecorder recorder = ui.PictureRecorder();
  Canvas(recorder).drawColor(Colors.white, BlendMode.src);
  final ui.Picture picture = recorder.endRecording();
  final ui.Image image = await picture.toImage(width, height);
  final ByteData? data = await image.toByteData(format: ui.ImageByteFormat.png);
  image.dispose();
  picture.dispose();
  return data!.buffer.asUint8List();
}

class _MockCacheManager extends Mock implements BaseCacheManager {}

/// Serves wallpaper URLs from files in [directory]. Counts requests per URL, fails the URLs in [failing] and holds
/// the URLs in [gates] until their completer completes.
class _WallCache {
  _WallCache(this.directory) {
    when(
      () => manager.getFileStream(
        any(),
        withProgress: any(named: 'withProgress'),
        headers: any(named: 'headers'),
        key: any(named: 'key'),
      ),
    ).thenAnswer((Invocation invocation) => _stream(invocation.positionalArguments.first as String));
    when(() => manager.getFileFromCache(any())).thenAnswer((_) async => null);
    when(() => manager.removeFile(any())).thenAnswer((_) async {});
  }

  final Directory directory;
  final _MockCacheManager manager = _MockCacheManager();
  final Map<String, int> requests = <String, int>{};
  final Set<String> failing = <String>{};
  final Map<String, Completer<void>> gates = <String, Completer<void>>{};
  final Map<String, String> paths = <String, String>{};
  final Map<String, List<int>> responses = <String, List<int>>{};

  Stream<FileResponse> _stream(String url) async* {
    requests[url] = (requests[url] ?? 0) + 1;
    final Completer<void>? gate = gates[url];
    if (gate != null) await gate.future;
    if (failing.contains(url)) throw Exception('fake network failure for $url');
    final String path = paths.putIfAbsent(url, () => '${directory.path}/${paths.length}.png');
    File(path).writeAsBytesSync(responses[url] ?? _png);
    yield FileInfo(
      const local.LocalFileSystem().file(path),
      FileSource.Online,
      DateTime.now().add(const Duration(days: 7)),
      url,
    );
  }
}

class _BreadcrumbReporter extends FakeErrorReporter {
  final List<String> categories = <String>[];

  @override
  Future<void> addBreadcrumb({
    required String message,
    String category = 'app.lifecycle',
    ErrorSeverity severity = ErrorSeverity.info,
    Map<String, Object?> data = const <String, Object?>{},
  }) {
    categories.add(category);
    return super.addBreadcrumb(message: message, category: category, severity: severity, data: data);
  }
}

/// Tracks only clones retained by ProgressiveWallpaperImage, not ImageProvider or RenderImage handles.
class _RetainedImageTracker {
  _RetainedImageTracker() {
    _previousOnCreate = ui.Image.onCreate;
    _previousOnDispose = ui.Image.onDispose;
    _onCreate = (ui.Image image) {
      _previousOnCreate?.call(image);
      if (StackTrace.current.toString().contains('_markShown')) {
        _live.add(image);
        if (_live.length > peak) peak = _live.length;
      }
    };
    _onDispose = (ui.Image image) {
      _live.remove(image);
      _previousOnDispose?.call(image);
    };
    ui.Image.onCreate = _onCreate;
    ui.Image.onDispose = _onDispose;
  }

  late final ui.ImageEventCallback? _previousOnCreate;
  late final ui.ImageEventCallback? _previousOnDispose;
  late final ui.ImageEventCallback _onCreate;
  late final ui.ImageEventCallback _onDispose;
  final Set<ui.Image> _live = HashSet<ui.Image>.identity();
  int peak = 0;

  int get live => _live.length;

  void restore() {
    if (ui.Image.onCreate == _onCreate) ui.Image.onCreate = _previousOnCreate;
    if (ui.Image.onDispose == _onDispose) ui.Image.onDispose = _previousOnDispose;
  }
}

WallpaperDisplaySource _display({String thumbnail = _thumb, String full = _full, String id = 'w1'}) =>
    WallpaperDisplaySource(thumbnail: thumbnail, full: full, id: id, source: WallpaperSource.wallhaven);

Widget _app(Widget child, {bool disableAnimations = false}) => MaterialApp(
  home: MediaQuery(
    data: MediaQueryData(size: const Size(320, 480), disableAnimations: disableAnimations),
    child: SizedBox(width: 320, height: 480, child: child),
  ),
);

/// The URL, file path or asset of the picture an [ImageProvider] paints.
String _sourceOf(ImageProvider provider) {
  final ImageProvider inner = provider is ResizeImage ? provider.imageProvider : provider;
  if (inner is CachedNetworkImageProvider) return inner.url;
  if (inner is FileImage) return 'file:${inner.file.path}';
  return inner.runtimeType.toString();
}

/// The sources of every picture that is painted right now, in tree order.
List<String> _painted(WidgetTester tester) => tester
    .elementList(find.byType(RawImage))
    .map((Element raw) {
      final Image? image = raw.findAncestorWidgetOfExactType<Image>();
      return image == null ? null : _sourceOf(image.image);
    })
    .whereType<String>()
    .toList();

int _visibleImageFrames(WidgetTester tester) => tester
    .elementList(find.byType(RawImage))
    .map((Element raw) => raw.widget as RawImage)
    .where((RawImage raw) => raw.image != null)
    .length;

Finder _imageFrom(String source) =>
    find.byWidgetPredicate((Widget widget) => widget is Image && _sourceOf(widget.image) == source);

Future<void> _pumpUntil(WidgetTester tester, bool Function() done) async {
  final Stopwatch clock = Stopwatch()..start();
  while (!done() && clock.elapsed < const Duration(seconds: 5)) {
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 10)));
    await tester.pump();
  }
  expect(done(), isTrue, reason: 'condition not reached in time');
}

void main() {
  late Directory directory;
  late _WallCache wallCache;
  late _BreadcrumbReporter reporter;
  late ErrorReporter previousReporter;

  setUp(() async {
    directory = await Directory.systemTemp.createTemp('progressive-wallpaper-test-');
    wallCache = _WallCache(directory);
    PrismImageCache.testOverride = wallCache.manager;
    PrismFullImageCache.testOverride = wallCache.manager;
    reporter = _BreadcrumbReporter();
    previousReporter = MonitoringRuntime.reporter;
    MonitoringRuntime.reporter = reporter;
  });

  tearDown(() async {
    ProgressiveWallpaperImage.offlineCopyOverride = null;
    PrismImageCache.testOverride = null;
    PrismFullImageCache.testOverride = null;
    MonitoringRuntime.reporter = previousReporter;
    PaintingBinding.instance.imageCache.clear();
    await directory.delete(recursive: true);
  });

  testWidgets('shows the thumbnail first, then the full picture, and drops the thumbnail', (tester) async {
    wallCache.gates[_full] = Completer<void>();
    await tester.pumpWidget(_app(ProgressiveWallpaperImage(display: _display())));
    await _pumpUntil(tester, () => _painted(tester).contains(_thumb));
    expect(_painted(tester), <String>[_thumb]);

    wallCache.gates[_full]!.complete();
    await _pumpUntil(tester, () => _painted(tester).contains(_full));
    // The full picture fades in over 280 ms on the fake clock. The end callback rebuilds one frame later.
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pump();

    expect(_painted(tester), <String>[_full]);
    expect(_imageFrom(_thumb), findsNothing);
  });

  testWidgets('reports the full picture size once it paints, never the thumbnail size', (tester) async {
    final List<Size> sizes = <Size>[];
    wallCache.responses[_full] = (await tester.runAsync(() => _pngOf(3, 2)))!;
    wallCache.gates[_full] = Completer<void>();
    await tester.pumpWidget(_app(ProgressiveWallpaperImage(display: _display(), onPictureSize: sizes.add)));
    await _pumpUntil(tester, () => _painted(tester).contains(_thumb));
    await tester.pump();
    // Some sources crop the thumbnail, so its shape is not the wallpaper's.
    expect(sizes, isEmpty);

    wallCache.gates[_full]!.complete();
    await _pumpUntil(tester, () => sizes.isNotEmpty);
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pump();

    expect(sizes, <Size>[const Size(3, 2)]);
    final ResizeImage resized = tester.widget<Image>(_imageFrom(_full)).image as ResizeImage;
    expect(resized.policy, ResizeImagePolicy.fit);
  });

  testWidgets('reports the size again for a new wall with the same pixel dimensions', (tester) async {
    final List<Size> sizes = <Size>[];
    await tester.pumpWidget(_app(ProgressiveWallpaperImage(display: _display(), onPictureSize: sizes.add)));
    await _pumpUntil(tester, () => sizes.isNotEmpty);
    await tester.pumpWidget(
      _app(
        ProgressiveWallpaperImage(
          display: _display(id: 'w2'),
          onPictureSize: sizes.add,
        ),
      ),
    );
    await _pumpUntil(tester, () => sizes.length > 1);

    expect(sizes, <Size>[const Size(1, 1), const Size(1, 1)]);
  });

  testWidgets('inline size callback that rebuilds does not report repeatedly', (tester) async {
    int reports = 0;
    await tester.pumpWidget(
      _app(
        StatefulBuilder(
          builder: (BuildContext context, StateSetter setState) =>
              ProgressiveWallpaperImage(display: _display(), onPictureSize: (_) => setState(() => reports++)),
        ),
      ),
    );
    await _pumpUntil(tester, () => reports == 1);
    for (int i = 0; i < 3; i++) {
      await tester.pump();
    }

    expect(reports, 1);
    expect(tester.takeException(), isNull);
  });

  testWidgets('keeps the same aspect-fit decode provider when the fixed decode box is unchanged', (tester) async {
    final List<Size> sizes = <Size>[];
    const WallpaperDisplaySource wideWall = WallpaperDisplaySource(
      thumbnail: _thumb,
      full: _full,
      id: 'w1',
      source: WallpaperSource.wallhaven,
      pixelSize: Size(4000, 2000),
    );
    late StateSetter rebuild;
    await tester.pumpWidget(
      _app(
        StatefulBuilder(
          builder: (BuildContext context, StateSetter setState) {
            rebuild = setState;
            return ProgressiveWallpaperImage(
              display: wideWall,
              decodeBox: const Size(1000, 1000),
              onPictureSize: sizes.add,
            );
          },
        ),
      ),
    );
    await _pumpUntil(tester, () => _painted(tester).contains(_full));
    final ImageProvider before = tester.widget<Image>(_imageFrom(_full)).image;
    expect(before, isA<ResizeImage>());
    final ResizeImage resized = before as ResizeImage;
    expect((resized.width, resized.height, resized.policy), (2000, 1000, ResizeImagePolicy.fit));

    rebuild(() {});
    await tester.pump();
    final ImageProvider after = tester.widget<Image>(_imageFrom(_full)).image;

    expect(after, before);
    expect(wallCache.requests[_full], 1);
    expect(sizes, <Size>[const Size(1, 1)]);
  });

  testWidgets('uses the shared thumbnail while checking for an on-device full copy', (tester) async {
    final Completer<File?> deviceLookup = Completer<File?>();
    ProgressiveWallpaperImage.offlineCopyOverride = (_) => deviceLookup.future;

    await tester.pumpWidget(
      _app(
        const ProgressiveWallpaperImage(
          display: WallpaperDisplaySource(thumbnail: _full, full: _full, id: 'w1', source: WallpaperSource.wallhaven),
        ),
      ),
    );
    await _pumpUntil(tester, () => _painted(tester).contains(_full));

    expect(_painted(tester), <String>[_full]);
    deviceLookup.complete(null);
    await tester.pump();
  });

  testWidgets('does not treat an invalid thumbnail link as a local file', (tester) async {
    await tester.pumpWidget(
      _app(
        ProgressiveWallpaperImage(
          display: const WallpaperDisplaySource(
            thumbnail: '/etc/passwd',
            full: '',
            id: 'w1',
            source: WallpaperSource.wallhaven,
          ),
          errorBuilder: (_, _) => const Text('no image'),
        ),
      ),
    );
    await _pumpUntil(tester, () => find.text('no image').evaluate().isNotEmpty);

    expect(find.text('no image'), findsOneWidget);
    expect(_imageFrom('file:/etc/passwd'), findsNothing);
    expect(wallCache.requests, isEmpty);
  });

  testWidgets('retries a failed full picture once, then keeps the thumbnail', (tester) async {
    wallCache.failing.add(_full);
    await tester.pumpWidget(_app(ProgressiveWallpaperImage(display: _display())));
    await _pumpUntil(tester, () => reporter.categories.isNotEmpty && _painted(tester).contains(_thumb));
    await tester.pump(const Duration(milliseconds: 300));

    expect(wallCache.requests[_full], 2);
    expect(reporter.categories, <String>['wallpaper.image']);
    expect(_painted(tester), <String>[_thumb]);
    expect(tester.takeException(), isNull);
  });

  testWidgets('never shows the thumbnail again once the full picture is shown', (tester) async {
    await tester.pumpWidget(_app(ProgressiveWallpaperImage(display: _display())));
    await _pumpUntil(tester, () => _painted(tester).contains(_full));
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pump();

    await tester.pumpWidget(_app(ProgressiveWallpaperImage(display: _display(thumbnail: _thumb2))));
    for (var i = 0; i < 3; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }

    expect(_painted(tester), <String>[_full]);
    expect(_imageFrom(_thumb2), findsNothing);
    expect(wallCache.requests.containsKey(_thumb2), isFalse);
  });

  testWidgets('keeps the painted full picture if a same-wall replacement fails', (tester) async {
    await tester.pumpWidget(_app(ProgressiveWallpaperImage(display: _display())));
    await _pumpUntil(tester, () => _painted(tester).contains(_full));
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pump();

    PaintingBinding.instance.imageCache.clear();
    await tester.pump();
    wallCache.gates[_thumb] = Completer<void>();
    wallCache.failing.add(_full2);
    await tester.pumpWidget(_app(ProgressiveWallpaperImage(display: _display(full: _full2))));
    await _pumpUntil(tester, () => reporter.categories.isNotEmpty);

    expect(
      _visibleImageFrames(tester),
      greaterThan(0),
      reason: 'the failed replacement and loading thumbnail must not leave a blank frame',
    );
    expect(find.byKey(const ValueKey<String>('last-full')), findsOneWidget);
    expect(tester.widget<RawImage>(find.byKey(const ValueKey<String>('last-full'))).image, isNotNull);
    expect(_imageFrom(_thumb), findsNothing);
    expect(wallCache.requests[_full], 1);
  });

  testWidgets('does not report the held full frame again while its replacement loads', (tester) async {
    final List<Size> sizes = <Size>[];
    wallCache.responses[_full2] = (await tester.runAsync(() => _pngOf(5, 3)))!;
    wallCache.gates[_full2] = Completer<void>();
    await tester.pumpWidget(_app(ProgressiveWallpaperImage(display: _display(), onPictureSize: sizes.add)));
    await _pumpUntil(tester, () => sizes.isNotEmpty);
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pump();

    await tester.pumpWidget(
      _app(
        ProgressiveWallpaperImage(
          display: _display(full: _full2),
          onPictureSize: sizes.add,
        ),
      ),
    );
    await _pumpUntil(tester, () => wallCache.requests.containsKey(_full2));
    await tester.pump();

    expect(sizes, <Size>[const Size(1, 1)]);
    expect(find.byKey(const ValueKey<String>('last-full')), findsOneWidget);

    wallCache.gates[_full2]!.complete();
    await _pumpUntil(tester, () => sizes.length > 1);
    await tester.pump(const Duration(milliseconds: 300));

    expect(sizes, <Size>[const Size(1, 1), const Size(5, 3)]);
  });

  testWidgets('keeps the full frame when a preview is unavailable but drops it when the wall is withheld', (
    tester,
  ) async {
    const WallpaperDisplaySource available = WallpaperDisplaySource(
      thumbnail: _thumb,
      full: _full,
      id: 'prism-1',
      source: WallpaperSource.prism,
    );
    await tester.pumpWidget(_app(const ProgressiveWallpaperImage(display: available)));
    await _pumpUntil(tester, () => _painted(tester).contains(_full));
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pump();

    await tester.pumpWidget(
      _app(
        const ProgressiveWallpaperImage(
          display: WallpaperDisplaySource(thumbnail: _thumb, full: '', id: 'prism-1', source: WallpaperSource.prism),
        ),
      ),
    );
    expect(find.byKey(const ValueKey<String>('last-full')), findsOneWidget);
    expect(_imageFrom(_thumb), findsNothing);

    await tester.pumpWidget(
      _app(
        const ProgressiveWallpaperImage(
          display: WallpaperDisplaySource(
            thumbnail: _thumb,
            full: '',
            id: 'prism-1',
            source: WallpaperSource.prism,
            withheld: true,
          ),
        ),
      ),
    );
    await _pumpUntil(tester, () => _painted(tester).contains(_thumb));

    expect(find.byKey(const ValueKey<String>('last-full')), findsNothing);
  });

  testWidgets('draws the on-device copy over the network full picture', (tester) async {
    final File offline = File('${directory.path}/offline.png')..writeAsBytesSync(_png);
    ProgressiveWallpaperImage.offlineCopyOverride = (_) async => offline;
    final String offlineSource = 'file:${offline.path}';

    await tester.pumpWidget(_app(ProgressiveWallpaperImage(display: _display())));
    await _pumpUntil(tester, () => _painted(tester).contains(offlineSource));
    await tester.pump();

    expect(_painted(tester), <String>[offlineSource]);
    expect(wallCache.requests.containsKey(_full), isFalse);
  });

  testWidgets('checks for an offline Prism original when its display preview is unavailable', (tester) async {
    final File offline = File('${directory.path}/offline-prism.png')..writeAsBytesSync(_png);
    ProgressiveWallpaperImage.offlineCopyOverride = (_) async => offline;

    await tester.pumpWidget(
      _app(
        const ProgressiveWallpaperImage(
          display: WallpaperDisplaySource(thumbnail: '', full: '', id: 'offline-prism', source: WallpaperSource.prism),
        ),
      ),
    );
    await _pumpUntil(tester, () => _painted(tester).contains('file:${offline.path}'));

    expect(wallCache.requests, isEmpty);
  });

  testWidgets('releases its retained decoded image when removed', (tester) async {
    await tester.pumpWidget(_app(ProgressiveWallpaperImage(display: _display())));
    await _pumpUntil(tester, () => _painted(tester).contains(_full));
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pump();
    expect(find.byKey(const ValueKey<String>('last-full')), findsOneWidget);
    final retainedImage = tester.widget<RawImage>(find.byKey(const ValueKey<String>('last-full'))).image!;
    expect(retainedImage.debugDisposed, isFalse);

    await tester.pumpWidget(_app(const SizedBox.shrink()));

    expect(retainedImage.debugDisposed, isTrue);
    expect(tester.takeException(), isNull);
  });

  testWidgets('releases the prior held frame after a same-wall replacement paints', (tester) async {
    await tester.pumpWidget(_app(ProgressiveWallpaperImage(display: _display())));
    await _pumpUntil(tester, () => _painted(tester).contains(_full));
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pump();
    final RawImage first = tester.widget<RawImage>(find.byKey(const ValueKey<String>('last-full')));

    await tester.pumpWidget(_app(ProgressiveWallpaperImage(display: _display(full: _full2))));
    await _pumpUntil(tester, () => _painted(tester).contains(_full2));
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pump();

    expect(first.image!.debugDisposed, isTrue);
    expect(find.byKey(const ValueKey<String>('last-full')), findsOneWidget);
    expect(_imageFrom(_thumb), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('releases its held frame when the wall changes', (tester) async {
    await tester.pumpWidget(_app(ProgressiveWallpaperImage(display: _display())));
    await _pumpUntil(tester, () => _painted(tester).contains(_full));
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pump();
    final RawImage held = tester.widget<RawImage>(find.byKey(const ValueKey<String>('last-full')));

    await tester.pumpWidget(
      _app(
        ProgressiveWallpaperImage(
          display: _display(full: _full2, id: 'w2'),
        ),
      ),
    );
    await tester.pump();

    expect(held.image!.debugDisposed, isTrue);
    expect(find.byKey(const ValueKey<String>('last-full')), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('releases its held frame when retry starts', (tester) async {
    VoidCallback? retry;
    await tester.pumpWidget(
      _app(
        ProgressiveWallpaperImage(
          display: _display(),
          errorBuilder: (_, VoidCallback callback) {
            retry = callback;
            return const Text('retry');
          },
        ),
      ),
    );
    await _pumpUntil(tester, () => _painted(tester).contains(_full));
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pump();
    final RawImage held = tester.widget<RawImage>(find.byKey(const ValueKey<String>('last-full')));

    retry!();
    await tester.pump();

    expect(held.image!.debugDisposed, isTrue);
    expect(find.byKey(const ValueKey<String>('last-full')), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('reports the size again when retry loads the full picture', (tester) async {
    final List<Size> sizes = <Size>[];
    VoidCallback? retry;
    await tester.pumpWidget(
      _app(
        ProgressiveWallpaperImage(
          display: _display(),
          onPictureSize: sizes.add,
          errorBuilder: (_, VoidCallback callback) {
            retry = callback;
            return const Text('retry');
          },
        ),
      ),
    );
    await _pumpUntil(tester, () => sizes.isNotEmpty);
    retry!();
    await tester.pump();
    await _pumpUntil(tester, () => sizes.length > 1);

    expect(sizes, <Size>[const Size(1, 1), const Size(1, 1)]);
  });

  testWidgets('holds at most one widget-retained image clone across replacements, retry, wall change, and dispose', (
    tester,
  ) async {
    final _RetainedImageTracker tracker = _RetainedImageTracker();
    addTearDown(tracker.restore);
    VoidCallback? retry;

    await tester.pumpWidget(
      _app(
        ProgressiveWallpaperImage(
          display: _display(),
          errorBuilder: (_, VoidCallback callback) {
            retry = callback;
            return const Text('retry');
          },
        ),
      ),
    );
    await _pumpUntil(tester, () => _painted(tester).contains(_full));
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pump();
    expect(tracker.live, 1);

    await tester.pumpWidget(_app(ProgressiveWallpaperImage(display: _display(full: _full2))));
    await _pumpUntil(tester, () => _painted(tester).contains(_full2));
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pump();
    expect(tracker.live, 1);

    await tester.pumpWidget(_app(ProgressiveWallpaperImage(display: _display(id: 'w2'))));
    expect(tracker.live, 0);
    await _pumpUntil(tester, () => _painted(tester).contains(_full));
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pump();
    expect(tracker.live, 1);

    retry!();
    await tester.pump();
    expect(tracker.live, 0);
    await _pumpUntil(tester, () => _painted(tester).contains(_full));
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pump();
    expect(tracker.live, 1);

    await tester.pumpWidget(_app(const SizedBox.shrink()));
    expect(tracker.live, 0);
    expect(tracker.peak, 1);
    expect(tester.takeException(), isNull);
  });

  testWidgets('ignores a retry callback invoked after dispose', (tester) async {
    VoidCallback? retry;
    await tester.pumpWidget(
      _app(
        ProgressiveWallpaperImage(
          display: _display(),
          errorBuilder: (_, VoidCallback callback) {
            retry = callback;
            return const Text('retry');
          },
        ),
      ),
    );
    await tester.pumpWidget(_app(const SizedBox.shrink()));

    retry!();

    expect(tester.takeException(), isNull);
  });

  testWidgets('does not report a full picture that resolves after dispose', (tester) async {
    final List<Size> sizes = <Size>[];
    wallCache.gates[_full] = Completer<void>();
    await tester.pumpWidget(_app(ProgressiveWallpaperImage(display: _display(), onPictureSize: sizes.add)));
    await _pumpUntil(tester, () => _painted(tester).contains(_thumb));

    await tester.pumpWidget(_app(const SizedBox.shrink()));
    wallCache.gates[_full]!.complete();
    await tester.pump();
    await tester.pump();

    expect(sizes, isEmpty);
    expect(tester.takeException(), isNull);
  });

  testWidgets('ignores an older on-device lookup after the wall changes', (tester) async {
    final File oldCopy = File('${directory.path}/old.png')..writeAsBytesSync(_png);
    final File newCopy = File('${directory.path}/new.png')..writeAsBytesSync(_png);
    final Completer<File?> oldLookup = Completer<File?>();
    final Completer<File?> newLookup = Completer<File?>();
    ProgressiveWallpaperImage.offlineCopyOverride = (display) =>
        display.id == 'old' ? oldLookup.future : newLookup.future;

    await tester.pumpWidget(_app(ProgressiveWallpaperImage(display: _display(id: 'old'))));
    await tester.pumpWidget(_app(ProgressiveWallpaperImage(display: _display(id: 'new'))));
    newLookup.complete(newCopy);
    await _pumpUntil(tester, () => _painted(tester).contains('file:${newCopy.path}'));

    oldLookup.complete(oldCopy);
    await tester.pump();
    await tester.pump();

    expect(_painted(tester), <String>['file:${newCopy.path}']);
  });

  testWidgets('shows the full picture without a fade when reduce motion is on', (tester) async {
    await tester.pumpWidget(_app(ProgressiveWallpaperImage(display: _display()), disableAnimations: true));
    await _pumpUntil(tester, () => _painted(tester).contains(_full));

    final Element fullRaw = tester
        .elementList(find.byType(RawImage))
        .singleWhere((Element raw) => _sourceOf(raw.findAncestorWidgetOfExactType<Image>()!.image) == _full);
    final List<double> opacities = <double>[];
    fullRaw.visitAncestorElements((Element ancestor) {
      if (ancestor.widget is Opacity) opacities.add((ancestor.widget as Opacity).opacity);
      return true;
    });
    expect(opacities.where((double opacity) => opacity < 1), isEmpty);

    await tester.pump();
    expect(_painted(tester), <String>[_full]);
    expect(_imageFrom(_thumb), findsNothing);
  });
}
