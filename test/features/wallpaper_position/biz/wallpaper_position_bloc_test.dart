import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:Prism/core/analytics/analytics_runtime.dart';
import 'package:Prism/core/analytics/events/events.dart';
import 'package:Prism/core/di/injection.dart';
import 'package:Prism/core/persistence/data_sources/settings_local_data_source.dart';
import 'package:Prism/core/platform/wallpaper_service.dart';
import 'package:Prism/features/wallpaper_history/wallpaper_history.dart';
import 'package:Prism/features/wallpaper_position/biz/bloc/wallpaper_position_bloc.j.dart';
import 'package:Prism/features/wallpaper_position/domain/entities/wallpaper_placement.dart';
import 'package:Prism/features/wallpaper_position/domain/repositories/wallpaper_position_repository.dart';
import 'package:async_wallpaper/async_wallpaper.dart' as aw;
// ignore: implementation_imports
import 'package:async_wallpaper/src/wallpaper_client.dart';
import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../support/fake_app_analytics.dart';
import '../../../support/in_memory_local_store.dart';

class _FakeRepository implements WallpaperPositionRepository {
  _FakeRepository(this.directory);

  final Directory directory;
  ui.Image? image;
  Object? loadError;
  Object? renderError;
  Completer<void>? renderGate;
  final List<String> loaded = <String>[];
  final List<(WallpaperPlacement, ui.Size)> renders = <(WallpaperPlacement, ui.Size)>[];
  final List<File> discarded = <File>[];

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
    return File('${directory.path}/placement_${renders.length}.png')..writeAsBytesSync(<int>[1, 2, 3]);
  }

  @override
  Future<void> discard(File file) async => discarded.add(file);
}

class _Client implements WallpaperClient {
  aw.WallpaperOperationStatus status = aw.WallpaperOperationStatus.applied;
  final List<aw.StaticWallpaperRequest> requests = <aw.StaticWallpaperRequest>[];

  @override
  Future<aw.WallpaperCapabilities> getCapabilities() async => const aw.WallpaperCapabilities();

  @override
  Future<aw.WallpaperOperationResult> applyWallpaper(aw.StaticWallpaperRequest request) async {
    requests.add(request);
    return aw.WallpaperOperationResult(status: status, requestedTarget: request.target);
  }

  @override
  Future<aw.WallpaperOperationResult> prepareVideoWallpaper(aw.VideoWallpaperRequest request) =>
      throw UnimplementedError();

  @override
  Future<aw.WallpaperOperationResult> openLiveWallpaperPreview(aw.VideoWallpaperRequest request) =>
      throw UnimplementedError();

  @override
  Future<aw.WallpaperOperationResult> applyOpenGlWallpaper(aw.OpenGlLiveWallpaperRequest request) =>
      throw UnimplementedError();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory directory;
  late _FakeRepository repository;
  late _Client client;
  late FakeAppAnalytics analytics;
  late WallpaperHistoryStore store;
  late WallpaperPositionBloc bloc;

  setUp(() {
    directory = Directory.systemTemp.createTempSync('position_bloc_test_');
    repository = _FakeRepository(directory);
    client = _Client();
    aw.AsyncWallpaper.debugSetClient(client);
    analytics = FakeAppAnalytics();
    AnalyticsRuntime.instance = analytics;
    store = WallpaperHistoryStore(SettingsLocalDataSource(InMemoryLocalStore()));
    getIt.registerSingleton<WallpaperHistoryStore>(store);
    bloc = WallpaperPositionBloc(repository);
  });

  tearDown(() async {
    await bloc.close();
    await getIt.reset();
    AnalyticsRuntime.reset();
    aw.AsyncWallpaper.debugResetClient();
    directory.deleteSync(recursive: true);
  });

  Future<ui.Image> tinyImage() {
    final ui.PictureRecorder recorder = ui.PictureRecorder();
    Canvas(recorder).drawRect(const Rect.fromLTWH(0, 0, 4, 8), Paint()..color = const Color(0xFFFFFFFF));
    return recorder.endRecording().toImage(4, 8);
  }

  Future<void> settle() => Future<void>.delayed(const Duration(milliseconds: 20));

