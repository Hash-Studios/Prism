import 'package:Prism/core/di/injection.dart';
import 'package:Prism/core/persistence/data_sources/favorites_local_data_source.dart';
import 'package:Prism/core/state/app_state.dart' as app_state;
import 'package:Prism/core/wallpaper/wallpaper_core.dart';
import 'package:Prism/core/wallpaper/wallpaper_source.dart';
import 'package:Prism/core/wallpaper/wallpaper_variants.dart';
import 'package:Prism/core/widgets/prism_glass.dart';
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

    testWidgets('falls back to the id, with the creator name on the line below', (tester) async {
      final FeedItemEntity entity = _prism();
      await pump(tester, WallpaperDetailLoaded(entity: entity, paletteLoading: false), entity: entity);

      expect(find.text('PRISM-1'), findsOneWidget);
      expect(find.text('by Akshay'), findsOneWidget);
    });

    testWidgets('never puts an email in the headline', (tester) async {
      final FeedItemEntity entity = _prism(authorName: 'creator@example.com');
      await pump(tester, WallpaperDetailLoaded(entity: entity, paletteLoading: false), entity: entity);

      expect(find.text('PRISM-1'), findsOneWidget);
      expect(find.text('Wallpaper by creator@example.com'), findsNothing);
    });

    testWidgets('shows Set N times from 5 sets', (tester) async {
      final FeedItemEntity entity = _prism();
      await pump(tester, WallpaperDetailLoaded(entity: entity, paletteLoading: false, setCount: 12), entity: entity);

      expect(find.text('12 times'), findsOneWidget);
    });

    testWidgets('hides the set count below 5 and when unknown', (tester) async {
      final FeedItemEntity entity = _prism();
      await pump(tester, WallpaperDetailLoaded(entity: entity, paletteLoading: false, setCount: 4), entity: entity);
      expect(find.text('4 times'), findsNothing);

      await pump(tester, WallpaperDetailLoaded(entity: entity, paletteLoading: false), entity: entity);
      expect(find.textContaining(RegExp(r'^\d+ times$')), findsNothing);
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
    testWidgets('shows a tappable glass Live pill with a 48 px touch target when the device supports live walls', (
      tester,
    ) async {
      var opened = 0;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: MakeItLiveChip(onPressed: () => opened++, supportProbe: () async => true),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      expect(find.text('Live'), findsOneWidget);
      expect(tester.getSize(find.byType(PrismGlass)).height, 32);
      final Size target = tester.getSize(
        find.descendant(of: find.byType(MakeItLiveChip), matching: find.byType(GestureDetector)),
      );
      expect(target.height, 48);
      expect(target.width, inInclusiveRange(48, 150));
      await tester.tap(find.bySemanticsLabel('Make it live'));
      expect(opened, 1);
    });

    testWidgets('shrinks a little under the finger', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: MakeItLiveChip(onPressed: () {}, supportProbe: () async => true),
          ),
        ),
      );
      await tester.pump();
      double scale() => tester
          .widget<Transform>(find.descendant(of: find.byType(MakeItLiveChip), matching: find.byType(Transform)).first)
          .transform
          .storage[0];

      final TestGesture finger = await tester.startGesture(tester.getCenter(find.byType(PrismGlass)));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));
      final double pressed = scale();
      await finger.up();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      expect(pressed, closeTo(0.96, 0.001));
      expect(scale(), 1);
    });

    Future<void> pumpChip(
      WidgetTester tester, {
      double textScale = 1,
      bool reduceMotion = false,
      Brightness brightness = Brightness.dark,
    }) async {
      await tester.pumpWidget(
        MaterialApp(
          themeAnimationDuration: Duration.zero,
          theme: ThemeData(brightness: brightness, primaryColor: const Color(0xFF204060)),
          builder: (BuildContext context, Widget? child) => MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(textScaler: TextScaler.linear(textScale), disableAnimations: reduceMotion),
            child: child!,
          ),
          home: Scaffold(
            body: MakeItLiveChip(onPressed: () {}, supportProbe: () async => true),
          ),
        ),
      );
      await tester.pump();
    }

    double chipOpacity(WidgetTester tester) => tester
        .widget<Opacity>(find.descendant(of: find.byType(MakeItLiveChip), matching: find.byType(Opacity)).first)
        .opacity;

    testWidgets('fades in over 160 ms when the probe answers, instead of popping in', (tester) async {
      await pumpChip(tester);
      final double first = chipOpacity(tester);

      await tester.pump(const Duration(milliseconds: 80));
      final double midway = chipOpacity(tester);
      await tester.pump(const Duration(milliseconds: 100));

      expect(first, 0);
      expect(midway, inExclusiveRange(0.3, 0.95));
      expect(chipOpacity(tester), 1);
    });

    testWidgets('shows at once when the device asks for less motion', (tester) async {
      await pumpChip(tester, reduceMotion: true);

      expect(chipOpacity(tester), 1);
    });

    testWidgets('its label scales with the system text only up to 1.5 times, and the pill follows the label', (
      tester,
    ) async {
      final Map<double, Size> pill = <double, Size>{};
      for (final double scale in <double>[1, 1.5, 2]) {
        await pumpChip(tester, textScale: scale);
        await tester.pump(const Duration(milliseconds: 200));
        pill[scale] = tester.getSize(find.byType(PrismGlass));
      }

      expect(pill[1.5]!.width, greaterThan(pill[1]!.width));
      expect(pill[2], pill[1.5]);
      expect(pill[2]!.height, 32);
    });

    testWidgets('sits on a dark scrim with white text, on a light theme as on a dark one', (tester) async {
      for (final Brightness brightness in <Brightness>[Brightness.dark, Brightness.light]) {
        await pumpChip(tester, brightness: brightness);
        final PrismGlass glass = tester.widget<PrismGlass>(find.byType(PrismGlass));

        expect(glass.glassColor, Colors.black.withValues(alpha: 0.5));
        expect(glass.thickness, 16);
        expect(tester.widget<Text>(find.text('Live')).style?.color, Colors.white);
      }
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
