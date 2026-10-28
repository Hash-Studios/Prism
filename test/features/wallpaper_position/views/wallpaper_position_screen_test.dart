import 'dart:io';
import 'dart:ui' as ui;

import 'package:Prism/core/analytics/analytics_runtime.dart';
import 'package:Prism/core/di/injection.dart';
import 'package:Prism/core/widgets/menu_button/set_wallpaper_choice.dart';
import 'package:Prism/features/wallpaper_detail/views/widgets/preview_layers.dart';
import 'package:Prism/features/wallpaper_position/biz/bloc/wallpaper_position_bloc.j.dart';
import 'package:Prism/features/wallpaper_position/domain/entities/wallpaper_placement.dart';
import 'package:Prism/features/wallpaper_position/domain/repositories/wallpaper_position_repository.dart';
import 'package:Prism/features/wallpaper_position/views/pages/wallpaper_position_screen.dart';
import 'package:Prism/features/wallpaper_position/views/widgets/placement_preview.dart';
import 'package:Prism/l10n/l10n.dart';
import 'package:async_wallpaper/async_wallpaper.dart' as aw;
import 'package:async_wallpaper/src/wallpaper_client.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/intl.dart';

import '../../../support/fake_app_analytics.dart';
import '../../../support/wait_for_real_io.dart';

class _Repository implements WallpaperPositionRepository {
  _Repository(this.directory);

  final Directory directory;
  ui.Image? image;
  bool failLoad = false;
  int loads = 0;
  final List<WallpaperPlacement> renders = <WallpaperPlacement>[];

  @override
  Future<PlacementSource> load(String url) async {
    loads++;
    if (failLoad) throw StateError('offline');
    return PlacementSource(image: image!, dominantColor: const Color(0xFF204060));
  }

  @override
  Future<File> render(PlacementSource source, WallpaperPlacement placement, ui.Size outputSize) async {
    renders.add(placement);
    final ByteData data = (await source.image.toByteData(format: ui.ImageByteFormat.png))!;
    return File('${directory.path}/placement.png')..writeAsBytesSync(data.buffer.asUint8List());
  }
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
  late _Repository repository;
  late _Client client;

