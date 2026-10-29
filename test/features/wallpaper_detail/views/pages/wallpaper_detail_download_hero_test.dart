import 'dart:async';
import 'dart:io';

import 'package:Prism/core/di/injection.dart';
import 'package:Prism/core/persistence/data_sources/settings_local_data_source.dart';
import 'package:Prism/core/personalization/taste_signals.dart';
import 'package:Prism/core/router/app_router.dart';
import 'package:Prism/core/router/wallpaper_detail_route.dart';
import 'package:Prism/core/wallpaper/wallpaper_core.dart';
import 'package:Prism/core/wallpaper/wallpaper_source.dart';
import 'package:Prism/core/wallpaper/wallpaper_variants.dart';
import 'package:Prism/core/widgets/progressive_wallpaper_image.dart';
import 'package:Prism/features/category_feed/domain/entities/feed_item_entity.dart';
import 'package:Prism/features/wallpaper_detail/biz/bloc/wallpaper_detail_bloc.dart';
import 'package:Prism/features/wallpaper_detail/biz/bloc/wallpaper_detail_event.dart';
import 'package:Prism/features/wallpaper_detail/biz/bloc/wallpaper_detail_state.dart';
import 'package:Prism/features/wallpaper_detail/views/pages/wallpaper_detail_screen.dart';
import 'package:Prism/l10n/l10n.dart';
import 'package:auto_route/auto_route.dart';
import 'package:bloc_test/bloc_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../../support/favourite_test_scope.dart';
import '../../../../support/in_memory_local_store.dart';
import '../../../../support/wait_for_real_io.dart';
import '../../../../support/wallpaper_image_finders.dart';

class _MockDetailBloc extends MockBloc<WallpaperDetailEvent, WallpaperDetailState> implements WallpaperDetailBloc {}

class _DownloadRouter extends RootStackRouter {
  _DownloadRouter(this.file);

  final File file;

  @override
  List<AutoRoute> get routes => [
    AutoRoute(
      path: '/',
      page: PageInfo(
        'Downloads',
        builder: (_) => Scaffold(
          body: Stack(
            children: [
              Positioned(
                left: 40,
                top: 120,
                width: 100,
                height: 100 / 1.5,
                child: Hero(
                  tag: 'download',
                  createRectTween: wallpaperHeroRectTween,
                  child: Image.file(file, fit: BoxFit.cover),
                ),
              ),
            ],
          ),
        ),
      ),
    ),
    CustomRoute(path: '/detail', page: WallpaperDetailRoute.page, customRouteBuilder: wallpaperDetailRouteBuilder),
  ];
}

void main() {
  setUpFavouriteCounts();

  testWidgets('a download Hero keeps its routed aspect hint through loading, metadata arrival, and landing', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(400, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final file = File('assets/images/prism.webp').absolute;
    final states = StreamController<WallpaperDetailState>();
    final bloc = _MockDetailBloc();
    whenListen(bloc, states.stream, initialState: const WallpaperDetailLoading());
    getIt.registerFactory<WallpaperDetailBloc>(() => bloc);
    getIt.registerSingleton<TasteSignalStore>(TasteSignalStore(SettingsLocalDataSource(InMemoryLocalStore())));
    final router = _DownloadRouter(file);
    addTearDown(() async {
      await tester.pumpWidget(const SizedBox());
      router.dispose();
      await states.close();
      await getIt.reset();
    });
    await tester.pumpWidget(
      MaterialApp.router(
        routerConfig: router.config(),
        builder: favouriteTestBuilder,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
      ),
    );
    await tester.pumpAndSettle();
    await waitForRealIo(
      tester,
      () => tester.widget<RawImage>(find.byType(RawImage)).image != null,
      reason: 'the download tile to decode its local file',
    );
    final source = tester.getRect(find.byType(Hero));
    unawaited(
      router.push<void>(
        WallpaperDetailRoute(
          wallId: 'downloaded-wall',
          source: WallpaperSource.pexels,
          localFile: file,
          heroTag: 'download',
          aspectRatio: 1.5,
        ),
      ),
    );
    await tester.pump();
    await tester.pump();
    final destination = find.descendant(
      of: find.byType(WallpaperDetailScreen, skipOffstage: false),
      matching: find.byType(Hero, skipOffstage: false),
    );
    final route = ModalRoute.of(tester.element(destination))!;
    Rect targetRect() {
      final box = tester.renderObject<RenderBox>(destination);
      return MatrixUtils.transformRect(
        box.getTransformTo(route.subtreeContext!.findRenderObject()),
        Offset.zero & box.size,
      );
    }

    final target = targetRect();
    expect(target.width, closeTo(392, 0.01));
    expect(target.width / target.height, closeTo(1.5, 0.001));
    expect(route.transitionDuration, const Duration(milliseconds: 160));
    final flying = find.byElementPredicate(
      (element) =>
          element.widget is ProgressiveWallpaperImage &&
          element.findAncestorWidgetOfExactType<WallpaperDetailScreen>() == null &&
          element.findAncestorWidgetOfExactType<Hero>() == null,
    );
    void expectFlight() {
      expect(flying, findsOneWidget);
      final expected = Rect.lerp(source, target, const Cubic(0.45, 0.3, 0.1, 1).transform(route.animation!.value))!;
      final actual = tester.getRect(flying);
      expect(actual.left, closeTo(expected.left, 0.1));
      expect(actual.top, closeTo(expected.top, 0.1));
      expect(actual.width, closeTo(expected.width, 0.1));
      expect(actual.height, closeTo(expected.height, 0.1));
      final image = tester.widget<Image>(find.descendant(of: flying, matching: find.byType(Image)).first);
      expect(unwrapImageProvider(image.image), isA<FileImage>().having((image) => image.file.path, 'path', file.path));
    }

    await tester.pump(const Duration(milliseconds: 40));
    expect(bloc.state, isA<WallpaperDetailLoading>());
    expectFlight();
    states.add(
      const WallpaperDetailLoaded(
        entity: FeedItemEntity.pexels(
          id: 'downloaded-wall',
          wallpaper: PexelsWallpaper(
            core: WallpaperCore(
              id: 'downloaded-wall',
              source: WallpaperSource.pexels,
              fullUrl: '',
              thumbnailUrl: '',
              width: 1600,
              height: 900,
            ),
          ),
        ),
        paletteLoading: false,
      ),
    );
    await tester.pump();
    await tester.pump();
    expect(targetRect(), target, reason: 'Catalogue dimensions must not replace the decoded download shape.');
    expectFlight();
    await tester.pump(const Duration(milliseconds: 40));
    expectFlight();
    await tester.pump(const Duration(milliseconds: 100));
    expect(flying, findsNothing);
    expect(tester.getRect(destination), target);
    expect(tester.takeException(), isNull);
  });
}
