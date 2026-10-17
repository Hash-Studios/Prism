import 'dart:async';

import 'package:Prism/core/analytics/analytics_runtime.dart';
import 'package:Prism/core/coins/coins_service.dart';
import 'package:Prism/core/di/injection.dart';
import 'package:Prism/core/router/app_router.dart';
import 'package:Prism/core/state/app_state.dart' as app_state;
import 'package:Prism/core/utils/result.dart';
import 'package:Prism/core/utils/status.dart';
import 'package:Prism/core/widgets/cosmetics/profile_frame.dart';
import 'package:Prism/core/widgets/prism/prism_ui.dart';
import 'package:Prism/features/public_profile/biz/bloc/public_profile_bloc.j.dart';
import 'package:Prism/features/public_profile/domain/entities/public_profile_entity.dart';
import 'package:Prism/features/public_profile/domain/entities/public_profile_wall_entity.dart';
import 'package:Prism/features/public_profile/domain/entities/user_summary_entity.dart';
import 'package:Prism/features/public_profile/domain/repositories/public_profile_repository.dart';
import 'package:Prism/features/public_profile/views/pages/profile_screen.dart';
import 'package:Prism/features/user_blocks/domain/repositories/user_block_repository.dart';
import 'package:Prism/theme/jam_icons_icons.dart';
import 'package:auto_route/auto_route.dart';
import 'package:bloc_test/bloc_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import '../../support/fake_app_analytics.dart';
import '../../support/fake_user_block_repository.dart';
import '../../support/profile_user_fixture.dart';

class _MockPublicProfileBloc extends MockBloc<PublicProfileEvent, PublicProfileState> implements PublicProfileBloc {}

class _FakeProfileRepository implements PublicProfileRepository {
  final StreamController<PublicProfileEntity?> profiles = StreamController<PublicProfileEntity?>.broadcast();

  @override
  Stream<PublicProfileEntity?> watchProfile(String identifier) => profiles.stream;

  @override
  Future<Result<({List<PublicProfileWallEntity> items, bool hasMore})>> fetchWalls({
    required String email,
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
    required List<String> allEmails,
    required int page,
  }) => throw UnimplementedError();

