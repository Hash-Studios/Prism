import 'package:Prism/core/di/injection.dart';
import 'package:Prism/core/persistence/data_sources/favorites_local_data_source.dart';
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
}
