import 'package:Prism/core/di/injection.dart';
import 'package:Prism/core/persistence/data_sources/favorites_local_data_source.dart';
import 'package:Prism/core/state/app_state.dart' as app_state;
import 'package:Prism/core/wallpaper/wallpaper_core.dart';
import 'package:Prism/core/wallpaper/wallpaper_source.dart';
import 'package:Prism/core/wallpaper/wallpaper_variants.dart';
import 'package:Prism/features/category_feed/domain/entities/feed_item_entity.dart';
import 'package:Prism/features/wallpaper_detail/biz/bloc/wallpaper_detail_bloc.dart';
import 'package:Prism/features/wallpaper_detail/biz/bloc/wallpaper_detail_event.dart';
import 'package:Prism/features/wallpaper_detail/biz/bloc/wallpaper_detail_state.dart';
import 'package:Prism/features/wallpaper_detail/domain/entities/recommendation_state.dart';
import 'package:Prism/features/wallpaper_detail/views/pages/wallpaper_detail_screen.dart';
import 'package:Prism/l10n/l10n.dart';
import 'package:bloc_test/bloc_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import '../../../../support/favourite_test_scope.dart';
import '../../../../support/in_memory_local_store.dart';
import '../../../../support/offline_asset_fixture.dart';
import '../../../../support/profile_user_fixture.dart';

class _MockWallpaperDetailBloc extends MockBloc<WallpaperDetailEvent, WallpaperDetailState>
    implements WallpaperDetailBloc {}

PrismWallpaper _wall({DateTime? editorsChoiceAt}) => PrismWallpaper(
  core: const WallpaperCore(
    id: 'prism-1',
    source: WallpaperSource.prism,
    fullUrl: 'https://img.test/full.jpg',
    thumbnailUrl: 'https://img.test/thumb.jpg',
    authorName: 'Akshay',
    authorUid: 'creator-uid',
  ),
  firestoreDocumentId: 'doc-1',
  editorsChoiceAt: editorsChoiceAt,
);

void main() {
  setUpFavouriteCounts();
  late _MockWallpaperDetailBloc bloc;
  late OfflineAssetFixture offlineAssets;

  setUpAll(() => registerFallbackValue(const FetchViews()));

  setUp(() async {
    offlineAssets = await OfflineAssetFixture.create(cacheMissByDefault: true);
    offlineAssets.install();
    getIt.registerSingleton<FavoritesLocalDataSource>(FavoritesLocalDataSource(InMemoryLocalStore()));
    app_state.prismUser = profileUser(loggedIn: false);
    bloc = _MockWallpaperDetailBloc();
  });

  tearDown(() async {
    await offlineAssets.dispose();
    await getIt.reset();
  });

  Future<void> pumpScreen(WidgetTester tester, PrismWallpaper wall) async {
    final entity = FeedItemEntity.prism(id: 'prism-1', wallpaper: wall);
    whenListen(
      bloc,
      const Stream<WallpaperDetailState>.empty(),
      initialState: WallpaperDetailLoaded(
        recommendations: const RecommendationState.exhausted(),
        entity: entity,
        paletteLoading: false,
        panelCollapsed: false,
      ),
    );
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: BlocProvider<WallpaperDetailBloc>.value(
          value: bloc,
          child: WallpaperDetailScreen(entity: entity),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 400));
  }

  testWidgets("a picked wall shows the Editors' Choice label", (tester) async {
    await pumpScreen(tester, _wall(editorsChoiceAt: DateTime(2026)));

    expect(find.text("Editors' Choice"), findsOneWidget);
  });

  testWidgets("an unpicked wall shows no Editors' Choice label", (tester) async {
    await pumpScreen(tester, _wall());

    expect(find.text("Editors' Choice"), findsNothing);
  });
}