  @override
  Future<Result<List<UserSummaryEntity>>> searchUsersByUsername({
    required String query,
    required List<String> scopeEmails,
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
  email: 'ana@example.com',
  username: 'ana_rivera',
  profilePhoto: '',
  bio: 'Makes calm gradients.',
  followers: <String>[],
  following: <String>[],
  links: <String, String>{},
  coverPhoto: '',
);

void main() {
  late _MockPublicProfileBloc bloc;
  late _FakeProfileRepository repository;
  late FakeUserBlockRepository blocks;

  setUp(() {
    bloc = _MockPublicProfileBloc();
    repository = _FakeProfileRepository();
    blocks = FakeUserBlockRepository.pending();
    AnalyticsRuntime.instance = FakeAppAnalytics();
    getIt
      ..registerFactory<PublicProfileBloc>(() => bloc)
      ..registerSingleton<PublicProfileRepository>(repository)
      ..registerSingleton<UserBlockRepository>(blocks);
    app_state.prismUser = profileUser(id: 'me', username: 'creator_01', bio: 'Hello', premium: true)
      ..name = 'Me Myself';
    whenListen(
      bloc,
      const Stream<PublicProfileState>.empty(),
      initialState: PublicProfileState.initial().copyWith(email: 'user@example.com', status: LoadStatus.success),
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
    await tester.pumpWidget(MaterialApp(home: ProfileScreen(profileIdentifier: identifier)));
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
    expect(find.byIcon(JamIcons.pencil), findsOneWidget);
    expect(find.byIcon(JamIcons.menu), findsOneWidget);
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
    expect(find.text('Upload your first wallpaper to start your gallery.'), findsOneWidget);
  });

  testWidgets('tappable profile counts expose button semantics', (tester) async {
    final SemanticsHandle semantics = tester.ensureSemantics();
    try {
      final _ProfileSemanticsRouter router = _ProfileSemanticsRouter();
      tester.view.physicalSize = const Size(800, 2400);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(MaterialApp.router(routerConfig: router.config()));
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
        email: 'user@example.com',
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
    await tester.pumpWidget(const MaterialApp(home: ProfileScreen()));
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

    await tester.pumpWidget(const MaterialApp(home: ProfileScreen()));
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
      email: 'ana@example.com',
      username: 'a_very_long_profile_username_for_a_narrow_screen',
      profilePhoto: '',
      bio: 'A long profile biography that should remain readable at larger text sizes.',
      followers: <String>[],
      following: <String>[],
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
      initialState: PublicProfileState.initial().copyWith(email: 'ana@example.com', status: LoadStatus.success),
    );

    await tester.pumpWidget(const MaterialApp(home: ProfileScreen(profileIdentifier: 'ana@example.com')));
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
    await pumpScreen(tester, identifier: 'ana@example.com');
    expect(find.bySemanticsLabel('Loading'), findsWidgets);
    expect(find.text('Ana Rivera'), findsNothing);

    repository.profiles.add(_ana);
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.text('Ana Rivera'), findsOneWidget);
    expect(find.byIcon(JamIcons.user_plus), findsOneWidget);
    expect(find.byTooltip('Follow'), findsOneWidget);
    expect(find.byTooltip('More options'), findsOneWidget);
    expect(find.byTooltip('Edit profile'), findsNothing);
    expect(find.text('Upload your first wallpaper to start your gallery.'), findsNothing);
  });

  testWidgets('the Follow button asks the bloc to follow, and shows Unfollow when already followed', (tester) async {
    await pumpScreen(tester, identifier: 'ana@example.com');
    repository.profiles.add(_ana);
    await tester.pump(const Duration(milliseconds: 400));

    await tester.tap(find.byTooltip('Follow'));
    verify(
      () => bloc.add(
        const PublicProfileEvent.followChangeRequested(
          follow: true,
          currentUserId: 'me',
          currentUserEmail: 'user@example.com',
          targetUserId: 'u2',
          targetUserEmail: 'ana@example.com',
          targetName: 'Ana Rivera',
        ),
      ),
    ).called(1);

    whenListen(
      bloc,
      const Stream<PublicProfileState>.empty(),
      initialState: PublicProfileState.initial().copyWith(
        email: 'ana@example.com',
        status: LoadStatus.success,
        followOverrides: <String, bool>{'ana@example.com': true},
      ),
    );
    await tester.pumpWidget(const SizedBox.shrink());
    await pumpScreen(tester, identifier: 'ana@example.com');
    repository.profiles.add(_ana);
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.byTooltip('Unfollow'), findsOneWidget);
    expect(find.byIcon(JamIcons.user_remove), findsOneWidget);
  });

  testWidgets('the first three links show as buttons and the rest open from a More links button', (tester) async {
    await pumpScreen(tester, identifier: 'ana@example.com');
    repository.profiles.add(
      const PublicProfileEntity(
        id: 'u2',
        name: 'Ana Rivera',
        email: 'ana@example.com',
        username: 'ana_rivera',
        profilePhoto: '',
        bio: '',
        followers: <String>[],
        following: <String>[],
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
    await tester.pump(const Duration(milliseconds: 500));

    expect(find.text('More links'), findsOneWidget);
    expect(find.byTooltip('Telegram'), findsOneWidget);
  });

  testWidgets('another profile that has been deleted says it is not available', (tester) async {
    await pumpScreen(tester, identifier: 'ana@example.com');

    repository.profiles.add(null);
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.text('Profile not available'), findsOneWidget);
    expect(find.byTooltip('Back'), findsOneWidget);
  });

  testWidgets('a failed profile stream shows an error with a retry', (tester) async {
    await pumpScreen(tester, identifier: 'ana@example.com');

    repository.profiles.addError(StateError('boom'));
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.text('Could not load this profile'), findsOneWidget);
    expect(find.text('Try again'), findsOneWidget);
  });

  testWidgets('a blocked user shows the unblock shell instead of the profile', (tester) async {
    await pumpScreen(tester, identifier: 'ana@example.com');
    repository.profiles.add(_ana);
    await tester.pump(const Duration(milliseconds: 400));

    blocks.completeInitial(<String>{'ana@example.com'});
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.text('You blocked Ana Rivera'), findsOneWidget);
    expect(find.text('Unblock'), findsOneWidget);
    expect(find.text('Follow'), findsNothing);
  });

