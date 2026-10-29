import 'dart:async';

import 'package:Prism/core/di/injection.dart';
import 'package:Prism/core/persistence/data_sources/settings_local_data_source.dart';
import 'package:Prism/core/utils/status.dart';
import 'package:Prism/core/wallpaper/ai_content_filter.dart';
import 'package:Prism/core/widgets/home/wallpapers/loading.dart';
import 'package:Prism/features/public_profile/biz/bloc/public_profile_bloc.j.dart';
import 'package:Prism/features/public_profile/domain/entities/public_profile_wall_entity.dart';
import 'package:Prism/features/public_profile/views/widgets/user_profile_grid.dart';
import 'package:Prism/l10n/l10n.dart';
import 'package:bloc_test/bloc_test.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import '../../support/favourite_test_scope.dart';
import '../../support/in_memory_local_store.dart';

class _MockPublicProfileBloc extends MockBloc<PublicProfileEvent, PublicProfileState> implements PublicProfileBloc {}

void main() {
  setUpFavouriteCounts();
  setUpAll(() => registerFallbackValue(const PublicProfileEvent.refreshRequested()));
  setUp(() => getIt.registerSingleton<SettingsLocalDataSource>(SettingsLocalDataSource(InMemoryLocalStore())));
  tearDown(() async {
    if (getIt.isRegistered<SettingsLocalDataSource>()) await getIt.unregister<SettingsLocalDataSource>();
  });
  late _MockPublicProfileBloc bloc;

  setUp(() {
    bloc = _MockPublicProfileBloc();
    when(() => bloc.isClosed).thenReturn(false);
  });

  Future<void> pumpGrid(WidgetTester tester, PublicProfileState state, {bool ownProfile = false}) async {
    when(() => bloc.state).thenReturn(state);
    await tester.pumpWidget(
      MaterialApp(
        builder: favouriteTestBuilder,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,

        home: Scaffold(
          body: BlocProvider<PublicProfileBloc>.value(
            value: bloc,
            child: CustomScrollView(slivers: <Widget>[UserProfileGrid(ownProfile: ownProfile)]),
          ),
        ),
      ),
    );
    // Glint loops, so pump a bounded time instead of settling.
    await tester.pump(const Duration(milliseconds: 400));
  }

  testWidgets('shows a skeleton before the first load finishes', (tester) async {
    await pumpGrid(tester, PublicProfileState.initial());

    expect(find.byType(LoadingCards), findsOneWidget);
    expect(find.text('No wallpapers yet'), findsNothing);
  });

  testWidgets('says there are no wallpapers yet after a successful empty load', (tester) async {
    await pumpGrid(tester, PublicProfileState.initial().copyWith(status: LoadStatus.success));

    expect(find.text('No wallpapers yet'), findsOneWidget);
    expect(find.text('Upload your first wallpaper to start your gallery.'), findsNothing);
    expect(find.byType(LoadingCards), findsNothing);
    expect(find.byType(SliverGrid), findsNothing);
  });

  testWidgets('invites the owner to upload when their gallery is empty', (tester) async {
    await pumpGrid(tester, PublicProfileState.initial().copyWith(status: LoadStatus.success), ownProfile: true);

    expect(find.text('No wallpapers yet'), findsOneWidget);
    expect(find.text('Upload your first wallpaper to start your gallery.'), findsOneWidget);
  });

  testWidgets('shows an error with a retry that refreshes when the first load failed', (tester) async {
    await pumpGrid(tester, PublicProfileState.initial().copyWith(status: LoadStatus.failure));

    expect(find.text('Could not load wallpapers'), findsOneWidget);
    await tester.tap(find.text('Try again'));
    verify(() => bloc.add(const PublicProfileEvent.refreshRequested())).called(1);
  });

  testWidgets('first loading state stays out of the empty state until a failed load can be retried', (tester) async {
    final states = StreamController<PublicProfileState>();
    addTearDown(states.close);
    final PublicProfileState loading = PublicProfileState.initial().copyWith(status: LoadStatus.loading);
    whenListen(bloc, states.stream, initialState: loading);
    await tester.pumpWidget(
      MaterialApp(
        builder: favouriteTestBuilder,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,

        home: Scaffold(
          body: BlocProvider<PublicProfileBloc>.value(
            value: bloc,
            child: const CustomScrollView(slivers: <Widget>[UserProfileGrid()]),
          ),
        ),
      ),
    );

    expect(find.byType(LoadingCards), findsOneWidget);
    expect(find.text('No wallpapers yet'), findsNothing);

    states.add(PublicProfileState.initial().copyWith(status: LoadStatus.failure));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.text('Could not load wallpapers'), findsOneWidget);
    await tester.tap(find.text('Try again'));
    verify(() => bloc.add(const PublicProfileEvent.refreshRequested())).called(1);
  });

  testWidgets('a cached gallery keeps its retry when refresh fails', (tester) async {
    await pumpGrid(
      tester,
      PublicProfileState.initial().copyWith(
        status: LoadStatus.failure,
        walls: <PublicProfileWallEntity>[
          const PublicProfileWallEntity(id: 'cached', by: 'Ana', wallpaperUrl: 'https://example.com/cached.jpg'),
        ],
      ),
    );

    expect(find.byType(SliverGrid), findsOneWidget);
    expect(find.text('Could not load wallpapers'), findsOneWidget);
    await tester.tap(find.text('Try again'));
    verify(() => bloc.add(const PublicProfileEvent.refreshRequested())).called(1);
  });

  for (final thumbnail in <String, String>{
    'https://th.wallhaven.cc/small/21/profile.jpg': 'https://th.wallhaven.cc/lg/21/profile.jpg',
    'https://images.pexels.com/photos/1/tiny.jpg?fit=crop&w=200&h=280':
        'https://images.pexels.com/photos/1/tiny.jpg?fit=max&w=200&h=280',
  }.entries) {
    testWidgets('normalizes the profile thumbnail ${thumbnail.key}', (tester) async {
      await pumpGrid(
        tester,
        PublicProfileState.initial().copyWith(
          status: LoadStatus.success,
          walls: <PublicProfileWallEntity>[
            PublicProfileWallEntity(
              id: 'wall-1',
              wallpaperThumb: thumbnail.key,
              wallpaperUrl: 'https://example.com/wall.jpg',
            ),
          ],
        ),
      );

      expect(tester.widget<CachedNetworkImage>(find.byType(CachedNetworkImage)).imageUrl, thumbnail.value);
    });
  }

  testWidgets('keeps every loaded wall and places See more in its own grid cell', (tester) async {
    final semantics = tester.ensureSemantics();
    try {
      tester.view.physicalSize = const Size(1000, 3000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final walls = <PublicProfileWallEntity>[
        for (var index = 1; index <= 3; index++)
          PublicProfileWallEntity(id: 'wall-$index', by: 'Author $index', wallpaperUrl: 'https://example.com/$index'),
      ];
      await pumpGrid(
        tester,
        PublicProfileState.initial().copyWith(status: LoadStatus.success, walls: walls, hasMoreWalls: true),
      );

      final grid = tester.widget<SliverGrid>(find.byType(SliverGrid));
      expect((grid.delegate as SliverChildBuilderDelegate).childCount, walls.length + 1);
      for (var index = 1; index <= walls.length; index++) {
        expect(find.bySemanticsLabel('Wallpaper by Author $index'), findsOneWidget);
      }
      expect(find.text('See more'), findsOneWidget);
    } finally {
      semantics.dispose();
    }
  });

  testWidgets('shows the final wall without See more when there is no next page', (tester) async {
    final semantics = tester.ensureSemantics();
    try {
      final walls = <PublicProfileWallEntity>[
        for (var index = 1; index <= 3; index++)
          PublicProfileWallEntity(id: 'wall-$index', by: 'Author $index', wallpaperUrl: 'https://example.com/$index'),
      ];
      await pumpGrid(
        tester,
        PublicProfileState.initial().copyWith(status: LoadStatus.success, walls: walls, hasMoreWalls: false),
      );

      final grid = tester.widget<SliverGrid>(find.byType(SliverGrid));
      expect((grid.delegate as SliverChildBuilderDelegate).childCount, walls.length);
      expect(find.text('See more'), findsNothing);
      expect(find.bySemanticsLabel('Wallpaper by Author 3'), findsOneWidget);
    } finally {
      semantics.dispose();
    }
  });

  group('AI walls hidden', () {
    final walls = <PublicProfileWallEntity>[
      const PublicProfileWallEntity(id: 'ai-1', isAiGenerated: true, wallpaperUrl: 'https://example.com/ai.jpg'),
      const PublicProfileWallEntity(id: 'human-1', wallpaperUrl: 'https://example.com/human.jpg'),
    ];

    Future<void> hideAi() => AiContentFilter.setShowsAi(getIt<SettingsLocalDataSource>(), false);

    int tileCount(WidgetTester tester) =>
        (tester.widget<SliverGrid>(find.byType(SliverGrid)).delegate as SliverChildBuilderDelegate).childCount!;

    testWidgets("drops AI walls from another user's profile", (tester) async {
      await hideAi();
      await pumpGrid(
        tester,
        PublicProfileState.initial().copyWith(status: LoadStatus.success, walls: walls, hasMoreWalls: false),
      );

      expect(tileCount(tester), 1);
    });

    testWidgets("keeps AI walls on the signed-in user's own profile", (tester) async {
      await hideAi();
      await pumpGrid(
        tester,
        PublicProfileState.initial().copyWith(status: LoadStatus.success, walls: walls, hasMoreWalls: false),
        ownProfile: true,
      );

      expect(tileCount(tester), 2);
    });

    testWidgets('shows the empty state with a switch back on when only AI walls are left', (tester) async {
      await hideAi();
      await pumpGrid(
        tester,
        PublicProfileState.initial().copyWith(
          status: LoadStatus.success,
          walls: walls.take(1).toList(),
          hasMoreWalls: false,
        ),
      );

      expect(find.text('No human-made walls here yet'), findsOneWidget);
      await tester.tap(find.text('Show AI walls'));
      await tester.pump();
      expect(AiContentFilter.showsAi(getIt<SettingsLocalDataSource>()), isTrue);
      verify(() => bloc.add(const PublicProfileEvent.refreshRequested())).called(1);
    });

    testWidgets('does not refresh a profile after the AI setting write completes post-disposal', (tester) async {
      final InMemoryLocalStore store = InMemoryLocalStore();
      final SettingsLocalDataSource initialSettings = SettingsLocalDataSource(store);
      await AiContentFilter.setShowsAi(initialSettings, false);
      await getIt.unregister<SettingsLocalDataSource>();
      final _DelayedSettingsLocalDataSource settings = _DelayedSettingsLocalDataSource(store);
      getIt.registerSingleton<SettingsLocalDataSource>(settings);
      await pumpGrid(
        tester,
        PublicProfileState.initial().copyWith(
          status: LoadStatus.success,
          walls: walls.take(1).toList(),
          hasMoreWalls: false,
        ),
      );

      await tester.tap(find.text('Show AI walls'));
      await tester.pumpWidget(const SizedBox.shrink());
      settings.release.complete();
      await tester.pump();

      verifyNever(() => bloc.add(const PublicProfileEvent.refreshRequested()));
    });

    testWidgets('shows retry after the next hidden page fails instead of claiming the profile is exhausted', (
      tester,
    ) async {
      await hideAi();
      await pumpGrid(
        tester,
        PublicProfileState.initial().copyWith(
          status: LoadStatus.failure,
          walls: walls.take(1).toList(),
          hasMoreWalls: true,
        ),
      );

      expect(find.text('Could not load wallpapers'), findsOneWidget);
      expect(find.text('No human-made walls here yet'), findsNothing);
      expect(find.text('Try again'), findsOneWidget);
    });

    testWidgets('bounds hidden-page scans at five, exposes a fetching retry, and resets the cap on refresh', (
      tester,
    ) async {
      await hideAi();
      final states = StreamController<PublicProfileState>.broadcast(sync: true);
      addTearDown(states.close);
      var state = PublicProfileState.initial().copyWith(
        status: LoadStatus.success,
        profileId: 'profile',
        walls: <PublicProfileWallEntity>[
          const PublicProfileWallEntity(id: 'ai-0', isAiGenerated: true, wallpaperUrl: ''),
        ],
        hasMoreWalls: true,
      );
      var fetchMoreCalls = 0;
      whenListen(bloc, states.stream, initialState: state);
      when(() => bloc.isClosed).thenReturn(false);
      when(() => bloc.close()).thenAnswer((_) async {});
      when(() => bloc.add(any())).thenAnswer((invocation) {
        if (invocation.positionalArguments.single == const PublicProfileEvent.fetchMoreWallsRequested()) {
          fetchMoreCalls++;
        }
      });

      await tester.pumpWidget(
        MaterialApp(
          builder: favouriteTestBuilder,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: BlocProvider<PublicProfileBloc>.value(
              value: bloc,
              child: const CustomScrollView(slivers: <Widget>[UserProfileGrid()]),
            ),
          ),
        ),
      );
      await tester.pump();
      for (var page = 1; page < 5; page++) {
        state = state.copyWith(
          walls: <PublicProfileWallEntity>[
            ...state.walls,
            PublicProfileWallEntity(id: 'ai-$page', isAiGenerated: true, wallpaperUrl: ''),
          ],
        );
        states.add(state);
        await tester.pump();
        await tester.pump();
      }

      expect(fetchMoreCalls, 5);
      state = state.copyWith(
        walls: <PublicProfileWallEntity>[
          ...state.walls,
          const PublicProfileWallEntity(id: 'ai-cap', isAiGenerated: true, wallpaperUrl: ''),
        ],
      );
      states.add(state);
      await tester.pump();
      expect(find.text('Try again'), findsOneWidget);
      await tester.tap(find.text('Try again'));
      expect(fetchMoreCalls, 6);
      state = state.copyWith(isFetchingMoreWalls: true);
      states.add(state);
      await tester.pump();
      expect(find.byType(LoadingCards), findsOneWidget);

      state = state.copyWith(status: LoadStatus.loading, isFetchingMoreWalls: false);
      states.add(state);
      await tester.pump();
      state = state.copyWith(status: LoadStatus.success);
      states.add(state);
      await tester.pump();
      await tester.pump();

      expect(fetchMoreCalls, 7);
    });
  });
}

class _DelayedSettingsLocalDataSource extends SettingsLocalDataSource {
  _DelayedSettingsLocalDataSource(super.store);

  final Completer<void> release = Completer<void>();

  @override
  Future<void> set(String key, Object? value) async {
    await release.future;
    await super.set(key, value);
  }
}
