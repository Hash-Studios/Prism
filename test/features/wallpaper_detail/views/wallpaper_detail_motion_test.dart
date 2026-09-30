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

class _MockDetailBloc extends MockBloc<WallpaperDetailEvent, WallpaperDetailState> implements WallpaperDetailBloc {}

void main() {
  for (final tag in <String?>['tile-1', null]) {
    testWidgets('reduced-motion detail loading disables flights and fades (tag $tag)', (tester) async {
      final bloc = _MockDetailBloc();
      whenListen(
        bloc,
        const Stream<WallpaperDetailState>.empty(),
        initialState: const WallpaperDetailLoading(thumbnailUrl: 'https://example.com/thumb.jpg'),
      );
      await tester.pumpWidget(
        MaterialApp(
          home: MediaQuery(
            data: const MediaQueryData(disableAnimations: true),
            child: BlocProvider<WallpaperDetailBloc>.value(
              value: bloc,
              child: WallpaperDetailScreen(wallId: 'wall', source: WallpaperSource.prism, heroTag: tag),
            ),
          ),
        ),
      );
      if (tag != null) {
        expect(tester.widget<HeroMode>(find.byType(HeroMode)).enabled, isFalse);
      } else {
        expect(find.byType(Hero), findsNothing);
      }
      final image = tester.widget<CachedNetworkImage>(find.byType(CachedNetworkImage));
      expect(image.fadeInDuration, Duration.zero);
      expect(image.fadeOutDuration, Duration.zero);
      await tester.pumpWidget(const SizedBox());
    });
  }
}
