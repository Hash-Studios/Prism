import 'package:Prism/core/di/injection.dart';
import 'package:Prism/core/persistence/data_sources/favorites_local_data_source.dart';
import 'package:Prism/core/persistence/data_sources/settings_local_data_source.dart';
import 'package:Prism/core/personalization/taste_signals.dart';
import 'package:Prism/core/wallpaper/wall_desktop.dart';
import 'package:Prism/core/wallpaper/wallpaper_core.dart';
import 'package:Prism/core/wallpaper/wallpaper_source.dart';
import 'package:Prism/core/wallpaper/wallpaper_variants.dart';
import 'package:Prism/features/category_feed/domain/entities/feed_item_entity.dart';
import 'package:Prism/features/wallpaper_detail/biz/bloc/wallpaper_detail_bloc.dart';
import 'package:Prism/features/wallpaper_detail/biz/bloc/wallpaper_detail_event.dart';
import 'package:Prism/features/wallpaper_detail/biz/bloc/wallpaper_detail_state.dart';
import 'package:Prism/features/wallpaper_detail/domain/entities/recommendation_state.dart';
import 'package:Prism/features/wallpaper_detail/views/pages/wallpaper_detail_screen.dart';
import 'package:Prism/features/wallpaper_detail/views/widgets/desktop_version_sheet.dart';
import 'package:Prism/l10n/l10n.dart';
import 'package:bloc_test/bloc_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../../support/favourite_test_scope.dart';
import '../../../../support/in_memory_local_store.dart';
import '../../../../support/offline_asset_fixture.dart';

class _MockWallpaperDetailBloc extends MockBloc<WallpaperDetailEvent, WallpaperDetailState>
    implements WallpaperDetailBloc {}

const WallDesktopVariant _desktop = WallDesktopVariant(
  version: '0123456789abcdef',
  thumbnailUrl: 'https://img.prismwalls.com/previews/desktop-x.jpg',
  width: 2560,
  height: 1600,
);

FeedItemEntity _prism({bool withDesktop = true, List<String>? collections}) => FeedItemEntity.prism(
  id: 'prism-1',
  wallpaper: PrismWallpaper(
    core: const WallpaperCore(
      id: 'prism-1',
      source: WallpaperSource.prism,
      fullUrl: 'https://img.test/full.jpg',
      thumbnailUrl: 'https://img.test/thumb.jpg',
      authorName: 'Akshay',
    ),
    tags: const <String>['space', 'stars'],
    collections: collections,
    desktop: withDesktop ? _desktop : null,
  ),
);

void main() {
  setUpFavouriteCounts();
  late OfflineAssetFixture offlineAssets;
  const MethodChannel toastChannel = MethodChannel('PonnamKarthik/fluttertoast');

  setUp(() async {
    offlineAssets = await OfflineAssetFixture.create();
    offlineAssets.install();
    getIt.registerSingleton<FavoritesLocalDataSource>(FavoritesLocalDataSource(InMemoryLocalStore()));
    getIt.registerSingleton<TasteSignalStore>(TasteSignalStore(SettingsLocalDataSource(InMemoryLocalStore())));
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
      toastChannel,
      (call) async => true,
    );
  });

  tearDown(() async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(toastChannel, null);
    await offlineAssets.dispose();
    await getIt.reset();
  });

  Future<void> pumpDetail(WidgetTester tester, FeedItemEntity entity, {double height = 844}) async {
    tester.view.physicalSize = Size(390 * 3, height * 3);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    final WallpaperDetailLoaded state = WallpaperDetailLoaded(
      recommendations: const RecommendationState.exhausted(),
      entity: entity,
      paletteLoading: false,
    );
    final _MockWallpaperDetailBloc bloc = _MockWallpaperDetailBloc();
    whenListen(bloc, const Stream<WallpaperDetailState>.empty(), initialState: state.copyWith(panelCollapsed: false));
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,

        themeAnimationDuration: Duration.zero,
        home: BlocProvider<WallpaperDetailBloc>.value(
          value: bloc,
          child: WallpaperDetailScreen(entity: state.entity),
        ),
      ),
    );
    await tester.pump();
    await tester.pumpAndSettle();
  }

  testWidgets('a wall with a desktop version shows the Desktop version chip', (tester) async {
    await pumpDetail(tester, _prism());

    expect(find.byType(DesktopVersionChip), findsOneWidget);
    expect(find.text('Desktop version'), findsOneWidget);
  });

  testWidgets('a wall without a desktop version shows no Desktop version chip', (tester) async {
    await pumpDetail(tester, _prism(withDesktop: false));

    expect(find.byType(DesktopVersionChip), findsNothing);
    expect(find.text('Desktop version'), findsNothing);
  });

  testWidgets('a premium wall opens the desktop sheet without Send to my computer', (tester) async {
    await pumpDetail(tester, _prism(collections: const <String>['space']));

    await tester.ensureVisible(find.byType(DesktopVersionChip));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Desktop version'));
    await tester.pumpAndSettle();

    expect(find.byType(DesktopVersionSheet), findsOneWidget);
    expect(find.text('Send to my computer'), findsNothing);
  });
}
