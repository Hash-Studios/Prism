import 'dart:io';
import 'dart:ui' as ui;

import 'package:Prism/core/analytics/analytics_runtime.dart';
import 'package:Prism/core/di/injection.dart';
import 'package:Prism/core/platform/wallpaper_service.dart';
import 'package:Prism/features/wallpaper_detail/views/widgets/preview_layers.dart';
import 'package:Prism/features/wallpaper_position/biz/bloc/wallpaper_position_bloc.j.dart';
import 'package:Prism/features/wallpaper_position/domain/entities/wallpaper_placement.dart';
import 'package:Prism/features/wallpaper_position/domain/repositories/wallpaper_position_repository.dart';
import 'package:Prism/features/wallpaper_position/views/pages/wallpaper_position_screen.dart';
import 'package:Prism/features/wallpaper_position/views/widgets/placement_preview.dart';
import 'package:async_wallpaper/async_wallpaper.dart' as aw;
// ignore: implementation_imports
import 'package:async_wallpaper/src/wallpaper_client.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../support/fake_app_analytics.dart';

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
    return File('${directory.path}/placement.png')..writeAsBytesSync(<int>[1]);
  }

  @override
  Future<void> discard(File file) async {}
}

class _Client implements WallpaperClient {
  _Client({this.capabilities = const aw.WallpaperCapabilities()});

  final aw.WallpaperCapabilities capabilities;
  aw.WallpaperOperationStatus status = aw.WallpaperOperationStatus.applied;
  final List<aw.StaticWallpaperRequest> requests = <aw.StaticWallpaperRequest>[];

  @override
  Future<aw.WallpaperCapabilities> getCapabilities() async => capabilities;

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

  Future<void> pumpScreen(WidgetTester tester, {void Function(Object? result)? onResult}) async {
    repository.image = await tester.runAsync(() {
      final ui.PictureRecorder recorder = ui.PictureRecorder();
      Canvas(recorder).drawRect(const Rect.fromLTWH(0, 0, 40, 80), Paint()..color = const Color(0xFF336699));
      return recorder.endRecording().toImage(40, 80);
    });
    await tester.pumpWidget(
      MaterialApp(
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

  testWidgets('shows the wall in a frame with fit choices, dim, reset and the three set buttons', (tester) async {
    await pumpScreen(tester);

    expect(find.byType(PlacementPreview), findsOneWidget);
    expect(find.byType(InteractiveViewer), findsOneWidget);
    expect(find.text('Fill'), findsOneWidget);
    expect(find.text('Fit with blur'), findsOneWidget);
    expect(find.text('Fit with colour'), findsOneWidget);
    expect(find.text('Dim'), findsOneWidget);
    expect(find.byType(Slider), findsOneWidget);
    expect(find.text('Reset'), findsOneWidget);
    expect(find.text('Home screen'), findsOneWidget);
    expect(find.text('Lock screen'), findsOneWidget);
    expect(find.text('Both'), findsOneWidget);
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

  testWidgets('Home screen renders the placement, sets it and closes the studio with the result', (tester) async {
    Object? result;
    await pumpScreen(tester, onResult: (value) => result = value);

    await tester.tap(find.text('Home screen'));
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 100)));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600));

    expect(repository.renders, hasLength(1));
    expect(client.requests.single.target, aw.WallpaperTarget.home);
    expect(find.byType(WallpaperPositionScreen), findsNothing);
    expect(result, isA<WallpaperSetResult>().having((r) => r.isSuccess, 'isSuccess', isTrue));
    await tester.pump(const Duration(seconds: 10));
  });

  testWidgets('a failed set keeps the studio open and offers Try again', (tester) async {
    client.status = aw.WallpaperOperationStatus.failed;
    await pumpScreen(tester);

    await tester.tap(find.text('Lock screen'));
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 100)));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600));

    expect(find.byType(WallpaperPositionScreen), findsOneWidget);
    expect(find.text('Try again'), findsOneWidget);
    await tester.pump(const Duration(seconds: 10));
  });

  testWidgets('only the screens the device supports get a button', (tester) async {
    aw.AsyncWallpaper.debugSetClient(
      _Client(capabilities: const aw.WallpaperCapabilities(supportsStaticWallpaper: true, supportsHomeWallpaper: true)),
    );
    await pumpScreen(tester);

    expect(find.text('Home screen'), findsOneWidget);
    expect(find.text('Lock screen'), findsNothing);
    expect(find.text('Both'), findsNothing);
  });

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