  group('cosmetics, rank and gifts', () {
    const PublicProfileEntity dressed = PublicProfileEntity(
      id: 'u2',
      name: 'Ana Rivera',
      email: 'ana@example.com',
      username: 'ana_rivera',
      profilePhoto: '',
      bio: '',
      followers: <String>[],
      following: <String>[],
      links: <String, String>{},
      coverPhoto: '',
      frameId: 'frame_aurora',
      nameGlowId: 'glow_ember',
      xp: 600,
    );

    tearDown(() {
      CoinsService.instance.inventoryNotifier.value = Inventory.empty;
      CoinsService.instance.balanceNotifier.value = 0;
    });

    testWidgets('another profile shows the rank tag, the frame and the glowing name', (tester) async {
      await pumpScreen(tester, identifier: 'ana@example.com');
      repository.profiles.add(dressed);
      await tester.pump(const Duration(milliseconds: 400));

      expect(find.text('Silver'), findsOneWidget);
      expect(find.byKey(ProfileFrame.ringKey), findsOneWidget);
      expect(find.ancestor(of: find.text('Ana Rivera'), matching: find.byType(ShaderMask)), findsOneWidget);
    });

    testWidgets('a profile with no cosmetics keeps the plain ring and name', (tester) async {
      await pumpScreen(tester, identifier: 'ana@example.com');
      repository.profiles.add(_ana);
      await tester.pump(const Duration(milliseconds: 400));

      expect(find.text('Bronze'), findsOneWidget);
      expect(find.byKey(ProfileFrame.ringKey), findsNothing);
      expect(find.ancestor(of: find.text('Ana Rivera'), matching: find.byType(ShaderMask)), findsNothing);
    });

    testWidgets('a Pro frame draws only while the profile is premium', (tester) async {
      await pumpScreen(tester, identifier: 'ana@example.com');
      repository.profiles.add(
        const PublicProfileEntity(
          id: 'u2',
          name: 'Ana Rivera',
          email: 'ana@example.com',
          username: 'ana_rivera',
          profilePhoto: '',
          bio: '',
          followers: <String>[],
          following: <String>[],
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
          email: 'ana@example.com',
          username: 'ana_rivera',
          profilePhoto: '',
          bio: '',
          followers: <String>[],
          following: <String>[],
          links: <String, String>{},
          coverPhoto: '',
          frameId: 'frame_prism',
          premium: true,
        ),
      );
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.byKey(ProfileFrame.ringKey), findsOneWidget);
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
      await pumpScreen(tester, identifier: 'ana@example.com');
      repository.profiles.add(_ana);
      await tester.pump(const Duration(milliseconds: 400));

      await tester.tap(find.byTooltip('Gift a 24 h pass'));
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
      await pumpScreen(tester, identifier: 'ana@example.com');
      repository.profiles.add(_ana);
      await tester.pump(const Duration(milliseconds: 400));

      await tester.tap(find.byTooltip('Gift a 24 h pass'));
      await tester.pump(const Duration(milliseconds: 500));

      expect(find.text('Earn coins'), findsOneWidget);
      final PrismButton send = tester.widget<PrismButton>(find.widgetWithText(PrismButton, 'Send gift'));
      expect(send.onPressed, isNull);
    });
  });
}