  setUp(() {
    directory = Directory.systemTemp.createTempSync('position_screen_test_');
    repository = _Repository(directory);
    client = _Client();
    aw.AsyncWallpaper.debugSetClient(client);
    AnalyticsRuntime.instance = FakeAppAnalytics();
    getIt.registerFactory<WallpaperPositionBloc>(() => WallpaperPositionBloc(repository));
    const MethodChannel toast = MethodChannel('PonnamKarthik/fluttertoast');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
      toast,
      (_) async => true,
    );
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (_) async => null,
    );
  });

  tearDown(() async {
    final messenger = TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(const MethodChannel('PonnamKarthik/fluttertoast'), null);
    messenger.setMockMethodCallHandler(SystemChannels.platform, null);
    await getIt.reset();
    AnalyticsRuntime.reset();
    aw.AsyncWallpaper.debugResetClient();
    directory.deleteSync(recursive: true);
  });

  Future<void> pumpScreen(
    WidgetTester tester, {
    void Function(Object? result)? onResult,
    EdgeInsets deviceInsets = EdgeInsets.zero,
  }) async {
    repository.image = await tester.runAsync(() {
      final ui.PictureRecorder recorder = ui.PictureRecorder();
      Canvas(recorder).drawRect(const Rect.fromLTWH(0, 0, 40, 80), Paint()..color = const Color(0xFF336699));
      return recorder.endRecording().toImage(40, 80);
    });
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,

        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(padding: deviceInsets, viewPadding: deviceInsets),
          child: child!,
        ),
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () async {
                final Object? result = await Navigator.of(context).push<Object?>(
                  MaterialPageRoute<Object?>(
                    builder: (_) => const WallpaperPositionScreen(
                      imageUrl: 'https://img.test/full.jpg',
                      thumbnailUrl: 'https://img.test/thumb.jpg',
                      entryPoint: 'wallpaper_detail',
                    ),
                  ),
                );
                onResult?.call(result);
              },
              child: const Text('open'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pump();
  }

  testWidgets('shows the wall in a frame with fit choices, dim, reset and Done', (tester) async {
    await pumpScreen(tester);

    expect(find.byType(PlacementPreview), findsOneWidget);
    expect(find.byType(InteractiveViewer), findsOneWidget);
    expect(find.text('Fill'), findsOneWidget);
    expect(find.text('Fit with blur'), findsOneWidget);
    expect(find.text('Fit with colour'), findsOneWidget);
    expect(find.text('Dim'), findsOneWidget);
    expect(find.byType(Slider), findsOneWidget);
    expect(find.text('Reset'), findsOneWidget);
    expect(find.text('Done'), findsOneWidget);
    expect(find.text('Approximate. Your launcher may differ.'), findsOneWidget);
  });

  testWidgets('the zoom range is 1 to 4 times', (tester) async {
    await pumpScreen(tester);

    final InteractiveViewer viewer = tester.widget<InteractiveViewer>(find.byType(InteractiveViewer));
    expect(viewer.minScale, 1);
    expect(viewer.maxScale, 4);
  });

  testWidgets('the Lock and Home toggle swaps the preview layer', (tester) async {
    await pumpScreen(tester);
    expect(find.byType(LockPreviewLayer), findsOneWidget);
    expect(find.byType(HomePreviewLayer), findsNothing);

    await tester.tap(find.text('Home'));
    await tester.pump();

    expect(find.byType(HomePreviewLayer), findsOneWidget);
    expect(find.byType(LockPreviewLayer), findsNothing);
  });

  group('device insets in the frame', () {
    testWidgets('the iOS lock date clears the status bar although the app bar covers it', (tester) async {
      await pumpScreen(tester, deviceInsets: const EdgeInsets.only(top: 47));

      final Rect layer = tester.getRect(find.byType(LockPreviewLayer));
      final double scale = layer.width / 800;
      final String locale = AppLocalizations.of(tester.element(find.byType(PlacementPreview))).localeName;
      final String dateLabel = DateFormat.MMMMEEEEd(locale).format(DateTime.now());
      final double dateTop = tester.getTopLeft(find.text(dateLabel)).dy;
      expect(dateTop - layer.top, closeTo((47 + 24) * scale, 0.01));
    }, variant: TargetPlatformVariant.only(TargetPlatform.iOS));

    testWidgets('the Android dock clears the navigation bar', (tester) async {
      await pumpScreen(tester, deviceInsets: const EdgeInsets.only(bottom: 34));
      await tester.tap(find.text('Home'));
      await tester.pump();

      final Rect layer = tester.getRect(find.byType(HomePreviewLayer));
      final double scale = layer.width / 800;
      expect(layer.bottom - tester.getBottomLeft(find.byKey(previewDockKey)).dy, closeTo(174 * scale, 0.01));
    }, variant: TargetPlatformVariant.only(TargetPlatform.android));
  });

  testWidgets('a fit chip changes the placement and Reset puts it back', (tester) async {
    await pumpScreen(tester);
    final WallpaperPositionBloc bloc = BlocProvider.of<WallpaperPositionBloc>(
      tester.element(find.byType(PlacementPreview)),
    );

    await tester.tap(find.text('Fit with blur'));
    await tester.pump();
    expect(bloc.state.placement.fit, PlacementFit.fitBlur);
    expect(tester.widget<ChoiceChip>(find.widgetWithText(ChoiceChip, 'Fit with blur')).selected, isTrue);

    await tester.tap(find.text('Reset'));
    await tester.pump();
    expect(bloc.state.placement.fit, PlacementFit.fill);
  });

  testWidgets('the dim slider moves the dim and shows its percentage', (tester) async {
    await pumpScreen(tester);
    final WallpaperPositionBloc bloc = BlocProvider.of<WallpaperPositionBloc>(
      tester.element(find.byType(PlacementPreview)),
    );

    await tester.drag(find.byType(Slider), const Offset(5000, 0));
    await tester.pump();

    expect(bloc.state.placement.dim, 0.6);
    expect(find.text('60%'), findsOneWidget);
  });

  testWidgets('the wall starts centred, the same way it will be rendered', (tester) async {
    await pumpScreen(tester);

    final TransformationController controller = tester
        .widget<InteractiveViewer>(find.byType(InteractiveViewer))
        .transformationController!;
    final Size frame = tester.getSize(find.byType(InteractiveViewer));
    final Size image = Size(repository.image!.width.toDouble(), repository.image!.height.toDouble());
    expect(controller.value, placementMatrix(const WallpaperPlacement(), image, frame));
    expect(controller.value.storage[13], lessThan(0));
  });

  testWidgets('a pan gesture reaches the bloc as a new focus point', (tester) async {
    await pumpScreen(tester);
    final WallpaperPositionBloc bloc = BlocProvider.of<WallpaperPositionBloc>(
      tester.element(find.byType(PlacementPreview)),
    );
    expect(bloc.state.placement.dy, 0);

    final TestGesture gesture = await tester.startGesture(tester.getCenter(find.byType(InteractiveViewer)));
    await gesture.moveBy(const Offset(0, -30));
    await gesture.moveBy(const Offset(0, -30));
    await gesture.up();
    await tester.pump();

    expect(bloc.state.placement.dy, greaterThan(0));
    expect(bloc.state.placement.zoom, 1);
  });

  testWidgets('changing the fit moves the preview to the placement again', (tester) async {
    await pumpScreen(tester);
    final TransformationController controller = tester
        .widget<InteractiveViewer>(find.byType(InteractiveViewer))
        .transformationController!;
    final TestGesture gesture = await tester.startGesture(tester.getCenter(find.byType(InteractiveViewer)));
    await gesture.moveBy(const Offset(0, -60));
    await gesture.up();
    await tester.pump();

    await tester.tap(find.text('Fit with colour'));
    await tester.pump();
    await tester.pump();

    expect(controller.value.storage[12], 0);
    expect(controller.value.storage[13], 0);
  });

  testWidgets('Done renders the wall and pops with it as the placed wall', (tester) async {
    Object? result;
    await pumpScreen(tester, onResult: (value) => result = value);

    await tester.tap(find.text('Done'));
    await waitForRealIo(tester, () => result != null, reason: 'placed wall result');
    await tester.pump(const Duration(milliseconds: 600));

    expect(repository.renders, hasLength(1));
    expect(client.requests, isEmpty);
    expect(find.byType(WallpaperPositionScreen), findsNothing);
    expect(result, isA<PlacedWallpaper>());
    expect((result! as PlacedWallpaper).path, endsWith('placement.png'));
    expect((result! as PlacedWallpaper).placement, const WallpaperPlacement());
    await tester.pump(const Duration(seconds: 1));
  });

  testWidgets('on Android Open system editor pops with a request for the system editor', (tester) async {
    Object? result;
    await pumpScreen(tester, onResult: (value) => result = value);

    await tester.tap(find.text('Open system editor'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600));

    expect(result, isA<SystemEditorRequested>());
    expect(find.byType(WallpaperPositionScreen), findsNothing);
    expect(repository.renders, isEmpty);
  }, variant: TargetPlatformVariant.only(TargetPlatform.android));

  testWidgets('on iOS there is no Open system editor button', (tester) async {
    await pumpScreen(tester);

    expect(find.text('Open system editor'), findsNothing);
    expect(find.text('Done'), findsOneWidget);
  }, variant: TargetPlatformVariant.only(TargetPlatform.iOS));

  testWidgets('a wall that cannot load shows a plain message and Try again loads it again', (tester) async {
    repository.failLoad = true;
    await pumpScreen(tester);

    expect(find.text("Couldn't load this wallpaper"), findsOneWidget);
    expect(find.byType(PlacementPreview), findsNothing);
    repository.failLoad = false;
    await tester.tap(find.text('Try again'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(repository.loads, 2);
    expect(find.byType(PlacementPreview), findsOneWidget);
  });
}
