import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:Prism/core/analytics/analytics_runtime.dart';
import 'package:Prism/core/analytics/events/events.dart';
import 'package:Prism/features/wallpaper_position/biz/bloc/wallpaper_position_bloc.j.dart';
import 'package:Prism/features/wallpaper_position/domain/entities/wallpaper_placement.dart';
import 'package:Prism/features/wallpaper_position/domain/repositories/wallpaper_position_repository.dart';
import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../support/fake_app_analytics.dart';

class _FakeRepository implements WallpaperPositionRepository {
  _FakeRepository(this.directory);

  final Directory directory;
  ui.Image? image;
  Object? loadError;
  Object? renderError;
  Completer<void>? renderGate;
  final List<String> loaded = <String>[];
  final List<(WallpaperPlacement, ui.Size)> renders = <(WallpaperPlacement, ui.Size)>[];

  @override
  Future<PlacementSource> load(String url) async {
    loaded.add(url);
    final Object? error = loadError;
    if (error != null) throw error;
    return PlacementSource(image: image!, dominantColor: const Color(0xFF123456));
  }

  @override
  Future<File> render(PlacementSource source, WallpaperPlacement placement, ui.Size outputSize) async {
    renders.add((placement, outputSize));
    await renderGate?.future;
    final Object? error = renderError;
    if (error != null) throw error;
    final ByteData data = (await source.image.toByteData(format: ui.ImageByteFormat.png))!;
    final Directory folder = Directory('${directory.path}/position_${renders.length}')..createSync();
    return File('${folder.path}/placement.png')..writeAsBytesSync(data.buffer.asUint8List());
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory directory;
  late _FakeRepository repository;
  late FakeAppAnalytics analytics;
  late WallpaperPositionBloc bloc;

  setUp(() {
    directory = Directory.systemTemp.createTempSync('position_bloc_test_');
    repository = _FakeRepository(directory);
    analytics = FakeAppAnalytics();
    AnalyticsRuntime.instance = analytics;
    bloc = WallpaperPositionBloc(repository);
  });

  tearDown(() async {
    await bloc.close();
    AnalyticsRuntime.reset();
    directory.deleteSync(recursive: true);
  });

  Future<ui.Image> tinyImage() {
    final ui.PictureRecorder recorder = ui.PictureRecorder();
    Canvas(recorder).drawRect(const Rect.fromLTWH(0, 0, 4, 8), Paint()..color = const Color(0xFFFFFFFF));
    return recorder.endRecording().toImage(4, 8);
  }

  // Waits on real time for a state, so a slow runner cannot assert early or leak a late render into the next test.
  Future<void> until(WidgetTester tester, bool Function(WallpaperPositionState state) done, {void Function()? then}) =>
      tester.runAsync(() async {
        final Future<void> reached = bloc.stream.firstWhere(done).timeout(const Duration(seconds: 10));
        then?.call();
        await reached;
      });

  Future<void> start(WidgetTester tester) async {
    await tester.runAsync(() async => repository.image = await tinyImage());
    await until(
      tester,
      (state) => state.status != WallpaperPositionStatus.loading,
      then: () => bloc.add(
        const WallpaperPositionEvent.started(
          imageUrl: 'https://img.test/full.jpg',
          thumbnailUrl: 'https://img.test/thumb.jpg',
          entryPoint: 'wallpaper_detail',
        ),
      ),
    );
  }

  testWidgets('starts loading, then is ready with the decoded wall', (tester) async {
    expect(bloc.state.status, WallpaperPositionStatus.loading);

    await start(tester);

    expect(bloc.state.status, WallpaperPositionStatus.ready);
    expect(bloc.state.source?.dominantColor, const Color(0xFF123456));
    expect(repository.loaded, ['https://img.test/full.jpg']);
    expect(bloc.state.placement, const WallpaperPlacement());
  });

  testWidgets('opening tracks wallpaper_position_opened with the entry point', (tester) async {
    await start(tester);

    expect(analytics.events.whereType<WallpaperPositionOpenedEvent>().single.source, 'wallpaper_detail');
  });

  testWidgets('a wall that cannot load fails, and starting again recovers', (tester) async {
    repository.loadError = StateError('offline');
    await start(tester);
    expect(bloc.state.status, WallpaperPositionStatus.failed);

    repository.loadError = null;
    await start(tester);
    expect(bloc.state.status, WallpaperPositionStatus.ready);
  });

  testWidgets('fit, move, dim and preview mode change the placement', (tester) async {
    await start(tester);

    bloc.add(const WallpaperPositionEvent.fitChanged(PlacementFit.fitBlur));
    bloc.add(const WallpaperPositionEvent.moved(dx: 0.5, dy: -0.25, zoom: 2));
    bloc.add(const WallpaperPositionEvent.dimChanged(0.3));
    bloc.add(const WallpaperPositionEvent.previewModeChanged(PlacementPreviewMode.home));
    await tester.pump();

    expect(
      bloc.state.placement,
      const WallpaperPlacement(
        fit: PlacementFit.fitBlur,
        dx: 0.5,
        dy: -0.25,
        zoom: 2,
        dim: 0.3,
        previewMode: PlacementPreviewMode.home,
      ),
    );
  });

  testWidgets('dim is free and stops at 60 percent', (tester) async {
    await start(tester);

    bloc.add(const WallpaperPositionEvent.dimChanged(0.9));
    await tester.pump();

    expect(bloc.state.placement.dim, 0.6);
  });

  testWidgets('a fit change or reset asks the preview to sync, a gesture does not', (tester) async {
    await start(tester);
    final int start0 = bloc.state.syncToken;

    bloc.add(const WallpaperPositionEvent.moved(dx: 1, dy: 1, zoom: 3));
    await tester.pump();
    expect(bloc.state.syncToken, start0);

    bloc.add(const WallpaperPositionEvent.fitChanged(PlacementFit.fitColor));
    await tester.pump();
    expect(bloc.state.syncToken, start0 + 1);

    bloc.add(const WallpaperPositionEvent.resetRequested());
    await tester.pump();
    expect(bloc.state.syncToken, start0 + 2);
  });

  testWidgets('reset restores the placement but keeps the lock or home view', (tester) async {
    await start(tester);
    bloc.add(const WallpaperPositionEvent.previewModeChanged(PlacementPreviewMode.home));
    bloc.add(const WallpaperPositionEvent.dimChanged(0.4));
    bloc.add(const WallpaperPositionEvent.moved(dx: 1, dy: 1, zoom: 3));
    bloc.add(const WallpaperPositionEvent.resetRequested());
    await tester.pump();

    expect(bloc.state.placement, const WallpaperPlacement(previewMode: PlacementPreviewMode.home));
  });

  group('done', () {
    const ui.Size screen = ui.Size(1080, 2400);

    testWidgets('renders at the output size and holds the PNG as the placed wall', (tester) async {
      await start(tester);
      bloc.add(const WallpaperPositionEvent.dimChanged(0.2));
      await until(
        tester,
        (state) => state.placedToken == 1,
        then: () => bloc.add(const WallpaperPositionEvent.doneRequested(outputSize: screen)),
      );

      expect(repository.renders.single.$2, screen);
      expect(repository.renders.single.$1.dim, 0.2);
      expect(bloc.state.placed?.path, endsWith('position_1${Platform.pathSeparator}placement.png'));
      expect(bloc.state.placed?.placement.dim, 0.2);
      expect(bloc.state.placedToken, 1);
      expect(bloc.state.status, WallpaperPositionStatus.ready);
      expect(bloc.state.renderErrorToken, 0);
    });

    testWidgets('goes through rendering before ready', (tester) async {
      repository.renderGate = Completer<void>();
      await start(tester);
      await until(
        tester,
        (state) => state.status == WallpaperPositionStatus.rendering,
        then: () => bloc.add(const WallpaperPositionEvent.doneRequested(outputSize: screen)),
      );
      expect(bloc.state.status, WallpaperPositionStatus.rendering);

      await until(tester, (state) => state.placedToken == 1, then: repository.renderGate!.complete);
      expect(bloc.state.status, WallpaperPositionStatus.ready);
    });

    testWidgets('a render error emits renderErrorToken 1 and returns to ready', (tester) async {
      repository.renderError = StateError('out of memory');
      await start(tester);
      await until(
        tester,
        (state) => state.renderErrorToken == 1,
        then: () => bloc.add(const WallpaperPositionEvent.doneRequested(outputSize: screen)),
      );

      expect(bloc.state.status, WallpaperPositionStatus.ready);
      expect(bloc.state.placed, isNull);
      expect(bloc.state.placedToken, 0);
    });

    testWidgets('a second Done while rendering is ignored', (tester) async {
      repository.renderGate = Completer<void>();
      await start(tester);
      await until(
        tester,
        (state) => state.status == WallpaperPositionStatus.rendering,
        then: () => bloc.add(const WallpaperPositionEvent.doneRequested(outputSize: screen)),
      );

      bloc.add(const WallpaperPositionEvent.doneRequested(outputSize: screen));
      await tester.pump();
      expect(bloc.state.status, WallpaperPositionStatus.rendering);
      await until(tester, (state) => state.placedToken == 1, then: repository.renderGate!.complete);

      expect(repository.renders, hasLength(1));
    });

    testWidgets('Done before the wall has loaded does nothing', (tester) async {
      bloc.add(const WallpaperPositionEvent.doneRequested(outputSize: screen));
      await tester.pump();

      expect(repository.renders, isEmpty);
      expect(bloc.state.status, WallpaperPositionStatus.loading);
    });
  });
}
