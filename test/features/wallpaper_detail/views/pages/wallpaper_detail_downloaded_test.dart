import 'dart:async';
import 'dart:io';

import 'package:Prism/core/di/injection.dart';
import 'package:Prism/core/persistence/data_sources/favorites_local_data_source.dart';
import 'package:Prism/core/router/app_router.dart';
import 'package:Prism/core/wallpaper/wallpaper_core.dart';
import 'package:Prism/core/wallpaper/wallpaper_source.dart';
import 'package:Prism/core/wallpaper/wallpaper_variants.dart';
import 'package:Prism/core/widgets/menu_button/set_wallpaper_button.dart';
import 'package:Prism/features/category_feed/domain/entities/feed_item_entity.dart';
import 'package:Prism/features/wallpaper_detail/biz/bloc/wallpaper_detail_bloc.dart';
import 'package:Prism/features/wallpaper_detail/biz/bloc/wallpaper_detail_event.dart';
import 'package:Prism/features/wallpaper_detail/biz/bloc/wallpaper_detail_state.dart';
import 'package:Prism/features/wallpaper_detail/views/pages/wallpaper_detail_screen.dart';
import 'package:Prism/features/wallpaper_detail/views/widgets/clock_overlay.dart';
import 'package:auto_route/auto_route.dart';
import 'package:bloc_test/bloc_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import '../../../../support/in_memory_local_store.dart';

class _MockWallpaperDetailBloc extends MockBloc<WallpaperDetailEvent, WallpaperDetailState>
    implements WallpaperDetailBloc {}

class _MockStackRouter extends Mock implements StackRouter {}

FeedItemEntity _wallpaper() => const FeedItemEntity.pexels(
  id: 'pexels-1',
  wallpaper: PexelsWallpaper(
    core: WallpaperCore(
      id: 'pexels-1',
      source: WallpaperSource.pexels,
      fullUrl: 'https://images.example/full.jpg',
      thumbnailUrl: 'https://images.example/thumb.jpg',
    ),
  ),
);

