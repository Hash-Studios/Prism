import 'dart:async';

import 'package:Prism/core/di/injection.dart';
import 'package:Prism/core/persistence/data_sources/favorites_local_data_source.dart';
import 'package:Prism/core/persistence/data_sources/settings_local_data_source.dart';
import 'package:Prism/core/personalization/taste_signals.dart';
import 'package:Prism/core/wallpaper/wallpaper_core.dart';
import 'package:Prism/core/wallpaper/wallpaper_source.dart';
import 'package:Prism/core/wallpaper/wallpaper_variants.dart';
import 'package:Prism/features/category_feed/domain/entities/feed_item_entity.dart';
import 'package:Prism/features/wallpaper_detail/biz/bloc/wallpaper_detail_bloc.dart';
import 'package:Prism/features/wallpaper_detail/biz/bloc/wallpaper_detail_event.dart';
import 'package:Prism/features/wallpaper_detail/biz/bloc/wallpaper_detail_state.dart';
import 'package:Prism/features/wallpaper_detail/views/pages/wallpaper_detail_screen.dart';
import 'package:bloc_test/bloc_test.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../../support/in_memory_local_store.dart';

class _MockDetailBloc extends MockBloc<WallpaperDetailEvent, WallpaperDetailState> implements WallpaperDetailBloc {}

FeedItemEntity _item(String id) => FeedItemEntity.prism(
  id: id,
  wallpaper: PrismWallpaper(
    core: WallpaperCore(
      id: id,
      source: WallpaperSource.prism,
      fullUrl: 'https://example.com/$id.jpg',
      thumbnailUrl: 'https://example.com/$id-thumb.jpg',
    ),
  ),
);

void main() {
  setUp(() {
    getIt.registerSingleton<FavoritesLocalDataSource>(FavoritesLocalDataSource(InMemoryLocalStore()));
    getIt.registerSingleton<TasteSignalStore>(TasteSignalStore(SettingsLocalDataSource(InMemoryLocalStore())));
    getIt.registerFactory<WallpaperDetailBloc>(() {
      final bloc = _MockDetailBloc();
      whenListen(bloc, const Stream<WallpaperDetailState>.empty(), initialState: const WallpaperDetailInitial());
      return bloc;
    });
  });

  tearDown(getIt.reset);

  testWidgets('a new detail route shows its own wallpaper on the first frame, not the last one opened', (tester) async {
    final staleBloc = _MockDetailBloc();
    whenListen(
      staleBloc,
      const Stream<WallpaperDetailState>.empty(),
      initialState: WallpaperDetailLoaded(entity: _item('previous')),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: BlocProvider<WallpaperDetailBloc>.value(
          value: staleBloc,
          child: Builder(
            builder: (context) => WallpaperDetailScreen(entity: _item('tapped'), heroTag: 'tile').wrappedRoute(context),
          ),
        ),
      ),
    );

    final urls = tester.widgetList<CachedNetworkImage>(find.byType(CachedNetworkImage)).map((i) => i.imageUrl);
    expect(urls, contains('https://example.com/tapped-thumb.jpg'));
    expect(urls.where((u) => u.contains('previous')), isEmpty);
    expect(find.byType(Hero), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('a covered detail route cannot replace the top route status bar style', (tester) async {
    final firstBloc = _MockDetailBloc();
    final firstStates = StreamController<WallpaperDetailState>();
    whenListen(firstBloc, firstStates.stream, initialState: WallpaperDetailLoaded(entity: _item('first')));
    final secondBloc = _MockDetailBloc();
    final secondStates = StreamController<WallpaperDetailState>();
    whenListen(secondBloc, secondStates.stream, initialState: WallpaperDetailLoaded(entity: _item('second')));
    addTearDown(firstStates.close);
    addTearDown(secondStates.close);

    final navigatorKey = GlobalKey<NavigatorState>();
    await tester.pumpWidget(
      MaterialApp(
        navigatorKey: navigatorKey,
        home: BlocProvider<WallpaperDetailBloc>.value(
          value: firstBloc,
          child: WallpaperDetailScreen(entity: _item('first')),
        ),
      ),
    );
    navigatorKey.currentState!.push<void>(
      MaterialPageRoute<void>(
        builder: (_) => BlocProvider<WallpaperDetailBloc>.value(
          value: secondBloc,
          child: WallpaperDetailScreen(entity: _item('second')),
        ),
      ),
    );
    await tester.pumpAndSettle();

    secondStates.add(
      WallpaperDetailLoaded(
        entity: _item('second'),
        paletteLoading: false,
        colors: const [Colors.white],
        accent: Colors.white,
      ),
    );
    await tester.pump();
    await tester.pump();
    List<Brightness?> detailStyles() => tester
        .widgetList<AnnotatedRegion<SystemUiOverlayStyle>>(find.byType(AnnotatedRegion<SystemUiOverlayStyle>))
        .map((region) => region.value.statusBarIconBrightness)
        .toList();
    expect(detailStyles(), [Brightness.dark]);

    firstStates.add(
      WallpaperDetailLoaded(
        entity: _item('first'),
        paletteLoading: false,
        colors: const [Colors.black],
        accent: Colors.black,
      ),
    );
    await tester.pump();
    await tester.pump();
    expect(detailStyles(), [Brightness.dark]);

    navigatorKey.currentState!.pop();
    await tester.pumpAndSettle();
    expect(detailStyles(), [Brightness.light]);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('uses the dark loading surface to choose status bar icon brightness', (tester) async {
    final bloc = _MockDetailBloc();
    whenListen(
      bloc,
      const Stream<WallpaperDetailState>.empty(),
      initialState: WallpaperDetailLoaded(entity: _item('dark-loading')),
    );

    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData.dark().copyWith(primaryColor: Colors.black),
        home: BlocProvider<WallpaperDetailBloc>.value(
          value: bloc,
          child: WallpaperDetailScreen(entity: _item('dark-loading')),
        ),
      ),
    );

    final style = tester.widget<AnnotatedRegion<SystemUiOverlayStyle>>(
      find.byType(AnnotatedRegion<SystemUiOverlayStyle>),
    );
    expect(style.value.statusBarIconBrightness, Brightness.light);
    await tester.pumpWidget(const SizedBox());
  });
}
