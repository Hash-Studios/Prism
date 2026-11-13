import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:Prism/core/analytics/analytics_runtime.dart';
import 'package:Prism/core/constants/app_constants.dart' as app_constants;
import 'package:Prism/core/di/injection.dart';
import 'package:Prism/core/persistence/data_sources/settings_local_data_source.dart';
import 'package:Prism/core/router/app_router.dart';
import 'package:Prism/core/state/app_state.dart' as app_state;
import 'package:Prism/core/utils/result.dart';
import 'package:Prism/core/utils/status.dart';
import 'package:Prism/core/widgets/prism/prism_button.dart';
import 'package:Prism/features/public_profile/biz/bloc/public_profile_bloc.j.dart';
import 'package:Prism/features/public_profile/domain/entities/public_profile_entity.dart';
import 'package:Prism/features/public_profile/domain/entities/public_profile_wall_entity.dart';
import 'package:Prism/features/public_profile/domain/entities/user_relation_kind.dart';
import 'package:Prism/features/public_profile/domain/entities/user_summary_entity.dart';
import 'package:Prism/features/public_profile/domain/repositories/public_profile_repository.dart';
import 'package:Prism/features/public_profile/views/pages/profile_screen.dart';
import 'package:Prism/features/public_profile/views/widgets/gift_pass_sheet.dart';
import 'package:Prism/features/rewards/views/widgets/rank_progress_card.dart';
import 'package:Prism/features/user_blocks/domain/repositories/user_block_repository.dart';
import 'package:Prism/l10n/l10n.dart';
import 'package:Prism/theme/theme.dart';
import 'package:auto_route/auto_route.dart';
import 'package:bloc_test/bloc_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import '../../support/fake_app_analytics.dart';
import '../../support/fake_user_block_repository.dart';
import '../../support/favourite_test_scope.dart';
import '../../support/in_memory_local_store.dart';
import '../../support/profile_user_fixture.dart';
import '../creator_directory/creator_directory_test_support.dart';

// Issue #548: the profile screen must not overflow on a 320 logical-pixel phone at 2x text.

class _MockPublicProfileBloc extends MockBloc<PublicProfileEvent, PublicProfileState> implements PublicProfileBloc {}

class _SmallProfileRouter extends RootStackRouter {
  @override
  List<AutoRoute> get routes => <AutoRoute>[
    AutoRoute(
      path: '/',
      page: PageInfo('Landing', builder: (_) => const SizedBox()),
    ),
    AutoRoute(
      path: '/profile',
      page: PageInfo(ProfileRoute.name, builder: (_) => const ProfileScreen()),
    ),
    AutoRoute(
      path: '/following',
      page: PageInfo(FollowingListRoute.name, builder: (_) => const Scaffold(body: Text('Following destination'))),
    ),
    AutoRoute(
      path: '/followers',
      page: PageInfo(FollowersRoute.name, builder: (_) => const Scaffold(body: Text('Followers destination'))),
    ),
    AutoRoute(
      path: '/stats',
      page: PageInfo(CreatorStatsRoute.name, builder: (_) => const Scaffold(body: Text('Stats destination'))),
    ),
    AutoRoute(
      path: '/edit',
      page: PageInfo(EditProfilePanelRoute.name, builder: (_) => const Scaffold(body: Text('Edit destination'))),
    ),
  ];
}

class _FakeProfileRepository implements PublicProfileRepository {
  final StreamController<PublicProfileEntity?> profiles = StreamController<PublicProfileEntity?>.broadcast();
  final List<String> watchedIdentifiers = <String>[];

  @override
  Stream<PublicProfileEntity?> watchProfile(String identifier) {
    watchedIdentifiers.add(identifier);
    return profiles.stream;
  }

  @override
  Future<Result<List<String>>> fetchRelationIds({required String profileUid, required UserRelationKind kind}) =>
      throw UnimplementedError();