void main() {
  setUpAll(
    () => registerFallbackValue(DownloadWallpaperRoute(source: WallpaperSource.downloaded, file: File('unused'))),
  );

  setUp(() {
    getIt.registerSingleton<FavoritesLocalDataSource>(FavoritesLocalDataSource(InMemoryLocalStore()));
  });

  tearDown(() => getIt.reset());

  Future<void> pumpFileError(WidgetTester tester) async {
    for (var i = 0; i < 20 && find.text('Downloaded wallpaper is unavailable').evaluate().isEmpty; i++) {
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 10)));
      await tester.pump();
    }
    await tester.pump(const Duration(milliseconds: 300));
  }

  testWidgets('local loading shows the file, back control, and passes its path to the bloc', (tester) async {
    final bloc = _MockWallpaperDetailBloc();
    whenListen(bloc, const Stream<WallpaperDetailState>.empty(), initialState: const WallpaperDetailLoading());
    final file = File('${Directory.systemTemp.path}/downloaded-wallpaper-missing.jpg');

    await tester.pumpWidget(
      MaterialApp(
        home: BlocProvider<WallpaperDetailBloc>.value(
          value: bloc,
          child: WallpaperDetailScreen(wallId: 'wall', source: WallpaperSource.pexels, localFile: file),
        ),
      ),
    );

    final image = tester.widget<Image>(find.byType(Image).first);
    expect(image.image, isA<FileImage>());
    expect(image.errorBuilder, isNotNull);
    expect(find.byTooltip('Back'), findsOneWidget);
    await pumpFileError(tester);
    expect(find.text('Downloaded wallpaper is unavailable'), findsOneWidget);
    expect(tester.takeException(), isNull);
    verify(
      () => bloc.add(LoadFromId(wallId: 'wall', source: WallpaperSource.pexels, localFilePath: file.path)),
    ).called(1);
  });

  testWidgets('downloaded detail uses the local file for set, clock, and color swatches', (tester) async {
    final bloc = _MockWallpaperDetailBloc();
    whenListen(
      bloc,
      const Stream<WallpaperDetailState>.empty(),
      initialState: WallpaperDetailLoaded(entity: _wallpaper(), paletteLoading: false, colors: const [Colors.teal]),
    );
    final file = File('assets/images/prism.webp');
    final router = _MockStackRouter();
    when(() => router.push(any())).thenAnswer((_) async => null);

    await tester.pumpWidget(
      MaterialApp(
        home: StackRouterScope(
          controller: router,
          stateHash: 0,
          child: BlocProvider<WallpaperDetailBloc>.value(
            value: bloc,
            child: WallpaperDetailScreen(wallId: 'pexels-1', source: WallpaperSource.pexels, localFile: file),
          ),
        ),
      ),
    );

    final localImages = tester
        .widgetList<Image>(find.byType(Image))
        .where((image) => image.image is FileImage)
        .toList();
    expect(localImages.length, greaterThan(1));
    expect(localImages.every((image) => (image.image as FileImage).file.path == file.path), isTrue);
    expect(tester.widget<SetWallpaperButton>(find.byType(SetWallpaperButton)).url, file.path);
    await tester.tap(find.byTooltip('Clock preview'));
    await tester.pumpAndSettle();
    final clock = tester.widget<ClockOverlay>(find.byType(ClockOverlay));
    expect(clock.link, file.path);
    expect(clock.file, isTrue);
  });

  testWidgets('a deleted image in loaded detail shows an error without an image-stream exception', (tester) async {
    final bloc = _MockWallpaperDetailBloc();
    whenListen(
      bloc,
      const Stream<WallpaperDetailState>.empty(),
      initialState: WallpaperDetailLoaded(entity: _wallpaper(), paletteLoading: false, colors: const [Colors.teal]),
    );
    final file = File('${Directory.systemTemp.path}/deleted-loaded-wallpaper.jpg');

    await tester.pumpWidget(
      MaterialApp(
        home: BlocProvider<WallpaperDetailBloc>.value(
          value: bloc,
          child: WallpaperDetailScreen(wallId: 'pexels-1', source: WallpaperSource.pexels, localFile: file),
        ),
      ),
    );
    await pumpFileError(tester);

    expect(find.text('Downloaded wallpaper is unavailable'), findsWidgets);
    expect(tester.takeException(), isNull);
  });

  testWidgets('a deleted local file keeps metadata failures on detail instead of opening a broken bare screen', (
    tester,
  ) async {
    final bloc = _MockWallpaperDetailBloc();
    whenListen(
      bloc,
      Stream<WallpaperDetailState>.value(const WallpaperDetailError(message: 'offline')),
      initialState: const WallpaperDetailLoading(),
    );
    final router = _MockStackRouter();
    final file = File('${Directory.systemTemp.path}/already-deleted-wallpaper.jpg');

    await tester.pumpWidget(
      MaterialApp(
        home: StackRouterScope(
          controller: router,
          stateHash: 0,
          child: BlocProvider<WallpaperDetailBloc>.value(
            value: bloc,
            child: WallpaperDetailScreen(wallId: 'wall', source: WallpaperSource.pexels, localFile: file),
          ),
        ),
      ),
    );
    await tester.pump();

    verifyNever(() => router.replace(any()));
    expect(find.text('offline'), findsOneWidget);
    expect(find.text('Try again'), findsOneWidget);
  });

  testWidgets('a valid downloaded file still falls back after metadata fails', (tester) async {
    final bloc = _MockWallpaperDetailBloc();
    whenListen(
      bloc,
      Stream<WallpaperDetailState>.value(const WallpaperDetailError(message: 'offline')),
      initialState: const WallpaperDetailLoading(),
    );
    final router = _MockStackRouter();
    when(() => router.replace(any())).thenAnswer((_) async => null);
    final file = File('assets/images/prism.webp');

    await tester.pumpWidget(
      MaterialApp(
        home: StackRouterScope(
          controller: router,
          stateHash: 0,
          child: BlocProvider<WallpaperDetailBloc>.value(
            value: bloc,
            child: WallpaperDetailScreen(wallId: 'wall', source: WallpaperSource.pexels, localFile: file),
          ),
        ),
      ),
    );
    await tester.pump();

    verify(() => router.replace(DownloadWallpaperRoute(source: WallpaperSource.downloaded, file: file))).called(1);
  });

  testWidgets('a delayed failure from a covered detail route does not replace the active route', (tester) async {
    final bloc = _MockWallpaperDetailBloc();
    final states = StreamController<WallpaperDetailState>.broadcast();
    whenListen(bloc, states.stream, initialState: const WallpaperDetailLoading());
    final router = _MockStackRouter();
    when(() => router.replace(any())).thenAnswer((_) async => null);
    final navigatorKey = GlobalKey<NavigatorState>();
    final file = File('assets/images/prism.webp');

    await tester.pumpWidget(
      MaterialApp(
        navigatorKey: navigatorKey,
        home: StackRouterScope(
          controller: router,
          stateHash: 0,
          child: BlocProvider<WallpaperDetailBloc>.value(
            value: bloc,
            child: WallpaperDetailScreen(wallId: 'a', source: WallpaperSource.pexels, localFile: file),
          ),
        ),
      ),
    );
    navigatorKey.currentState!.push<void>(MaterialPageRoute<void>(builder: (_) => const Scaffold(body: Text('B'))));
    await tester.pumpAndSettle();
    states.add(const WallpaperDetailError(message: 'offline'));
    await tester.pump();

    expect(find.text('B'), findsOneWidget);
    verifyNever(() => router.replace(any()));
    await states.close();
  });

  testWidgets('an error in one detail route does not replace another route', (tester) async {
    final firstBloc = _MockWallpaperDetailBloc();
    final secondBloc = _MockWallpaperDetailBloc();
    whenListen(firstBloc, const Stream<WallpaperDetailState>.empty(), initialState: const WallpaperDetailLoading());
    whenListen(
      secondBloc,
      Stream<WallpaperDetailState>.value(const WallpaperDetailError(message: 'offline')),
      initialState: const WallpaperDetailLoading(),
    );
    final blocs = <WallpaperDetailBloc>[firstBloc, secondBloc];
    getIt.registerFactory<WallpaperDetailBloc>(() => blocs.removeAt(0));
    final router = _MockStackRouter();
    when(() => router.replace(any())).thenAnswer((_) async => null);
    final file = File('assets/images/prism.webp');

    await tester.pumpWidget(
      MaterialApp(
        home: StackRouterScope(
          controller: router,
          stateHash: 0,
          child: Stack(
            children: [
              WrappedRoute<WallpaperDetailScreen>(
                child: WallpaperDetailScreen(wallId: 'first', source: WallpaperSource.pexels, localFile: file),
              ),
              WrappedRoute<WallpaperDetailScreen>(
                child: WallpaperDetailScreen(wallId: 'second', source: WallpaperSource.pexels, localFile: file),
              ),
            ],
          ),
        ),
      ),
    );

    await tester.pump();
    verify(() => router.replace(DownloadWallpaperRoute(source: WallpaperSource.downloaded, file: file))).called(1);
    verify(
      () => firstBloc.add(LoadFromId(wallId: 'first', source: WallpaperSource.pexels, localFilePath: file.path)),
    ).called(1);
    verify(
      () => secondBloc.add(LoadFromId(wallId: 'second', source: WallpaperSource.pexels, localFilePath: file.path)),
    ).called(1);
  });
}
