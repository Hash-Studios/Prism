import 'dart:async';

import 'package:Prism/core/analytics/analytics_runtime.dart';
import 'package:Prism/core/coins/coins_service.dart';
import 'package:Prism/core/di/injection.dart';
import 'package:Prism/core/persistence/data_sources/settings_local_data_source.dart';
import 'package:Prism/core/router/app_router.dart';
import 'package:Prism/core/state/app_state.dart' as app_state;
import 'package:Prism/core/utils/result.dart';
import 'package:Prism/core/utils/status.dart';
import 'package:Prism/core/widgets/cosmetics/profile_frame.dart';
import 'package:Prism/core/widgets/prism/prism_ui.dart';
import 'package:Prism/features/badges/views/widgets/profile_badge_row.dart';
import 'package:Prism/features/favourite_walls/biz/bloc/favourite_walls_bloc.j.dart';
import 'package:Prism/features/folders/views/widgets/profile_folders_row.dart';
import 'package:Prism/features/profile_completeness/views/widgets/profile_completeness_card.dart';
import 'package:Prism/features/public_profile/biz/bloc/public_profile_bloc.j.dart';
import 'package:Prism/features/public_profile/domain/entities/public_profile_entity.dart';
import 'package:Prism/features/public_profile/domain/entities/public_profile_wall_entity.dart';
import 'package:Prism/features/public_profile/domain/entities/user_relation_kind.dart';
import 'package:Prism/features/public_profile/domain/entities/user_summary_entity.dart';
import 'package:Prism/features/public_profile/domain/repositories/public_profile_repository.dart';
import 'package:Prism/features/public_profile/views/pages/profile_screen.dart';
import 'package:Prism/features/public_profile/views/widgets/pro_profile_badge.dart';
import 'package:Prism/features/public_profile/views/widgets/profile_cover.dart';
import 'package:Prism/features/rewards/views/widgets/rank_progress_card.dart';
import 'package:Prism/features/user_blocks/domain/repositories/user_block_repository.dart';
import 'package:Prism/l10n/generated/app_localizations_en.dart';
import 'package:Prism/l10n/l10n.dart';
import 'package:auto_route/auto_route.dart';
import 'package:bloc_test/bloc_test.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import '../../support/fake_app_analytics.dart';
import '../../support/fake_user_block_repository.dart';
import '../../support/favourite_test_scope.dart';
import '../../support/in_memory_local_store.dart';
import '../../support/profile_user_fixture.dart';
import '../creator_directory/creator_directory_test_support.dart';

class _MockPublicProfileBloc extends MockBloc<PublicProfileEvent, PublicProfileState> implements PublicProfileBloc {}

class _MockFavouriteWallsBloc extends MockBloc<FavouriteWallsEvent, FavouriteWallsState>
    implements FavouriteWallsBloc {}

Widget profileFavouriteBuilder(BuildContext context, Widget? child) => favouriteTestBuilder(
  context,
  BlocProvider<FavouriteWallsBloc>(
    create: (_) {
      final bloc = _MockFavouriteWallsBloc();
      whenListen(
        bloc,
        const Stream<FavouriteWallsState>.empty(),
        initialState: FavouriteWallsState.initial().copyWith(
          status: LoadStatus.success,
          userId: app_state.prismUser.id,
        ),
      );
      return bloc;
    },
    child: child,
  ),
);

class _FakeProfileRepository implements PublicProfileRepository {
  final StreamController<PublicProfileEntity?> profiles = StreamController<PublicProfileEntity?>.broadcast();
  final List<String> watchedIdentifiers = <String>[];

  @override
  Stream<PublicProfileEntity?> watchProfile(String identifier) {
    watchedIdentifiers.add(identifier);
    return profiles.stream;
  }

  @override
  Future<Result<List<String>>> fetchRelationIds({
    required String profileUid,
    required UserRelationKind kind,
    String? afterId,
  }) => throw UnimplementedError();

  @override
  Future<void> clearForUser(String userId) async {}

  @override
  Future<Result<({List<PublicProfileWallEntity> items, bool hasMore})>> fetchWalls({
    required String userId,
    required bool refresh,
  }) => throw UnimplementedError();

  @override
  Future<Result<void>> follow({
    required String currentUserId,
    required String currentUserEmail,
    required String targetUserId,
    required String targetUserEmail,
  }) => throw UnimplementedError();

  @override
  Future<Result<void>> unfollow({
    required String currentUserId,
    required String currentUserEmail,
    required String targetUserId,
    required String targetUserEmail,
  }) => throw UnimplementedError();

  @override
  Future<Result<({List<UserSummaryEntity> items, bool hasMore})>> fetchUserSummariesPage({
    required List<String> userIds,
    required int page,
  }) => throw UnimplementedError();

  @override
  Future<Result<List<UserSummaryEntity>>> searchUsersByUsername({
    required String query,
    required List<String> scopeUserIds,
  }) => throw UnimplementedError();
}

