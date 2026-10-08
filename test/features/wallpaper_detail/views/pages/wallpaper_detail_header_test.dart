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
import 'package:Prism/features/wallpaper_detail/views/pages/wallpaper_detail_screen.dart';
import 'package:Prism/features/wallpaper_detail/views/widgets/make_it_live_button.dart';
import 'package:bloc_test/bloc_test.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import '../../../../support/in_memory_local_store.dart';
import '../../../../support/profile_user_fixture.dart';

class _MockWallpaperDetailBloc extends MockBloc<WallpaperDetailEvent, WallpaperDetailState>
    implements WallpaperDetailBloc {}

FeedItemEntity _prism({
  String? title,
  String? authorName = 'Akshay',
  String? authorEmail = 'creator@example.com',
  String? docId = 'doc-1',
  int? width,
  int? height,
}) => FeedItemEntity.prism(
  id: 'prism-1',
  wallpaper: PrismWallpaper(
    core: WallpaperCore(
      id: 'prism-1',
      source: WallpaperSource.prism,
      fullUrl: 'https://img.test/full.jpg',
      thumbnailUrl: 'https://img.test/thumb.jpg',
      authorName: authorName,
      authorEmail: authorEmail,
      width: width,
      height: height,
    ),
    title: title,
    firestoreDocumentId: docId,
  ),
);

