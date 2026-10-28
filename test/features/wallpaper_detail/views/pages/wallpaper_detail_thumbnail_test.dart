import 'package:Prism/core/wallpaper/wallpaper_source.dart';
import 'package:Prism/features/wallpaper_detail/biz/bloc/wallpaper_detail_bloc.dart';
import 'package:Prism/features/wallpaper_detail/biz/bloc/wallpaper_detail_event.dart';
import 'package:Prism/features/wallpaper_detail/biz/bloc/wallpaper_detail_state.dart';
import 'package:Prism/features/wallpaper_detail/views/pages/wallpaper_detail_screen.dart';
import 'package:Prism/l10n/l10n.dart';
import 'package:bloc_test/bloc_test.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import '../../../../support/favourite_test_scope.dart';
import '../../../../support/wallpaper_image_finders.dart';

class _MockWallpaperDetailBloc extends MockBloc<WallpaperDetailEvent, WallpaperDetailState>
    implements WallpaperDetailBloc {}

void main() {
  setUpFavouriteCounts();
  late _MockWallpaperDetailBloc bloc;

  setUp(() {
    bloc = _MockWallpaperDetailBloc();
    when(() => bloc.state).thenReturn(const WallpaperDetailLoading());
  });

  Future<void> pumpDetail(WidgetTester tester, {required WallpaperDetailState state, String? thumbnailUrl}) async {
    when(() => bloc.state).thenReturn(state);
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,

        home: BlocProvider<WallpaperDetailBloc>.value(
          value: bloc,
          child: WallpaperDetailScreen(
            wallId: 'wall-id',
            source: WallpaperSource.wallhaven,
            thumbnailUrl: thumbnailUrl,
          ),
        ),
      ),
    );
  }

  testWidgets('normalizes the route thumbnail in the initial state', (tester) async {
    const String crop = 'https://th.wallhaven.cc/lg/21/wall.jpg';
    await pumpDetail(tester, state: const WallpaperDetailInitial(), thumbnailUrl: crop);

    expect(networkImageUrls(tester), ['https://th.wallhaven.cc/lg/21/wall.jpg']);
  });

  testWidgets('normalizes the loading-state URL instead of the route fallback', (tester) async {
    const String crop = 'https://th.wallhaven.cc/small/21/state.jpg';
    await pumpDetail(
      tester,
      state: const WallpaperDetailLoading(thumbnailUrl: crop),
      thumbnailUrl: 'https://th.wallhaven.cc/lg/21/route.jpg',
    );

    expect(networkImageUrls(tester), ['https://th.wallhaven.cc/lg/21/state.jpg']);
  });

  testWidgets('keeps a non-Wallhaven URL unchanged', (tester) async {
    const String pexelsUrl = 'https://images.pexels.com/photos/1/tiny.jpg';
    await pumpDetail(tester, state: const WallpaperDetailLoading(thumbnailUrl: pexelsUrl));
    expect(networkImageUrls(tester), [pexelsUrl]);
  });

  testWidgets('does not build a cached image when the route thumbnail is null', (tester) async {
    await pumpDetail(tester, state: const WallpaperDetailInitial());
    expect(find.byType(CachedNetworkImage), findsNothing);
  });

  testWidgets('an empty route thumbnail shows localized loading without image or Hero widgets', (tester) async {
    await pumpDetail(tester, state: const WallpaperDetailInitial(), thumbnailUrl: '');

    final AppLocalizations l10n = AppLocalizations.of(tester.element(find.byType(WallpaperDetailScreen)));
    expect(find.text(l10n.wallpaperLoadingWallpaper), findsOneWidget);
    expect(find.byType(CachedNetworkImage), findsNothing);
    expect(find.byType(Image), findsNothing);
    expect(find.byType(Hero), findsNothing);
    verify(
      () => bloc.add(const LoadFromId(wallId: 'wall-id', source: WallpaperSource.wallhaven, thumbnailUrl: '')),
    ).called(1);
  });

  testWidgets('an empty loading-state thumbnail does not fall back to the route image', (tester) async {
    await pumpDetail(
      tester,
      state: const WallpaperDetailLoading(thumbnailUrl: ''),
      thumbnailUrl: 'https://th.wallhaven.cc/lg/21/route.jpg',
    );

    final AppLocalizations l10n = AppLocalizations.of(tester.element(find.byType(WallpaperDetailScreen)));
    expect(find.text(l10n.wallpaperLoadingWallpaper), findsOneWidget);
    expect(find.byType(CachedNetworkImage), findsNothing);
    expect(find.byType(Image), findsNothing);
    expect(find.byType(Hero), findsNothing);
  });

  testWidgets('an empty error thumbnail shows the not-found message and retries with the same id and source', (
    tester,
  ) async {
    await pumpDetail(
      tester,
      state: const WallpaperDetailError(failure: WallpaperDetailLoadFailure.notFound, thumbnailUrl: ''),
      thumbnailUrl: '',
    );

    final AppLocalizations l10n = AppLocalizations.of(tester.element(find.byType(WallpaperDetailScreen)));
    expect(find.text(l10n.wallpaperOpenError), findsOneWidget);
    expect(find.text(l10n.wallpaperDetailNotFound), findsOneWidget);
    expect(find.byType(CachedNetworkImage), findsNothing);
    expect(find.byType(Image), findsNothing);
    expect(find.byType(Hero), findsNothing);

    await tester.tap(find.text(l10n.wallpaperTryAgain));
    await tester.pump();

    verify(
      () => bloc.add(const LoadFromId(wallId: 'wall-id', source: WallpaperSource.wallhaven, thumbnailUrl: '')),
    ).called(2);
  });
}
