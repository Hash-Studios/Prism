import 'package:Prism/core/di/injection.dart';
import 'package:Prism/core/persistence/data_sources/settings_local_data_source.dart';
import 'package:Prism/core/utils/status.dart';
import 'package:Prism/core/wallpaper/ai_content_filter.dart';
import 'package:Prism/core/wallpaper/wallpaper_core.dart';
import 'package:Prism/core/wallpaper/wallpaper_source.dart';
import 'package:Prism/core/wallpaper/wallpaper_variants.dart';
import 'package:Prism/features/personalized_feed/views/widgets/trending_chip_sliver.dart';
import 'package:Prism/features/trending/biz/bloc/trending_bloc.j.dart';
import 'package:Prism/l10n/l10n.dart';
import 'package:bloc_test/bloc_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import '../../../support/in_memory_local_store.dart';

class _MockTrendingBloc extends MockBloc<TrendingEvent, TrendingState> implements TrendingBloc {}

PrismWallpaper _aiWall(String id) => PrismWallpaper(
  core: WallpaperCore(id: id, source: WallpaperSource.prism, fullUrl: '', thumbnailUrl: ''),
  isAiGenerated: true,
);

void main() {
  tearDown(() async {
    await getIt.reset();
  });

  testWidgets('an all-AI trending list with AI hidden offers Show AI walls, which turns the setting on', (
    tester,
  ) async {
    final SettingsLocalDataSource settings = SettingsLocalDataSource(InMemoryLocalStore());
    getIt.registerSingleton<SettingsLocalDataSource>(settings);
    await AiContentFilter.setShowsAi(settings, false);
    final trending = _MockTrendingBloc();
    when(() => trending.state).thenReturn(
      TrendingState.initial().copyWith(status: LoadStatus.success, walls: <PrismWallpaper>[_aiWall('a'), _aiWall('b')]),
    );
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: CustomScrollView(
            slivers: <Widget>[
              TrendingChipSliver(bloc: trending, crossAxisCount: 3, tileMemCacheHeight: 400, showAi: false),
            ],
          ),
        ),
      ),
    );

    expect(find.text('No human-made walls here yet'), findsOneWidget);
    await tester.tap(find.text('Show AI walls'));
    await tester.pump();

    expect(AiContentFilter.showsAi(settings), isTrue);
  });
}
