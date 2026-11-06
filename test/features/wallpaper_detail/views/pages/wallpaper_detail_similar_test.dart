import 'package:Prism/core/di/injection.dart';
import 'package:Prism/core/persistence/data_sources/favorites_local_data_source.dart';
import 'package:Prism/core/persistence/data_sources/settings_local_data_source.dart';
import 'package:Prism/core/personalization/taste_signals.dart';
import 'package:Prism/core/wallpaper/wallpaper_core.dart';
import 'package:Prism/core/wallpaper/wallpaper_source.dart';
import 'package:Prism/core/wallpaper/wallpaper_variants.dart';
import 'package:Prism/core/widgets/gesture_hint.dart';
import 'package:Prism/features/category_feed/domain/entities/feed_item_entity.dart';
import 'package:Prism/features/wallpaper_detail/biz/bloc/wallpaper_detail_bloc.dart';
import 'package:Prism/features/wallpaper_detail/biz/bloc/wallpaper_detail_event.dart';
import 'package:Prism/features/wallpaper_detail/biz/bloc/wallpaper_detail_state.dart';
import 'package:Prism/features/wallpaper_detail/domain/entities/recommendation_page.dart';
import 'package:Prism/features/wallpaper_detail/domain/entities/recommendation_state.dart';
import 'package:Prism/features/wallpaper_detail/views/pages/wallpaper_detail_screen.dart';
import 'package:Prism/l10n/l10n.dart';
import 'package:bloc_test/bloc_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../../support/favourite_test_scope.dart';
import '../../../../support/in_memory_local_store.dart';
import '../../../../support/offline_asset_fixture.dart';

class _DetailBloc extends MockBloc<WallpaperDetailEvent, WallpaperDetailState> implements WallpaperDetailBloc {}

FeedItemEntity _item(String id, {String thumbnail = ''}) => PexelsFeedItem(
  id: id,
  wallpaper: PexelsWallpaper(
    core: WallpaperCore(
      id: id,
      source: WallpaperSource.pexels,
      fullUrl: '',
      thumbnailUrl: thumbnail,
      width: 1080,
      height: 1920,
    ),
  ),
);

WallpaperDetailLoaded _loaded({Color? accent, bool paletteLoading = false}) => WallpaperDetailLoaded(
  entity: _item('parent', thumbnail: _thumb),
  paletteLoading: paletteLoading,
  accent: accent,
  recommendations: RecommendationState(
    items: List.generate(30, (index) => _item('$index')),
    kind: RecommendationKind.related,
    status: RecommendationStatus.exhausted,
  ),
);

const String _thumb = 'https://images.pexels.com/photos/1/thumb.jpg';

const double _statusBar = 47;
const double _header = 52;