class _ProfileSemanticsRouter extends AppRouter {
  @override
  List<AutoRoute> get routes => <AutoRoute>[
    AutoRoute(
      path: '/',
      page: PageInfo('ProfileSemanticsHost', builder: (_) => const Scaffold(body: ProfileScreen())),
    ),
    AutoRoute(
      path: '/following',
      page: PageInfo(FollowingListRoute.name, builder: (_) => const Text('Following destination')),
    ),
    AutoRoute(
      path: '/followers',
      page: PageInfo(FollowersRoute.name, builder: (_) => const Text('Followers destination')),
    ),
  ];
}

const PublicProfileEntity _ana = PublicProfileEntity(
  id: 'u2',
  name: 'Ana Rivera',
  email: '',
  username: 'ana_rivera',
  profilePhoto: '',
  bio: 'Makes calm gradients.',
  links: <String, String>{},
  coverPhoto: '',
);

void main() {
  setUpFavouriteCounts();
  setUp(() => getIt.registerSingleton<SettingsLocalDataSource>(SettingsLocalDataSource(InMemoryLocalStore())));
  tearDown(() async {
    if (getIt.isRegistered<SettingsLocalDataSource>()) await getIt.unregister<SettingsLocalDataSource>();
  });
  late _MockPublicProfileBloc bloc;
  late _FakeProfileRepository repository;
  late FakeUserBlockRepository blocks;

  setUp(() {
    bloc = _MockPublicProfileBloc();
    repository = _FakeProfileRepository();
    blocks = FakeUserBlockRepository.pending()..completeInitial(<String>{});
    AnalyticsRuntime.instance = FakeAppAnalytics();
    getIt
      ..registerFactory<PublicProfileBloc>(() => bloc)
      ..registerSingleton<PublicProfileRepository>(repository)
      ..registerSingleton<UserBlockRepository>(blocks);
    registerCreatorDirectoryFakes(profileBloc: false);
    app_state.prismUser = profileUser(id: 'me', username: 'creator_01', bio: 'Hello', premium: true)
      ..name = 'Me Myself';
    whenListen(
      bloc,
      const Stream<PublicProfileState>.empty(),
      initialState: PublicProfileState.initial().copyWith(profileId: 'me', status: LoadStatus.success),
    );
  });

  tearDown(() async {
    AnalyticsRuntime.reset();
    await repository.profiles.close();
    await getIt.reset();
  });

  Future<void> pumpScreen(WidgetTester tester, {String? identifier}) async {
    // A tall surface keeps the gallery header on screen.
    tester.view.physicalSize = const Size(800, 2400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: ProfileScreen(profileIdentifier: identifier),
        builder: profileFavouriteBuilder,
      ),
    );
    // Glint and skeletons loop, so pump a bounded time instead of settling.
    await tester.pump(const Duration(milliseconds: 400));
  }

  testWidgets('a guest is asked to sign in', (tester) async {
    app_state.prismUser = profileUser(loggedIn: false);

    await pumpScreen(tester);

    expect(find.text('Sign in to use your profile'), findsOneWidget);
    expect(find.byTooltip('Back'), findsOneWidget);
  });

  testWidgets('own profile: current header, completeness card and the redesign empty gallery', (tester) async {
    await pumpScreen(tester);

    // The current header: centred name and username over the cover, the two stats, round icon buttons.
    expect(find.text('Me Myself'), findsOneWidget);
    expect(find.text('@creator_01'), findsOneWidget);
    expect(find.textContaining('Following', findRichText: true), findsOneWidget);
    expect(find.textContaining('Followers', findRichText: true), findsOneWidget);
    expect(tester.getCenter(find.text('Me Myself')).dx, 400);
    expect(find.byIcon(Icons.edit_rounded), findsOneWidget);
    expect(find.byIcon(Icons.menu_rounded), findsOneWidget);
    expect(find.byTooltip('Edit profile'), findsOneWidget);
    expect(find.byTooltip('Menu'), findsOneWidget);
    // Nothing from the redesign header.
    expect(find.text('Pro'), findsNothing);
    expect(find.text('Posts'), findsNothing);
    expect(find.byTooltip('Share profile'), findsNothing);
    expect(find.text('Wallpapers'), findsNothing);
    // The redesign body.
    expect(find.text('Complete your profile'), findsOneWidget);
    expect(find.text('No wallpapers yet'), findsOneWidget);
    expect(find.widgetWithText(PrismButton, 'Upload wallpaper'), findsOneWidget);
    expect(find.text('Upload your first wallpaper to start your gallery.'), findsNothing);
    expect(repository.watchedIdentifiers, <String>['me']);
  });

  testWidgets('own profile: the gallery follows the header, and the XP card comes after it', (tester) async {
    await pumpScreen(tester);

    final double statsBottom = tester.getRect(find.textContaining('Followers', findRichText: true)).bottom;
    final Rect prompt = tester.getRect(find.text('No wallpapers yet'));
    expect(prompt.top - statsBottom, lessThan(48));
    expect(tester.getRect(find.byType(RankProgressCard)).top, greaterThan(prompt.bottom));
  });

  testWidgets('own profile: tight gaps around the cards, so the gallery starts higher', (tester) async {
    await pumpScreen(tester);

    final Rect rank = tester.getRect(find.byType(RankProgressCard));
    final Rect completeness = tester.getRect(find.byType(ProfileCompletenessCard));
    expect(completeness.top - rank.bottom, lessThanOrEqualTo(PrismSpace.xs));
    // The folders row is empty (zero height) while it loads, so the finder must look offstage too.
    final double foldersBottom = tester.getRect(find.byType(ProfileFoldersRow, skipOffstage: false)).bottom;
    expect(
      tester.getRect(find.widgetWithText(PrismButton, 'Upload wallpaper')).top - foldersBottom,
      lessThanOrEqualTo(PrismSpace.md),
    );
  });

  testWidgets('scrolled profile pins the header: back stays and the name shows as the title', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      const MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: ProfileScreen(profileIdentifier: 'u2'),
        builder: profileFavouriteBuilder,
      ),
    );
    await tester.pump(const Duration(milliseconds: 400));
    repository.profiles.add(_ana);
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('Ana Rivera'), findsOneWidget);

    await tester.drag(find.byType(CustomScrollView), const Offset(0, -600));
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.byTooltip('Back'), findsOneWidget);
    expect(tester.getRect(find.byTooltip('Back')).top, greaterThanOrEqualTo(0));
    final Finder title = find.descendant(of: find.byType(AppBar), matching: find.text('Ana Rivera'));
    expect(title, findsOneWidget);
    expect(tester.widget<Opacity>(find.ancestor(of: title, matching: find.byType(Opacity)).first).opacity, 1);
  });

  testWidgets('own profile collapsed: flat header buttons, and Stats and Edit give way to the title', (tester) async {
    tester.view.physicalSize = const Size(390, 600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      const MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: ProfileScreen(),
        builder: profileFavouriteBuilder,
      ),
    );
    await tester.pump(const Duration(milliseconds: 400));
    bool glass(String tooltip) => tester
        .widget<PrismIconButton>(find.ancestor(of: find.byTooltip(tooltip), matching: find.byType(PrismIconButton)))
        .glass;

    expect(glass('Menu'), isTrue);
    expect(find.byTooltip('Stats').hitTestable(), findsOneWidget);

    await tester.drag(find.byType(CustomScrollView), const Offset(0, -600));
    await tester.pump(const Duration(milliseconds: 400));

    expect(glass('Menu'), isFalse);
    expect(find.byTooltip('Menu').hitTestable(), findsOneWidget);
    expect(find.byTooltip('Stats').hitTestable(), findsNothing);
    // The collapsed title (avatar slot, then the name) is centred between Back and the menu.
    final Finder title = find.descendant(of: find.byType(AppBar), matching: find.text('Me Myself'));
    final Rect slot = tester.getRect(find.byKey(const ValueKey<String>('profile-title-avatar-slot')));
    expect((slot.left + tester.getRect(title).right) / 2, closeTo(195, 1));
  });

  Future<void> pumpPhone(WidgetTester tester, {String? identifier, bool reduceMotion = false}) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: ProfileScreen(profileIdentifier: identifier),
        builder: (BuildContext context, Widget? child) => favouriteTestBuilder(
          context,
          MediaQuery(
            data: MediaQuery.of(context).copyWith(disableAnimations: reduceMotion),
            child: child!,
          ),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 400));
    if (identifier != null) {
      repository.profiles.add(_ana);
      await tester.pump(const Duration(milliseconds: 400));
    }
  }

  Rect carriedAvatar(WidgetTester tester) => tester.getRect(
    find.descendant(of: find.byKey(const ValueKey<String>('profile-carried-avatar')), matching: find.byType(ClipOval)),
  );

  for (final String? identifier in <String?>[null, 'u2']) {
    final String who = identifier == null ? 'own' : 'creator';
    testWidgets('$who profile: scroll carries the avatar from the header into the bar next to the name', (
      tester,
    ) async {
      await pumpPhone(tester, identifier: identifier);

      // Expanded: the full avatar sits centred on the cover edge.
      final Rect expanded = carriedAvatar(tester);
      expect(expanded.center.dx, closeTo(195, 1));
      // The photo is clipped 82 across. The 4 point ring covers its outer 2 points, so 78 shows.
      expect(expanded.width, closeTo(82, 1));

      // Half way: smaller and higher, on its way to the bar.
      await tester.drag(find.byType(CustomScrollView), const Offset(0, -70));
      await tester.pump();
      final Rect midway = carriedAvatar(tester);
      expect(midway.width, lessThan(expanded.width));
      expect(midway.center.dy, lessThan(expanded.center.dy));

      // Collapsed: a 28 point avatar exactly on the title slot, next to the name.
      await tester.drag(find.byType(CustomScrollView), const Offset(0, -600));
      await tester.pump(const Duration(milliseconds: 400));
      final Rect slot = tester.getRect(find.byKey(const ValueKey<String>('profile-title-avatar-slot')));
      final Rect collapsed = carriedAvatar(tester);
      expect(collapsed.center.dx, closeTo(slot.center.dx, 0.5));
      expect(collapsed.center.dy, closeTo(slot.center.dy, 0.5));
      expect(collapsed.width, closeTo(82 * 28 / 86, 0.5));
      final String name = identifier == null ? 'Me Myself' : 'Ana Rivera';
      final Rect title = tester.getRect(find.descendant(of: find.byType(AppBar), matching: find.text(name)));
      expect(title.left, greaterThan(slot.right));
      expect((slot.left + title.right) / 2, closeTo(195, 1));
    });
  }

  testWidgets('reduce motion: the avatar does not travel; a small copy fades in with the collapsed name', (
    tester,
  ) async {
    await pumpPhone(tester, reduceMotion: true);

    expect(find.byKey(const ValueKey<String>('profile-carried-avatar')), findsNothing);
    expect(find.byType(ClipOval), findsOneWidget);

    await tester.drag(find.byType(CustomScrollView), const Offset(0, -600));
    await tester.pump(const Duration(milliseconds: 400));

    final Finder slot = find.byKey(const ValueKey<String>('profile-title-avatar-slot'));
    expect(find.descendant(of: slot, matching: find.byType(ClipOval)), findsOneWidget);
    expect(tester.getRect(slot).width, 28);
  });

  testWidgets('one follower reads as a singular label', (tester) async {
    await pumpScreen(tester);
    repository.profiles.add(
      const PublicProfileEntity(
        id: 'me',
        name: 'Me Myself',
        email: '',
        username: 'creator_01',
        profilePhoto: '',
        bio: '',
        links: <String, String>{},
        coverPhoto: '',
        followerCount: 1,
      ),
    );
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.text('1 Follower', findRichText: true), findsOneWidget);
    expect(find.text('1 Followers', findRichText: true), findsNothing);
  });

  testWidgets('own profile keeps private header data and uses UID public graph counts', (tester) async {
    await pumpScreen(tester);
    repository.profiles.add(
      const PublicProfileEntity(
        id: 'me',
        name: 'Should not replace owner name',
        email: 'private@example.com',
        username: 'other_name',
        profilePhoto: 'https://example.com/other.png',
        bio: 'Should not replace owner bio',
        followingCount: 2,
        links: <String, String>{},
        coverPhoto: '',
        followerCount: 41,
        badges: <String>['creator'],
      ),
    );
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.text('Me Myself'), findsOneWidget);
    expect(find.text('Should not replace owner name'), findsNothing);
    expect(find.text('@creator_01'), findsOneWidget);
    expect(tester.getSemantics(find.bySemanticsLabel('2 Following')), isNotNull);
    expect(tester.getSemantics(find.bySemanticsLabel('41 Followers')), isNotNull);
    expect(repository.watchedIdentifiers, <String>['me']);
  });

  testWidgets('own profile shows the Pro badge only while the public profile carries it', (tester) async {
    await pumpScreen(tester);
    PublicProfileEntity graph({required bool proBadge}) => PublicProfileEntity(
      id: 'me',
      name: 'Me Myself',
      email: '',
      username: 'creator_01',
      profilePhoto: '',
      bio: '',
      links: const <String, String>{},
      coverPhoto: '',
      proBadge: proBadge,
    );
    expect(find.byType(ProProfileBadge), findsNothing);

    repository.profiles.add(graph(proBadge: true));
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.byType(ProProfileBadge), findsOneWidget);
    // The Pro pill leads the badge row, so the header has one meta row.
    expect(find.descendant(of: find.byType(ProfileBadgeRow), matching: find.byType(ProProfileBadge)), findsOneWidget);

    repository.profiles.add(graph(proBadge: false));
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.byType(ProProfileBadge), findsNothing);
  });

  testWidgets('tappable profile counts expose button semantics', (tester) async {
    final SemanticsHandle semantics = tester.ensureSemantics();
    try {
      final _ProfileSemanticsRouter router = _ProfileSemanticsRouter();
      tester.view.physicalSize = const Size(800, 2400);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        MaterialApp.router(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          routerConfig: router.config(),
          builder: profileFavouriteBuilder,
        ),
      );
      await router.navigatePath('/');
      await tester.pump(const Duration(milliseconds: 400));

      expect(
        tester.getSemantics(find.bySemanticsLabel('0 Following')),
        matchesSemantics(label: '0 Following', isButton: true, hasTapAction: true),
      );
      expect(
        tester.getSemantics(find.bySemanticsLabel('0 Followers')),
        matchesSemantics(label: '0 Followers', isButton: true, hasTapAction: true),
      );

      final SemanticsNode followers = tester.getSemantics(find.bySemanticsLabel('0 Followers'));
      tester.binding.performSemanticsAction(
        SemanticsActionEvent(type: SemanticsAction.tap, viewId: tester.view.viewId, nodeId: followers.id),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      expect(router.stack.map((AutoRoutePage<dynamic> entry) => entry.name), contains(FollowersRoute.name));
      expect(find.text('Followers destination'), findsOneWidget);

      router.pop();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      await tester.tap(find.textContaining('Following', findRichText: true));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      expect(router.stack.map((AutoRoutePage<dynamic> entry) => entry.name), contains(FollowingListRoute.name));
      expect(find.text('Following destination'), findsOneWidget);
    } finally {
      semantics.dispose();
    }
  });

  testWidgets('the wallpapers of a profile show as the redesign grid under the current header', (tester) async {
    whenListen(
      bloc,
      const Stream<PublicProfileState>.empty(),
      initialState: PublicProfileState.initial().copyWith(
        profileId: 'me',
        status: LoadStatus.success,
        walls: <PublicProfileWallEntity>[
          const PublicProfileWallEntity(id: 'w1', wallpaperUrl: 'https://example.com/1'),
          const PublicProfileWallEntity(id: 'w2', wallpaperUrl: 'https://example.com/2'),
        ],
      ),
    );
    await pumpScreen(tester);

    expect(find.text('Me Myself'), findsOneWidget);
    expect(find.byType(PrismWallTile), findsNWidgets(2));
    expect(find.text('No wallpapers yet'), findsNothing);
  });

  testWidgets('with no custom cover, the latest upload is the blurred cover art', (tester) async {
    whenListen(
      bloc,
      const Stream<PublicProfileState>.empty(),
      initialState: PublicProfileState.initial().copyWith(
        profileId: 'me',
        status: LoadStatus.success,
        walls: <PublicProfileWallEntity>[
          const PublicProfileWallEntity(
            id: 'w1',
            wallpaperUrl: 'https://example.com/1',
            wallpaperThumb: 'https://example.com/t1',
          ),
          const PublicProfileWallEntity(id: 'w2', wallpaperUrl: 'https://example.com/2'),
        ],
      ),
    );
    await pumpScreen(tester);

    final Finder cover = find.descendant(of: find.byType(ProfileCover), matching: find.byType(ImageFiltered));
    final Finder art = find.descendant(of: cover, matching: find.byType(CachedNetworkImage));
    expect(tester.widget<CachedNetworkImage>(art).imageUrl, 'https://example.com/t1');
  });

  testWidgets('the header fits a wide phone with links and scrolls up to the gallery', (tester) async {
    // The test font is wider than Proxima Nova, so the stats row needs this much width.
    tester.view.physicalSize = const Size(540, 960);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    app_state.prismUser = profileUser(
      id: 'me',
      username: 'creator_01',
      bio: 'Hello',
      links: <String, String>{'github': 'https://github.com/a', 'twitter': 'https://twitter.com/a'},
    )..name = 'Me Myself';
    await tester.pumpWidget(
      const MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: ProfileScreen(),
        builder: profileFavouriteBuilder,
      ),
    );
    await tester.pump(const Duration(milliseconds: 400));

    expect(tester.takeException(), isNull);
    expect(find.byTooltip('github'), findsOneWidget);
    await tester.drag(find.byType(CustomScrollView), const Offset(0, -700));
    await tester.pump(const Duration(milliseconds: 400));
    expect(tester.takeException(), isNull);
    expect(find.text('No wallpapers yet'), findsOneWidget);
  });

  testWidgets('own profile header remains reachable on a narrow screen at 2x text', (tester) async {
    tester.view.physicalSize = const Size(320, 568);
    tester.view.devicePixelRatio = 1;
    tester.platformDispatcher.textScaleFactorTestValue = 2;
    addTearDown(tester.view.reset);
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    const String name = 'A very long profile display name for a narrow screen';
    app_state.prismUser = profileUser(
      id: 'me',
      username: 'a_very_long_profile_username_for_a_narrow_screen',
      bio: 'A long profile biography that should remain readable at larger text sizes.',
      links: <String, String>{
        'github': 'https://github.com/a',
        'twitter': 'https://twitter.com/a',
        'instagram': 'https://instagram.com/a',
        'telegram': 'https://t.me/a',
      },
    )..name = name;

    await tester.pumpWidget(
      const MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: ProfileScreen(),
        builder: profileFavouriteBuilder,
      ),
    );
    await tester.pump(const Duration(milliseconds: 400));

    expect(tester.takeException(), isNull);
    expect(find.text(name), findsOneWidget);
    expect(find.byTooltip('github'), findsOneWidget);
    final Finder emptyState = find.text('No wallpapers yet');
    final Finder galleryScrollable = find
        .descendant(of: find.byType(CustomScrollView), matching: find.byType(Scrollable))
        .first;
    await tester.scrollUntilVisible(emptyState, 100, scrollable: galleryScrollable);
    await Scrollable.ensureVisible(tester.element(emptyState), alignment: 0.5);
    await tester.pump(const Duration(milliseconds: 500));
    expect(tester.takeException(), isNull);
    final Rect viewport = tester.getRect(find.byType(CustomScrollView));
    final Rect emptyStateRect = tester.getRect(emptyState);
    expect(emptyStateRect.top, greaterThanOrEqualTo(viewport.top));
    expect(emptyStateRect.bottom, lessThanOrEqualTo(viewport.bottom));
  });

  testWidgets('public profile header remains reachable on a narrow screen at 2x text', (tester) async {
    tester.view.physicalSize = const Size(320, 568);
    tester.view.devicePixelRatio = 1;
    tester.platformDispatcher.textScaleFactorTestValue = 2;
    addTearDown(tester.view.reset);
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    const PublicProfileEntity longProfile = PublicProfileEntity(
      id: 'u2',
      name: 'A very long profile display name for a narrow screen',
      email: '',
      username: 'a_very_long_profile_username_for_a_narrow_screen',
      profilePhoto: '',
      bio: 'A long profile biography that should remain readable at larger text sizes.',
      links: <String, String>{
        'github': 'https://github.com/a',
        'twitter': 'https://twitter.com/a',
        'instagram': 'https://instagram.com/a',
        'telegram': 'https://t.me/a',
      },
      coverPhoto: '',
    );
    whenListen(
      bloc,
      const Stream<PublicProfileState>.empty(),
      initialState: PublicProfileState.initial().copyWith(profileId: 'u2', status: LoadStatus.success),
    );

    await tester.pumpWidget(
      const MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: ProfileScreen(profileIdentifier: 'u2'),
        builder: profileFavouriteBuilder,
      ),
    );
    await tester.pump(const Duration(milliseconds: 400));
    repository.profiles.add(longProfile);
    await tester.pump(const Duration(milliseconds: 400));

    expect(tester.takeException(), isNull);
    expect(find.text(longProfile.name), findsOneWidget);
    expect(find.byTooltip('github'), findsOneWidget);
    final Finder emptyState = find.text('No wallpapers yet');
    final Finder galleryScrollable = find
        .descendant(of: find.byType(CustomScrollView), matching: find.byType(Scrollable))
        .first;
    await tester.scrollUntilVisible(emptyState, 100, scrollable: galleryScrollable);
    await Scrollable.ensureVisible(tester.element(emptyState), alignment: 0.5);
    await tester.pump(const Duration(milliseconds: 500));
    expect(tester.takeException(), isNull);
    final Rect viewport = tester.getRect(find.byType(CustomScrollView));
    final Rect emptyStateRect = tester.getRect(emptyState);
    expect(emptyStateRect.top, greaterThanOrEqualTo(viewport.top));
    expect(emptyStateRect.bottom, lessThanOrEqualTo(viewport.bottom));
  });

  testWidgets('the Menu button opens the drawer with account rows', (tester) async {
    await pumpScreen(tester);

    await tester.tap(find.byTooltip('Menu'));
    await tester.pump(const Duration(milliseconds: 500));

    expect(find.text('Library'), findsOneWidget);
    expect(find.text('Log out'), findsOneWidget);
  });

  testWidgets('another profile shows a skeleton while loading, then the profile with Follow', (tester) async {
    await pumpScreen(tester, identifier: 'u2');
    expect(find.bySemanticsLabel('Loading'), findsWidgets);
    expect(find.text('Ana Rivera'), findsNothing);

    repository.profiles.add(_ana);
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.text('Ana Rivera'), findsOneWidget);
    expect(find.byIcon(Icons.person_add_alt_1_rounded), findsOneWidget);
    expect(find.widgetWithText(PrismButton, 'Follow'), findsOneWidget);
    expect(tester.widget<PrismButton>(find.widgetWithText(PrismButton, 'Follow')).variant, PrismButtonVariant.primary);
    expect(find.byTooltip('More options'), findsOneWidget);
    expect(find.byTooltip('Edit profile'), findsNothing);
    expect(find.text('Upload your first wallpaper to start your gallery.'), findsNothing);
    // Header buttons over the cover use the glass look, readable on a light cover.
    for (final IconData icon in <IconData>[Icons.arrow_back_rounded, Icons.card_giftcard_rounded]) {
      expect(tester.widget<PrismIconButton>(find.widgetWithIcon(PrismIconButton, icon)).glass, isTrue);
    }
  });

  testWidgets('the Follow button asks the bloc to follow, and shows Unfollow when already followed', (tester) async {
    await pumpScreen(tester, identifier: 'u2');
    repository.profiles.add(_ana);
    await tester.pump(const Duration(milliseconds: 400));

    await tester.tap(find.widgetWithText(PrismButton, 'Follow'));
    verify(
      () => bloc.add(
        const PublicProfileEvent.followChangeRequested(
          follow: true,
          currentUserId: 'me',
          currentUserEmail: 'user@example.com',
          targetUserId: 'u2',
          targetUserEmail: '',
          targetName: 'Ana Rivera',
        ),
      ),
    ).called(1);

    whenListen(
      bloc,
      const Stream<PublicProfileState>.empty(),
      initialState: PublicProfileState.initial().copyWith(
        profileId: 'u2',
        status: LoadStatus.success,
        followOverrides: <String, bool>{'u2': true},
      ),
    );
    await tester.pumpWidget(const SizedBox.shrink());
    await pumpScreen(tester, identifier: 'u2');
    repository.profiles.add(_ana);
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.widgetWithText(PrismButton, 'Following'), findsOneWidget);
    expect(find.byIcon(Icons.check_rounded), findsOneWidget);
    expect(tester.widget<PrismButton>(find.widgetWithText(PrismButton, 'Following')).variant, PrismButtonVariant.tonal);
  });

  testWidgets('the first three links show as buttons and the rest open from a More links button', (tester) async {
    await pumpScreen(tester, identifier: 'u2');
    repository.profiles.add(
      const PublicProfileEntity(
        id: 'u2',
        name: 'Ana Rivera',
        email: '',
        username: 'ana_rivera',
        profilePhoto: '',
        bio: '',
        links: <String, String>{
          'github': 'https://github.com/a',
          'twitter': 'https://twitter.com/a',
          'instagram': 'https://instagram.com/a',
          'telegram': 'https://t.me/a',
        },
        coverPhoto: '',
      ),
    );
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.byTooltip('github'), findsOneWidget);
    expect(find.byTooltip('twitter'), findsOneWidget);
    expect(find.byTooltip('instagram'), findsOneWidget);
    expect(find.byTooltip('telegram'), findsNothing);
    await tester.tap(find.byTooltip('More links'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    expect(find.text('More links'), findsOneWidget);
    expect(find.byTooltip('Telegram'), findsOneWidget);
  });

  testWidgets('another profile that has been deleted says it is not available', (tester) async {
    await pumpScreen(tester, identifier: 'u2');

    repository.profiles.add(null);
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.text('Profile not available'), findsOneWidget);
    expect(find.byTooltip('Back'), findsOneWidget);
  });

  testWidgets('a failed profile stream shows an error with a retry', (tester) async {
    await pumpScreen(tester, identifier: 'u2');

    repository.profiles.addError(StateError('boom'));
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.text('Could not load this profile'), findsOneWidget);
    expect(find.text('Try again'), findsOneWidget);
  });

  testWidgets('a blocked user shows the unblock shell instead of the profile', (tester) async {
    await pumpScreen(tester, identifier: 'u2');
    repository.profiles.add(_ana);
    await tester.pump(const Duration(milliseconds: 400));

    blocks.completeInitial(<String>{'u2'});
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.text('You blocked Ana Rivera'), findsOneWidget);
    expect(find.text('Unblock'), findsOneWidget);
    expect(find.text('Follow'), findsNothing);
  });

  testWidgets('an unknown block list keeps the profile loading until the list is known', (tester) async {
    blocks.emitUnknown();
    await pumpScreen(tester, identifier: 'u2');
    repository.profiles.add(_ana);
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.text('Ana Rivera'), findsNothing);
    expect(find.text('You blocked Ana Rivera'), findsNothing);
    expect(find.bySemanticsLabel('Loading'), findsWidgets);

    blocks.completeInitial(<String>{});
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.text('Ana Rivera'), findsOneWidget);
  });

  group('cosmetics, rank and gifts', () {
    const PublicProfileEntity dressed = PublicProfileEntity(
      id: 'u2',
      name: 'Ana Rivera',
      email: '',
      username: 'ana_rivera',
      profilePhoto: '',
      bio: '',
      links: <String, String>{},
      coverPhoto: '',
      frameId: 'frame_aurora',
      nameGlowId: 'glow_ember',
      xp: 600,
    );

    tearDown(() {
      CoinsService.instance.inventoryNotifier.value = Inventory.empty;
      CoinsService.instance.balanceNotifier.value = 0;
      CoinsService.instance.xpNotifier.value = XpStatus.empty();
    });

    testWidgets('own profile shows full lifetime XP progress and confirmed reward state', (tester) async {
      CoinsService.instance.xpNotifier.value = XpStatus.fromUserData(<String, dynamic>{'xp': 1240});
      CoinsService.instance.inventoryNotifier.value = const Inventory(owned: <String>{'glow_aurora'});
      await pumpScreen(tester);

      expect(find.byType(RankProgressCard), findsOneWidget);
      final AppLocalizationsEn l10n = AppLocalizationsEn();
      expect(find.textContaining(l10n.economyLifetimeXp('1,240')), findsOneWidget);
      expect(find.textContaining(l10n.economyXpToRank('760', l10n.economyRankGold)), findsOneWidget);
      expect(find.text(l10n.economyNextReward('Gold frame')), findsOneWidget);
      expect(find.byType(RankInfoChip), findsNothing);
    });

    testWidgets('another profile shows the rank tag, the frame and the glowing name', (tester) async {
      await pumpScreen(tester, identifier: 'u2');
      repository.profiles.add(dressed);
      await tester.pump(const Duration(milliseconds: 400));

      expect(find.text('Silver'), findsOneWidget);
      expect(find.byType(RankProgressCard), findsNothing);
      expect(find.byType(RankInfoChip), findsOneWidget);
      expect(find.byKey(ProfileFrame.ringKey), findsOneWidget);
      expect(find.ancestor(of: find.text('Ana Rivera'), matching: find.byType(ShaderMask)), findsOneWidget);

      await tester.tap(find.text('Silver'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.text('XP, ranks & rewards'), findsOneWidget);
    });

    testWidgets('a profile with no cosmetics keeps the plain ring and name', (tester) async {
      await pumpScreen(tester, identifier: 'u2');
      repository.profiles.add(_ana);
      await tester.pump(const Duration(milliseconds: 400));

      expect(find.text('Bronze'), findsOneWidget);
      expect(find.byKey(ProfileFrame.ringKey), findsNothing);
      expect(find.ancestor(of: find.text('Ana Rivera'), matching: find.byType(ShaderMask)), findsNothing);
    });

    testWidgets('a Pro frame draws only while the profile is premium', (tester) async {
      await pumpScreen(tester, identifier: 'u2');
      repository.profiles.add(
        const PublicProfileEntity(
          id: 'u2',
          name: 'Ana Rivera',
          email: '',
          username: 'ana_rivera',
          profilePhoto: '',
          bio: '',
          links: <String, String>{},
          coverPhoto: '',
          frameId: 'frame_prism',
        ),
      );
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.byKey(ProfileFrame.ringKey), findsNothing);

      repository.profiles.add(
        const PublicProfileEntity(
          id: 'u2',
          name: 'Ana Rivera',
          email: '',
          username: 'ana_rivera',
          profilePhoto: '',
          bio: '',
          links: <String, String>{},
          coverPhoto: '',
          frameId: 'frame_prism',
          premium: true,
        ),
      );
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.byKey(ProfileFrame.ringKey), findsOneWidget);
    });

    testWidgets('a profile with the Pro badge shows it above the badge row', (tester) async {
      await pumpScreen(tester, identifier: 'u2');
      repository.profiles.add(
        const PublicProfileEntity(
          id: 'u2',
          name: 'Ana Rivera',
          email: '',
          username: 'ana_rivera',
          profilePhoto: '',
          bio: '',
          links: <String, String>{},
          coverPhoto: '',
          proBadge: true,
        ),
      );
      await tester.pump(const Duration(milliseconds: 400));

      expect(find.byType(ProProfileBadge), findsOneWidget);
    });

    testWidgets('a profile without the Pro badge shows no badge', (tester) async {
      await pumpScreen(tester, identifier: 'u2');
      repository.profiles.add(
        const PublicProfileEntity(
          id: 'u2',
          name: 'Ana Rivera',
          email: '',
          username: 'ana_rivera',
          profilePhoto: '',
          bio: '',
          links: <String, String>{},
          coverPhoto: '',
        ),
      );
      await tester.pump(const Duration(milliseconds: 400));

      expect(find.byType(ProProfileBadge), findsNothing);
    });

    testWidgets('a Pro badge profile renders at 2x text without an exception', (tester) async {
      tester.view.physicalSize = const Size(800, 2400);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: const ProfileScreen(profileIdentifier: 'u2'),
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context).copyWith(textScaler: const TextScaler.linear(2)),
            child: favouriteTestBuilder(context, child),
          ),
        ),
      );
      repository.profiles.add(
        const PublicProfileEntity(
          id: 'u2',
          name: 'Ana Rivera',
          email: '',
          username: 'ana_rivera',
          profilePhoto: '',
          bio: '',
          links: <String, String>{},
          coverPhoto: '',
          proBadge: true,
        ),
      );
      await tester.pump(const Duration(milliseconds: 400));

      expect(find.byType(ProProfileBadge), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('own profile updates when a frame is equipped', (tester) async {
      await pumpScreen(tester);
      expect(find.byKey(ProfileFrame.ringKey), findsNothing);

      CoinsService.instance.inventoryNotifier.value = const Inventory(
        owned: <String>{'frame_ring'},
        frame: 'frame_ring',
      );
      await tester.pump();

      expect(find.byKey(ProfileFrame.ringKey), findsOneWidget);
      expect(find.byTooltip('Gift a 24 h pass'), findsNothing);
    });

    testWidgets('another profile offers the gift sheet', (tester) async {
      CoinsService.instance.balanceNotifier.value = 500;
      await pumpScreen(tester, identifier: 'u2');
      repository.profiles.add(_ana);
      await tester.pump(const Duration(milliseconds: 400));

      await tester.tap(find.byTooltip('Gift a 24 h pass'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      expect(find.text('Gift a 24-hour Pro pass'), findsOneWidget);
      expect(
        find.textContaining('Ana Rivera gets premium collections and premium walls until tomorrow.'),
        findsOneWidget,
      );
      expect(find.text('Send gift'), findsOneWidget);
      expect(find.text('Earn coins'), findsNothing);
    });

    testWidgets('the gift sheet offers Earn coins and blocks sending when the balance is short', (tester) async {
      CoinsService.instance.balanceNotifier.value = 0;
      await pumpScreen(tester, identifier: 'u2');
      repository.profiles.add(_ana);
      await tester.pump(const Duration(milliseconds: 400));

      await tester.tap(find.byTooltip('Gift a 24 h pass'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      expect(find.text('Earn coins'), findsOneWidget);
      final PrismButton send = tester.widget<PrismButton>(find.widgetWithText(PrismButton, 'Send gift'));
      expect(send.onPressed, isNull);
    });
  });
}