  @override
  Future<Result<RelationPage>> fetchRelationPage({
    required String profileUid,
    required UserRelationKind kind,
    RelationCursor? cursor,
  }) async => Result.success(const RelationPage(users: <UserSummaryEntity>[], next: null));

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

const String _longName = 'Maximiliana Alexandria Fernandez-Montgomery of the Northern Coastal Region';
const String _longUsername = 'maximiliana_alexandria_fernandez_montgomery_northern_coast_01';
const String _longBio = 'A long profile biography that should remain readable at larger text sizes.';
const Map<String, String> _fourLinks = <String, String>{
  'github': 'https://github.com/a',
  'twitter': 'https://twitter.com/a',
  'instagram': 'https://instagram.com/a',
  'telegram': 'https://t.me/a',
};

const PublicProfileEntity _longProfile = PublicProfileEntity(
  id: 'u2',
  name: _longName,
  email: '',
  username: _longUsername,
  profilePhoto: '',
  bio: _longBio,
  links: _fourLinks,
  coverPhoto: '',
);

void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    // Match the shipped label metrics. Ahem makes the Stats label cover the Back button at 2x text.
    final FontLoader fonts = FontLoader('Proxima Nova')..addFont(rootBundle.load('assets/fonts/Proxima Nova Bold.otf'));
    await fonts.load();
  });
  setUpFavouriteCounts();
  setUp(() => getIt.registerSingleton<SettingsLocalDataSource>(SettingsLocalDataSource(InMemoryLocalStore())));
  tearDown(() async {
    if (getIt.isRegistered<SettingsLocalDataSource>()) await getIt.unregister<SettingsLocalDataSource>();
  });
  late _MockPublicProfileBloc bloc;
  late _FakeProfileRepository repository;
  late FakeUserBlockRepository blocks;
  void Function(FlutterErrorDetails)? savedOnError;

  setUp(() {
    savedOnError = FlutterError.onError;
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
    FlutterError.onError = savedOnError;
    app_state.prismUser = app_constants.createGuestPrismUser();
    AnalyticsRuntime.reset();
    await repository.profiles.close();
    await getIt.reset();
  });

  // Pumps ProfileScreen on a 320 x 568 logical-pixel surface at 2x text scale.
  Future<void> pumpSmallScreen(WidgetTester tester, {required bool isDark, String? identifier}) async {
    tester.view.physicalSize = const Size(640, 1136);
    tester.view.devicePixelRatio = 2.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        theme: isDark ? kDarkTheme : kLightTheme,
        home: ProfileScreen(profileIdentifier: identifier),
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(textScaler: const TextScaler.linear(2.0)),
          child: favouriteTestBuilder(context, child),
        ),
      ),
    );
    // Glint and skeletons loop, so pump a bounded time instead of settling.
    await tester.pump(const Duration(milliseconds: 400));
  }

  // Records every FlutterError, and still forwards it so tester.takeException() keeps working.
  List<String> captureFlutterErrors() {
    final List<String> messages = <String>[];
    final void Function(FlutterErrorDetails)? previous = FlutterError.onError;
    FlutterError.onError = (FlutterErrorDetails details) {
      messages.add(details.toString());
      previous?.call(details);
    };
    return messages;
  }

  void expectNoOverflow(List<String> errors) {
    final List<String> overflows = errors.where((String message) => message.contains('overflowed')).toList();
    expect(overflows, isEmpty, reason: overflows.join('\n---\n'));
  }

  for (final bool isDark in <bool>[false, true]) {
    final String themeName = isDark ? 'dark' : 'light';

    testWidgets('another profile with 4 links, long name and long username fits 320 wide at 2x text, $themeName', (
      tester,
    ) async {
      whenListen(
        bloc,
        const Stream<PublicProfileState>.empty(),
        initialState: PublicProfileState.initial().copyWith(profileId: 'u2', status: LoadStatus.success),
      );
      final List<String> errors = captureFlutterErrors();

      await pumpSmallScreen(tester, isDark: isDark, identifier: 'u2');
      repository.profiles.add(_longProfile);
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pump(const Duration(milliseconds: 500));

      expect(find.text(_longName), findsWidgets);
      expect(find.byIcon(Icons.card_giftcard_rounded), findsOneWidget);
      expect(find.byIcon(Icons.person_add_alt_1_rounded), findsOneWidget);
      expect(find.byWidgetPredicate((Widget widget) => widget is PopupMenuButton), findsOneWidget);
      final Finder follow = find.widgetWithText(PrismButton, 'Follow');
      await tester.ensureVisible(follow);
      await tester.pump();
      for (final Finder target in <Finder>[
        find.byTooltip('Back'),
        find.byTooltip('Gift a 24 h pass'),
        follow,
        find.byTooltip('More options'),
      ]) {
        expect(target.hitTestable(), findsOneWidget, reason: 'must stay tappable: $target');
        final Rect rect = tester.getRect(target);
        expect(rect.left, greaterThanOrEqualTo(0));
        expect(rect.right, lessThanOrEqualTo(320));
      }
      final RenderParagraph followLabel = tester.renderObject(find.text('Follow'));
      expect(followLabel.didExceedMaxLines, isFalse);
      await tester.tap(follow);
      verify(
        () => bloc.add(
          const PublicProfileEvent.followChangeRequested(
            follow: true,
            currentUserId: 'me',
            currentUserEmail: 'user@example.com',
            targetUserId: 'u2',
            targetUserEmail: '',
            targetName: _longName,
          ),
        ),
      ).called(1);
      await tester.tap(find.byTooltip('Gift a 24 h pass'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      final GiftPassSheet gift = tester.widget(find.byType(GiftPassSheet));
      expect(gift.recipientUid, 'u2');
      expect(gift.recipientName, _longName);
      Navigator.of(tester.element(find.byType(GiftPassSheet))).pop();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      await tester.tap(find.byTooltip('More options'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.text('Report user').hitTestable(), findsOneWidget);
      expect(find.text('Block user').hitTestable(), findsOneWidget);
      expect(tester.takeException(), isNull);
      expectNoOverflow(errors);
    });

    testWidgets('own profile with 4 links, long name and long username fits 320 wide at 2x text, $themeName', (
      tester,
    ) async {
      app_state.prismUser = profileUser(id: 'me', username: _longUsername, bio: _longBio, links: _fourLinks)
        ..name = _longName;
      final List<String> errors = captureFlutterErrors();

      await pumpSmallScreen(tester, isDark: isDark);
      await tester.pump(const Duration(milliseconds: 500));

      expect(find.text(_longName), findsWidgets);
      expect(find.byIcon(Icons.edit_rounded), findsOneWidget);
      for (final String tooltip in <String>['Edit profile', 'Stats', 'Menu']) {
        final Finder target = find.byTooltip(tooltip);
        expect(target.hitTestable(), findsOneWidget, reason: 'must stay tappable: $tooltip');
        final Rect rect = tester.getRect(target);
        expect(rect.left, greaterThanOrEqualTo(0));
        expect(rect.right, lessThanOrEqualTo(320));
      }
      expect(tester.takeException(), isNull);
      expectNoOverflow(errors);
    });
  }

  // Issue #548: at 360 points and 2x text the stats row gave each item a third of the width and broke words in half.
  for (final double width in <double>[320, 360, 412]) {
    for (final double scale in <double>[1, 2, 3]) {
      for (final bool dark in <bool>[false, true]) {
        for (final TextDirection direction in TextDirection.values) {
          testWidgets('stats keep every word on one line at $width points and ${scale}x text $dark $direction', (
            tester,
          ) async {
            whenListen(
              bloc,
              const Stream<PublicProfileState>.empty(),
              initialState: PublicProfileState.initial().copyWith(profileId: 'u2', status: LoadStatus.success),
            );
            tester.view.physicalSize = Size(width * 2, 1600);
            tester.view.devicePixelRatio = 2;
            addTearDown(tester.view.reset);
            await tester.pumpWidget(
              MaterialApp(
                localizationsDelegates: AppLocalizations.localizationsDelegates,
                supportedLocales: AppLocalizations.supportedLocales,
                theme: dark ? kDarkTheme : kLightTheme,
                home: const ProfileScreen(profileIdentifier: 'u2'),
                builder: (context, child) => MediaQuery(
                  data: MediaQuery.of(context).copyWith(textScaler: TextScaler.linear(scale)),
                  child: Directionality(textDirection: direction, child: favouriteTestBuilder(context, child)),
                ),
              ),
            );
            repository.profiles.add(
              const PublicProfileEntity(
                id: 'u2',
                name: 'Akshay Maurya',
                email: '',
                username: 'codenameakshay',
                profilePhoto: '',
                bio: '',
                links: <String, String>{},
                coverPhoto: '',
                followerCount: 6930,
                followingCount: 23,
                xp: 5000,
              ),
            );
            await tester.pump(const Duration(milliseconds: 400));
            await tester.pump(const Duration(milliseconds: 500));

            final List<Finder> stats = <Finder>[
              find.textContaining('Following', findRichText: true),
              find.textContaining('Followers', findRichText: true),
              find.descendant(of: find.byType(RankInfoChip), matching: find.byType(RichText)),
            ];
            for (final Finder stat in stats) {
              expect(stat, findsOneWidget);
              final RenderParagraph paragraph = tester.renderObject(stat);
              final String text = paragraph.text.toPlainText();
              for (final RegExpMatch word in RegExp(r'\S+').allMatches(text)) {
                final List<TextBox> boxes = paragraph.getBoxesForSelection(
                  TextSelection(baseOffset: word.start, extentOffset: word.end),
                );
                expect(boxes.map((TextBox box) => box.top).toSet(), hasLength(1), reason: '"${word[0]}" in "$text"');
              }
              final Rect rect = tester.getRect(stat);
              expect(rect.left, greaterThanOrEqualTo(0));
              expect(rect.right, lessThanOrEqualTo(width));
            }
            final Rect following = tester.getRect(stats[0]);
            final Rect followers = tester.getRect(stats[1]);
            final Rect rank = tester.getRect(stats[2]);
            if (scale == 1 && width >= 360) {
              expect(following.center.dy, closeTo(followers.center.dy, 1));
              expect(followers.center.dy, closeTo(rank.center.dy, 1));
              expect(
                direction == TextDirection.ltr ? following.right < followers.left : followers.right < following.left,
                isTrue,
              );
            } else {
              expect(following.bottom, lessThan(followers.top));
              expect(followers.bottom, lessThan(rank.top));
              expect(following.center.dx, closeTo(width / 2, 1));
              expect(followers.center.dx, closeTo(width / 2, 1));
              expect(rank.center.dx, closeTo(width / 2, 1));
            }
            expect(find.byType(RankInfoChip).hitTestable(), findsOneWidget);
            if (width == 320 && scale == 3 && dark) {
              await tester.tap(find.byType(RankInfoChip));
              await tester.pump();
              await tester.pump(const Duration(milliseconds: 500));
              expect(find.byType(XpExplanationSheet), findsOneWidget);
            }

            expect(tester.takeException(), isNull);
          });
        }
      }
    }
  }

  for (final TextDirection direction in TextDirection.values) {
    testWidgets('stacked own counts retain tap targets at 320 and 3x $direction', (tester) async {
      final SemanticsHandle semantics = tester.ensureSemantics();
      final _SmallProfileRouter router = _SmallProfileRouter();
      try {
        tester.view.physicalSize = const Size(640, 2000);
        tester.view.devicePixelRatio = 2;
        addTearDown(tester.view.reset);
        await tester.pumpWidget(
          MaterialApp.router(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            theme: kDarkTheme,
            routerConfig: router.config(),
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(context).copyWith(textScaler: const TextScaler.linear(3)),
              child: Directionality(textDirection: direction, child: favouriteTestBuilder(context, child)),
            ),
          ),
        );
        unawaited(router.push(ProfileRoute()));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 500));
        final List<String> labels = <String>[];
        void collectLabels(SemanticsNode node) {
          labels.add(node.label);
          for (final SemanticsNode child in node.debugListChildrenInOrder(DebugSemanticsDumpOrder.traversalOrder)) {
            collectLabels(child);
          }
        }

        collectLabels(tester.getSemantics(find.byType(ProfileScreen)));
        expect(labels.indexOf('0 Following'), greaterThanOrEqualTo(0));
        expect(labels.indexOf('0 Following'), lessThan(labels.indexOf('0 Followers')));
        for (final String label in <String>['Following', 'Followers']) {
          expect(
            tester.getSemantics(find.bySemanticsLabel('0 $label')),
            matchesSemantics(label: '0 $label', isButton: true, hasTapAction: true),
          );
          await tester.tap(find.textContaining(label, findRichText: true));
          await tester.pump();
          await tester.pump(const Duration(milliseconds: 700));
          expect(find.text('$label destination'), findsOneWidget);
          router.pop();
          await tester.pump();
          await tester.pump(const Duration(milliseconds: 700));
        }
        expect(tester.takeException(), isNull);
      } finally {
        await tester.pumpWidget(const SizedBox());
        router.dispose();
        semantics.dispose();
      }
    });
  }

  testWidgets('an individually oversized stat wraps within its available width', (tester) async {
    await pumpSmallScreen(tester, isDark: false);
    final Widget line = tester.widget(
      find.byWidgetPredicate((widget) => widget.runtimeType.toString() == '_StatsLine'),
    );
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        theme: kLightTheme,
        home: Center(child: SizedBox(width: 80, child: line)),
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(textScaler: const TextScaler.linear(3)),
          child: child!,
        ),
      ),
    );
    final RenderParagraph following = tester.renderObject(find.textContaining('Following', findRichText: true));
    final String text = following.text.toPlainText();
    final int start = text.indexOf('Following');
    final List<TextBox> boxes = following.getBoxesForSelection(
      TextSelection(baseOffset: start, extentOffset: text.length),
    );
    expect(boxes.map((box) => box.top).toSet().length, greaterThan(1));
    expect(following.size.width, lessThanOrEqualTo(80));
    expect(tester.takeException(), isNull);
  });

  testWidgets('stats follow the reading order right to left', (tester) async {
    whenListen(
      bloc,
      const Stream<PublicProfileState>.empty(),
      initialState: PublicProfileState.initial().copyWith(profileId: 'u2', status: LoadStatus.success),
    );
    tester.view.physicalSize = const Size(824, 1600);
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        theme: kLightTheme,
        home: const ProfileScreen(profileIdentifier: 'u2'),
        builder: (context, child) =>
            Directionality(textDirection: TextDirection.rtl, child: favouriteTestBuilder(context, child)),
      ),
    );
    repository.profiles.add(_longProfile);
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pump(const Duration(milliseconds: 500));

    final Rect following = tester.getRect(find.textContaining('Following', findRichText: true));
    final Rect followers = tester.getRect(find.textContaining('Followers', findRichText: true));
    final Rect rank = tester.getRect(find.byType(RankInfoChip));
    expect(following.left, greaterThan(followers.right));
    expect(followers.left, greaterThan(rank.right));
    expect(following.center.dy, closeTo(followers.center.dy, 1));
    expect(tester.takeException(), isNull);
  });

  // Issue #558: where the accent ring meets the photo, a pixel may only mix the ring and the photo colours.
  for (final bool isDark in <bool>[false, true]) {
    testWidgets('header avatar ring meets the photo with no third colour, ${isDark ? 'dark' : 'light'}', (
      tester,
    ) async {
      app_state.prismUser = profileUser(id: 'me', profilePhoto: '');
      final GlobalKey boundaryKey = GlobalKey();
      tester.view.physicalSize = const Size(780, 1688);
      tester.view.devicePixelRatio = 2;
      addTearDown(tester.view.reset);
      final ThemeData theme = isDark ? kDarkTheme : kLightTheme;
      await tester.pumpWidget(
        RepaintBoundary(
          key: boundaryKey,
          child: MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            theme: theme,
            home: const ProfileScreen(),
            builder: favouriteTestBuilder,
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 500));

      final Offset centre = tester.getCenter(find.byKey(const ValueKey<String>('profile-carried-avatar')));
      final RenderRepaintBoundary boundary = tester.renderObject(find.byKey(boundaryKey));
      final ByteData bytes = (await tester.runAsync<ByteData?>(() async {
        final ui.Image image = await boundary.toImage(pixelRatio: 2);
        final ByteData? data = await image.toByteData();
        image.dispose();
        return data;
      }))!;
      final int width = (boundary.size.width * 2).round();
      final ColorScheme cs = theme.colorScheme;
      // The photo is the default person tile, cs.surface. The ring is cs.primary.
      final List<Color> allowed = <Color>[cs.primary, cs.surface];
      double channel(Color c, int i) => <double>[c.r, c.g, c.b][i];
      final List<String> stray = <String>[];
      for (int step = 0; step < 72; step++) {
        final double angle = step * math.pi / 36;
        for (double radius = 37; radius <= 41; radius += 0.5) {
          final int x = ((centre.dx + radius * math.cos(angle)) * 2).round();
          final int y = ((centre.dy + radius * math.sin(angle)) * 2).round();
          final int offset = (y * width + x) * 4;
          final List<double> pixel = <double>[for (int i = 0; i < 3; i++) bytes.getUint8(offset + i) / 255];
          for (int i = 0; i < 3; i++) {
            final double low = allowed.map((Color c) => channel(c, i)).reduce(math.min) - 0.04;
            final double high = allowed.map((Color c) => channel(c, i)).reduce(math.max) + 0.04;
            if (pixel[i] < low || pixel[i] > high) {
              stray.add('r=$radius angle=$step rgb=$pixel');
              break;
            }
          }
        }
      }
      expect(stray, isEmpty, reason: stray.take(5).join('\n'));
    });
  }

  testWidgets('pushed owner app bar keeps back, stats, edit and menu usable at 320 points and 2x text', (tester) async {
    final _SmallProfileRouter router = _SmallProfileRouter();
    tester.view.physicalSize = const Size(320, 568);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp.router(
        routerConfig: router.config(),
        theme: kLightTheme,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(textScaler: const TextScaler.linear(2)),
          child: favouriteTestBuilder(context, child),
        ),
      ),
    );
    await tester.pump();
    unawaited(router.push(ProfileRoute()));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    for (final Finder target in <Finder>[
      find.byTooltip('Back'),
      find.byTooltip('Stats'),
      find.byTooltip('Edit profile'),
      find.byTooltip('Menu'),
    ]) {
      expect(target.hitTestable(), findsOneWidget, reason: 'App-bar control must remain tappable: $target');
      final Rect rect = tester.getRect(target);
      expect(rect.left, greaterThanOrEqualTo(0));
      expect(rect.right, lessThanOrEqualTo(320));
    }
    await tester.tap(find.byTooltip('Stats'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.text('Stats destination'), findsOneWidget);
    router.pop();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    await tester.tap(find.byTooltip('Edit profile'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.text('Edit destination'), findsOneWidget);
    router.pop();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    await tester.tap(find.byTooltip('Menu'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.text('Library').hitTestable(), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
    router.dispose();
  });
}