void main() {
  late _MockWallpaperDetailBloc bloc;

  setUpAll(() => registerFallbackValue(const FetchViews()));

  setUp(() {
    getIt.registerSingleton<FavoritesLocalDataSource>(FavoritesLocalDataSource(InMemoryLocalStore()));
    app_state.prismUser = profileUser(loggedIn: false);
    bloc = _MockWallpaperDetailBloc();
  });

  tearDown(() => getIt.reset());

  Future<void> pump(WidgetTester tester, WallpaperDetailState state, {FeedItemEntity? entity}) async {
    whenListen(bloc, const Stream<WallpaperDetailState>.empty(), initialState: state);
    await tester.pumpWidget(
      MaterialApp(
        home: BlocProvider<WallpaperDetailBloc>.value(
          value: bloc,
          child: WallpaperDetailScreen(
            entity: entity,
            wallId: entity == null ? 'prism-1' : null,
            source: WallpaperSource.prism,
          ),
        ),
      ),
    );
    await tester.pump();
  }

  group('headline', () {
    testWidgets('shows the title the creator gave, not the id', (tester) async {
      final FeedItemEntity entity = _prism(title: 'Misty pines');
      await pump(tester, WallpaperDetailLoaded(entity: entity, paletteLoading: false), entity: entity);

      expect(find.text('Misty pines'), findsOneWidget);
      expect(find.text('PRISM-1'), findsNothing);
    });

    testWidgets('falls back to Wallpaper by the creator name', (tester) async {
      final FeedItemEntity entity = _prism();
      await pump(tester, WallpaperDetailLoaded(entity: entity, paletteLoading: false), entity: entity);

      expect(find.text('Wallpaper by Akshay'), findsOneWidget);
    });

    testWidgets('never shows an email as the creator', (tester) async {
      final FeedItemEntity entity = _prism(authorName: 'creator@example.com');
      await pump(tester, WallpaperDetailLoaded(entity: entity, paletteLoading: false), entity: entity);

      expect(find.text('Wallpaper by Prism creator'), findsOneWidget);
      expect(find.text('Wallpaper by creator@example.com'), findsNothing);
    });

    testWidgets('shows Set N times from 5 sets', (tester) async {
      final FeedItemEntity entity = _prism();
      await pump(tester, WallpaperDetailLoaded(entity: entity, paletteLoading: false, setCount: 12), entity: entity);

      expect(find.text('Set 12 times'), findsOneWidget);
    });

    testWidgets('hides the set count below 5 and when unknown', (tester) async {
      final FeedItemEntity entity = _prism();
      await pump(tester, WallpaperDetailLoaded(entity: entity, paletteLoading: false, setCount: 4), entity: entity);
      expect(find.textContaining('Set 4'), findsNothing);
      expect(find.textContaining(RegExp(r'Set \d+ times')), findsNothing);

      await pump(tester, WallpaperDetailLoaded(entity: entity, paletteLoading: false), entity: entity);
      expect(find.textContaining(RegExp(r'Set \d+ times')), findsNothing);
    });
  });

  group('block creator', () {
    testWidgets("is offered to a signed-in viewer on someone else's wall", (tester) async {
      app_state.prismUser = profileUser();
      final FeedItemEntity entity = _prism();
      await pump(tester, WallpaperDetailLoaded(entity: entity, paletteLoading: false), entity: entity);

      expect(find.text('Report'), findsOneWidget);
      expect(find.text('Block creator'), findsOneWidget);
    });

    testWidgets('is hidden for a guest', (tester) async {
      final FeedItemEntity entity = _prism();
      await pump(tester, WallpaperDetailLoaded(entity: entity, paletteLoading: false), entity: entity);

      expect(find.text('Report'), findsOneWidget);
      expect(find.text('Block creator'), findsNothing);
    });

    testWidgets('is hidden on your own wall', (tester) async {
      app_state.prismUser = profileUser();
      final FeedItemEntity entity = _prism(authorEmail: 'User@Example.com');
      await pump(tester, WallpaperDetailLoaded(entity: entity, paletteLoading: false), entity: entity);

      expect(find.text('Block creator'), findsNothing);
    });

    testWidgets('is hidden when the creator is unknown', (tester) async {
      app_state.prismUser = profileUser();
      final FeedItemEntity entity = _prism(authorEmail: null);
      await pump(tester, WallpaperDetailLoaded(entity: entity, paletteLoading: false), entity: entity);

      expect(find.text('Block creator'), findsNothing);
    });
  });

  group('load error', () {
    testWidgets('shows a plain message, keeps the thumbnail behind it and loads again on Try again', (tester) async {
      await pump(
        tester,
        const WallpaperDetailError(
          message: 'Check your connection and try again.',
          thumbnailUrl: 'https://img.test/thumb.jpg',
        ),
      );

      expect(find.text("Couldn't load this wallpaper"), findsOneWidget);
      expect(find.text('Check your connection and try again.'), findsOneWidget);
      expect(tester.widget<CachedNetworkImage>(find.byType(CachedNetworkImage)).imageUrl, 'https://img.test/thumb.jpg');

      await tester.tap(find.text('Try again'));
      await tester.pump();
      verify(() => bloc.add(any(that: isA<LoadFromId>()))).called(2);
    });

    testWidgets('a missing wallpaper keeps the not found message', (tester) async {
      await pump(tester, const WallpaperDetailError(message: 'Wallpaper not found'));

      expect(find.text('Wallpaper not found'), findsOneWidget);
      expect(find.byType(CachedNetworkImage), findsNothing);
    });
  });

  group('Live chip', () {
    testWidgets('shows a tappable Live chip on the image when the device supports live wallpapers', (tester) async {
      var opened = 0;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: MakeItLiveChip(onPressed: () => opened++, supportProbe: () async => true),
          ),
        ),
      );
      await tester.pump();

      expect(find.text('Live'), findsOneWidget);
      expect(tester.getSize(find.byType(ConstrainedBox).first).height, greaterThanOrEqualTo(48));
      await tester.tap(find.bySemanticsLabel('Make it live'));
      expect(opened, 1);
    });

    testWidgets('stays hidden when the device does not support live wallpapers', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: MakeItLiveChip(onPressed: () {}, supportProbe: () async => false),
          ),
        ),
      );
      await tester.pump();

      expect(find.text('Live'), findsNothing);
    });
  });

  testWidgets('the panel lists the landscape note for a wide wall', (tester) async {
    final FeedItemEntity entity = _prism(width: 4000, height: 2000);
    await pump(tester, WallpaperDetailLoaded(entity: entity, paletteLoading: false), entity: entity);

    expect(find.text('Landscape wallpaper: the sides will be cropped'), findsOneWidget);
  });
}