  Future<void> start(WidgetTester tester) async {
    await tester.runAsync(() async {
      repository.image = await tinyImage();
      bloc.add(
        const WallpaperPositionEvent.started(
          imageUrl: 'https://img.test/full.jpg',
          thumbnailUrl: 'https://img.test/thumb.jpg',
          entryPoint: 'wallpaper_detail',
        ),
      );
      await settle();
    });
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
    await tester.runAsync(settle);

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
    await tester.runAsync(settle);

    expect(bloc.state.placement.dim, 0.6);
  });

  testWidgets('a fit change or reset asks the preview to sync, a gesture does not', (tester) async {
    await start(tester);
    final int start0 = bloc.state.syncToken;

    bloc.add(const WallpaperPositionEvent.moved(dx: 1, dy: 1, zoom: 3));
    await tester.runAsync(settle);
    expect(bloc.state.syncToken, start0);

    bloc.add(const WallpaperPositionEvent.fitChanged(PlacementFit.fitColor));
    await tester.runAsync(settle);
    expect(bloc.state.syncToken, start0 + 1);

    bloc.add(const WallpaperPositionEvent.resetRequested());
    await tester.runAsync(settle);
    expect(bloc.state.syncToken, start0 + 2);
  });

  testWidgets('reset restores the placement but keeps the lock or home view', (tester) async {
    await start(tester);
    bloc.add(const WallpaperPositionEvent.previewModeChanged(PlacementPreviewMode.home));
    bloc.add(const WallpaperPositionEvent.dimChanged(0.4));
    bloc.add(const WallpaperPositionEvent.moved(dx: 1, dy: 1, zoom: 3));
    bloc.add(const WallpaperPositionEvent.resetRequested());
    await tester.runAsync(settle);

    expect(bloc.state.placement, const WallpaperPlacement(previewMode: PlacementPreviewMode.home));
  });

  group('apply', () {
    const ui.Size screen = ui.Size(1080, 2400);

    testWidgets('renders at the screen size, sets the PNG and keeps the original wall in history', (tester) async {
      await start(tester);
      bloc.add(const WallpaperPositionEvent.dimChanged(0.2));
      bloc.add(const WallpaperPositionEvent.applyRequested(target: WallpaperTarget.lock, outputSize: screen));
      await tester.runAsync(() async {
        await settle();
        await settle();
      });

      expect(repository.renders.single.$2, screen);
      expect(repository.renders.single.$1.dim, 0.2);
      expect(client.requests.single.target, aw.WallpaperTarget.lock);
      expect(client.requests.single.source.filePath, endsWith('placement_1.png'));
      expect(client.requests.single.scaleMode, aw.WallpaperScaleMode.centerCrop);
      expect(store.items().single.fullUrl, 'https://img.test/full.jpg');
      expect(store.items().single.thumbnailUrl, 'https://img.test/thumb.jpg');
      expect(store.items().single.target, 'lock');
      expect(bloc.state.status, WallpaperPositionStatus.ready);
      expect(bloc.state.result?.isSuccess, isTrue);
      expect(bloc.state.resultToken, 1);
      expect(repository.discarded, hasLength(1));
    });

    testWidgets('tracks wallpaper_placement_applied with the choices made', (tester) async {
      await start(tester);
      bloc.add(const WallpaperPositionEvent.fitChanged(PlacementFit.fitColor));
      bloc.add(const WallpaperPositionEvent.moved(dx: 0, dy: 0, zoom: 2));
      bloc.add(const WallpaperPositionEvent.dimChanged(0.4));
      bloc.add(const WallpaperPositionEvent.applyRequested(target: WallpaperTarget.both, outputSize: screen));
      await tester.runAsync(() async {
        await settle();
        await settle();
      });

      final WallpaperPlacementAppliedEvent event = analytics.events.whereType<WallpaperPlacementAppliedEvent>().single;
      expect(event.toWireParameters(), {
        'fit': 'fitColor',
        'zoomed': 1,
        'dim_bucket': 4,
        'wallpaper_target': 'both',
        'result': 'success',
      });
    });

    testWidgets('keeps the file while the system preview is open', (tester) async {
      client.status = aw.WallpaperOperationStatus.previewOpened;
      await start(tester);
      bloc.add(const WallpaperPositionEvent.applyRequested(target: WallpaperTarget.home, outputSize: screen));
      await tester.runAsync(() async {
        await settle();
        await settle();
      });

      expect(bloc.state.result?.isInfo, isTrue);
      expect(repository.discarded, isEmpty);
      expect(analytics.events.whereType<WallpaperPlacementAppliedEvent>(), isEmpty);
    });

    testWidgets('a failed set returns to ready with the failure and tracks it', (tester) async {
      client.status = aw.WallpaperOperationStatus.failed;
      await start(tester);
      bloc.add(const WallpaperPositionEvent.applyRequested(target: WallpaperTarget.home, outputSize: screen));
      await tester.runAsync(() async {
        await settle();
        await settle();
      });

      expect(bloc.state.status, WallpaperPositionStatus.ready);
      expect(bloc.state.result?.isFailure, isTrue);
      expect(analytics.events.whereType<WallpaperPlacementAppliedEvent>().single.result, BinaryResultValue.failure);
      expect(store.items(), isEmpty);
    });

    testWidgets('a render error is a retryable failure and sets nothing', (tester) async {
      repository.renderError = StateError('out of memory');
      await start(tester);
      bloc.add(const WallpaperPositionEvent.applyRequested(target: WallpaperTarget.home, outputSize: screen));
      await tester.runAsync(() async {
        await settle();
        await settle();
      });

      expect(client.requests, isEmpty);
      expect(bloc.state.result?.errorCode, 'render_failed');
      expect(bloc.state.result?.canRetry, isTrue);
      expect(bloc.state.status, WallpaperPositionStatus.ready);
    });

    testWidgets('a second tap while applying is ignored', (tester) async {
      repository.renderGate = Completer<void>();
      await start(tester);
      bloc.add(const WallpaperPositionEvent.applyRequested(target: WallpaperTarget.home, outputSize: screen));
      await tester.runAsync(settle);
      expect(bloc.state.status, WallpaperPositionStatus.applying);

      bloc.add(const WallpaperPositionEvent.applyRequested(target: WallpaperTarget.lock, outputSize: screen));
      repository.renderGate!.complete();
      await tester.runAsync(() async {
        await settle();
        await settle();
      });

      expect(repository.renders, hasLength(1));
      expect(client.requests.single.target, aw.WallpaperTarget.home);
    });

    testWidgets('apply before the wall has loaded does nothing', (tester) async {
      bloc.add(const WallpaperPositionEvent.applyRequested(target: WallpaperTarget.home, outputSize: screen));
      await tester.runAsync(settle);

      expect(repository.renders, isEmpty);
      expect(bloc.state.status, WallpaperPositionStatus.loading);
    });
  });
}
