import 'package:Prism/core/wallpaper/wallpaper_source.dart';
import 'package:Prism/features/wallpaper_detail/biz/bloc/wallpaper_detail_bloc.dart';
import 'package:Prism/features/wallpaper_detail/biz/bloc/wallpaper_detail_event.dart';
import 'package:Prism/features/wallpaper_detail/biz/bloc/wallpaper_detail_state.dart';
import 'package:Prism/features/wallpaper_detail/views/pages/wallpaper_detail_screen.dart';
import 'package:bloc_test/bloc_test.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockWallpaperDetailBloc extends MockBloc<WallpaperDetailEvent, WallpaperDetailState>
    implements WallpaperDetailBloc {}

void main() {
  late _MockWallpaperDetailBloc bloc;

  setUp(() {
    bloc = _MockWallpaperDetailBloc();
    when(() => bloc.state).thenReturn(const WallpaperDetailLoading());
  });

  Future<void> pumpDetail(WidgetTester tester, {required WallpaperDetailState state, String? thumbnailUrl}) async {
    when(() => bloc.state).thenReturn(state);
    await tester.pumpWidget(
      MaterialApp(
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

    expect(
      tester.widget<CachedNetworkImage>(find.byType(CachedNetworkImage)).imageUrl,
      'https://th.wallhaven.cc/lg/21/wall.jpg',
    );
  });

  testWidgets('normalizes the loading-state URL instead of the route fallback', (tester) async {
    const String crop = 'https://th.wallhaven.cc/small/21/state.jpg';
    await pumpDetail(
      tester,
      state: const WallpaperDetailLoading(thumbnailUrl: crop),
      thumbnailUrl: 'https://th.wallhaven.cc/lg/21/route.jpg',
    );

    expect(
      tester.widget<CachedNetworkImage>(find.byType(CachedNetworkImage)).imageUrl,
      'https://th.wallhaven.cc/lg/21/state.jpg',
    );
  });

  testWidgets('keeps a non-Wallhaven URL unchanged', (tester) async {
    const String pexelsUrl = 'https://images.pexels.com/photos/1/tiny.jpg';
    await pumpDetail(tester, state: const WallpaperDetailLoading(thumbnailUrl: pexelsUrl));
    expect(tester.widget<CachedNetworkImage>(find.byType(CachedNetworkImage)).imageUrl, pexelsUrl);
  });

  testWidgets('does not build a cached image when the route thumbnail is null', (tester) async {
    await pumpDetail(tester, state: const WallpaperDetailInitial());
    expect(find.byType(CachedNetworkImage), findsNothing);
  });
}