void main() {
  setUpFavouriteCounts();
  late OfflineAssetFixture assets;
  setUp(() async {
    assets = await OfflineAssetFixture.create();
    assets.install();
    GestureHints.resetForTest();
    getIt.registerSingleton<FavoritesLocalDataSource>(FavoritesLocalDataSource(InMemoryLocalStore()));
    getIt.registerSingleton<TasteSignalStore>(TasteSignalStore(SettingsLocalDataSource(InMemoryLocalStore())));
  });
  tearDown(() async {
    GestureHints.resetForTest();
    await assets.dispose();
    await getIt.reset();
  });

  void sizeView(WidgetTester tester) {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    tester.view.padding = const FakeViewPadding(top: _statusBar, bottom: 34);
    addTearDown(tester.view.reset);
  }

  Widget app(Widget home, {ThemeData? theme}) => MaterialApp(
    builder: favouriteTestBuilder,
    theme: theme,
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: home,
  );

  Widget screen(_DetailBloc bloc) => BlocProvider<WallpaperDetailBloc>.value(
    value: bloc,
    child: WallpaperDetailScreen(entity: _item('parent', thumbnail: _thumb)),
  );

  Future<_DetailBloc> pump(WidgetTester tester, {WallpaperDetailLoaded? state, ThemeData? theme}) async {
    sizeView(tester);
    final bloc = _DetailBloc();
    whenListen(bloc, const Stream<WallpaperDetailState>.empty(), initialState: state ?? _loaded());
    await tester.pumpWidget(app(screen(bloc), theme: theme));
    await tester.pump();
    return bloc;
  }

  ScrollController scrollOf(WidgetTester tester) =>
      tester.widget<CustomScrollView>(find.byType(CustomScrollView)).controller!;

  double opacityOf(WidgetTester tester, String key) =>
      tester.widget<AnimatedOpacity>(find.byKey(ValueKey<String>(key))).opacity;

  /// "More like this" sits just under the solid header once the page snaps to it.
  void expectSnapped(WidgetTester tester) {
    expect(tester.getRect(find.text('More like this')).top, moreOrLessEquals(_statusBar + _header + 20, epsilon: 1));
  }

  testWidgets('a slow drag up from the top past 18% of the screen snaps to the similar walls, and ^ goes back', (
    tester,
  ) async {
    await pump(tester);
    expect(opacityOf(tester, 'detail-back-to-wall'), 0);
    expect(opacityOf(tester, 'detail-header-thumb'), 0);

    await tester.timedDrag(find.byType(CustomScrollView), const Offset(0, -200), const Duration(seconds: 1));
    await tester.pumpAndSettle();
    expectSnapped(tester);
    expect(opacityOf(tester, 'detail-back-to-wall'), 1);
    expect(opacityOf(tester, 'detail-header-thumb'), 1);
    expect(opacityOf(tester, 'detail-header'), 1);

    await tester.tap(find.byTooltip('Scroll to top'));
    await tester.pumpAndSettle();
    expect(scrollOf(tester).offset, 0);
    expect(opacityOf(tester, 'detail-back-to-wall'), 0);
    expect(opacityOf(tester, 'detail-header-thumb'), 0);
  });

  testWidgets('a short slow drag from the top stays where it is', (tester) async {
    await pump(tester);
    await tester.timedDrag(find.byType(CustomScrollView), const Offset(0, -100), const Duration(seconds: 1));
    await tester.pumpAndSettle();
    expect(scrollOf(tester).offset, moreOrLessEquals(100, epsilon: 20));
    expect(opacityOf(tester, 'detail-back-to-wall'), 0);
  });

  testWidgets('a quick flick up from the top snaps to the similar walls', (tester) async {
    await pump(tester);
    await tester.fling(find.byType(CustomScrollView), const Offset(0, -60), 1200);
    await tester.pumpAndSettle();
    expectSnapped(tester);
  });

  testWidgets('a drag that starts below the top scrolls freely', (tester) async {
    await pump(tester);
    scrollOf(tester).jumpTo(40);
    await tester.pump();
    await tester.timedDrag(find.byType(CustomScrollView), const Offset(0, -200), const Duration(seconds: 1));
    await tester.pumpAndSettle();
    expect(scrollOf(tester).offset, moreOrLessEquals(240, epsilon: 20));
  });

  testWidgets('the snap plays a selection haptic and retires the swipe hint', (tester) async {
    getIt.registerSingleton<SettingsLocalDataSource>(SettingsLocalDataSource(InMemoryLocalStore()));
    final List<Object?> haptics = <Object?>[];
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(SystemChannels.platform, (call) async {
      if (call.method == 'HapticFeedback.vibrate') haptics.add(call.arguments);
      return null;
    });
    addTearDown(() => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(SystemChannels.platform, null));
    await pump(tester);
    await tester.pump(const Duration(seconds: 1));
    expect(find.text('Swipe up for similar walls'), findsOneWidget);
    expect(GestureHints.seen(GestureHint.swipeForSimilar).value, isFalse);

    await tester.timedDrag(find.byType(CustomScrollView), const Offset(0, -200), const Duration(seconds: 1));
    await tester.pumpAndSettle();
    expectSnapped(tester);
    expect(GestureHints.seen(GestureHint.swipeForSimilar).value, isTrue);
    expect(haptics, contains('HapticFeedbackType.selectionClick'));
  }, variant: TargetPlatformVariant.only(TargetPlatform.iOS));

  for (final Brightness brightness in Brightness.values) {
    testWidgets('$brightness: the page takes the wall colour once the palette arrives', (tester) async {
      final ThemeData theme = ThemeData(brightness: brightness);
      const Color accent = Color(0xFFE53935);
      Color page() => tester
          .widget<ColoredBox>(
            find.descendant(
              of: find.byKey(const ValueKey<String>('detail-page-tint')),
              matching: find.byType(ColoredBox),
            ),
          )
          .color;
      sizeView(tester);
      final bloc = _DetailBloc();
      whenListen(
        bloc,
        Stream<WallpaperDetailState>.fromFuture(
          Future<WallpaperDetailState>.delayed(const Duration(milliseconds: 100), () => _loaded(accent: accent)),
        ),
        initialState: _loaded(paletteLoading: true),
      );
      await tester.pumpWidget(app(screen(bloc), theme: theme));
      await tester.pump();
      expect(page(), theme.scaffoldBackgroundColor);

      await tester.pump(const Duration(milliseconds: 100));
      await tester.pump(const Duration(milliseconds: 120));
      // Half way through the 240 ms ease, the colour is on its way.
      expect(page(), isNot(theme.scaffoldBackgroundColor));
      await tester.pumpAndSettle();
      final double share = brightness == Brightness.dark ? 0.10 : 0.06;
      expect(page(), Color.alphaBlend(accent.withValues(alpha: share), theme.scaffoldBackgroundColor));
    });
  }

  testWidgets('back, Preview and the action bar fade in after the card lands', (tester) async {
    sizeView(tester);
    final bloc = _DetailBloc();
    whenListen(bloc, const Stream<WallpaperDetailState>.empty(), initialState: _loaded());
    final GlobalKey<NavigatorState> navigator = GlobalKey<NavigatorState>();
    await tester.pumpWidget(
      MaterialApp(
        navigatorKey: navigator,
        builder: favouriteTestBuilder,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: const SizedBox.shrink(),
      ),
    );
    navigator.currentState!.push(MaterialPageRoute<void>(builder: (_) => screen(bloc)));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
    Iterable<double> landed() => tester
        .widgetList<AnimatedOpacity>(find.ancestor(of: find.byTooltip('Back'), matching: find.byType(AnimatedOpacity)))
        .map((fade) => fade.opacity);
    expect(landed(), contains(0));

    await tester.pumpAndSettle();
    expect(landed(), everyElement(1));
  });
}
