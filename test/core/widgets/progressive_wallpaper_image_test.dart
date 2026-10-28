// ignore_for_file: depend_on_referenced_packages
import 'dart:async';
import 'dart:convert';
import 'dart:io';

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

final List<int> _png = base64Decode(
  'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNkYAAAAAYAAjCB0C8AAAAASUVORK5CYII=',
);

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

  Stream<FileResponse> _stream(String url) async* {
    requests[url] = (requests[url] ?? 0) + 1;
    final Completer<void>? gate = gates[url];
    if (gate != null) await gate.future;
    if (failing.contains(url)) throw Exception('fake network failure for $url');
    final String path = paths.putIfAbsent(url, () => '${directory.path}/${paths.length}.png');
    File(path).writeAsBytesSync(_png);
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

WallpaperDisplaySource _display({String thumbnail = _thumb}) =>
    WallpaperDisplaySource(thumbnail: thumbnail, full: _full, id: 'w1', source: WallpaperSource.wallhaven);

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
    .map((Element raw) => _sourceOf(raw.findAncestorWidgetOfExactType<Image>()!.image))
    .toList();

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
