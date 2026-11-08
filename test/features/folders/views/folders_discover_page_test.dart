import 'package:Prism/core/analytics/analytics_runtime.dart';
import 'package:Prism/core/constants/app_constants.dart' as app_constants;
import 'package:Prism/core/di/injection.dart';
import 'package:Prism/core/firestore/firestore_client.dart';
import 'package:Prism/core/state/app_state.dart' as app_state;
import 'package:Prism/core/utils/result.dart';
import 'package:Prism/features/favourite_walls/domain/entities/favourite_wall_entity.dart';
import 'package:Prism/features/favourite_walls/domain/repositories/favourite_walls_repository.dart';
import 'package:Prism/features/folders/biz/folder_discover_cubit.dart';
import 'package:Prism/features/folders/domain/entities/discover_folder.dart';
import 'package:Prism/features/folders/domain/repositories/public_folders_repository.dart';
import 'package:Prism/features/folders/domain/section_suggester.dart';
import 'package:Prism/features/folders/views/pages/folders_discover_page.dart';
import 'package:Prism/l10n/l10n.dart';
import 'package:Prism/theme/theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../support/fake_app_analytics.dart';
import '../../../support/fake_user_block_repository.dart';

class _FakePublicFolders extends Fake implements PublicFoldersRepository {
  FolderDiscoverLists discover = FolderDiscoverLists.empty;
  final List<({String id, bool following})> followCalls = <({String id, bool following})>[];

  @override
  Future<Result<FolderDiscoverLists>> fetchDiscover() async => Result.success(discover);

  @override
  Future<Result<Set<String>>> fetchFollowedIds(String userId) async => Result.success(<String>{});

  @override
  Future<void> recordSignal(String folderId, FolderSignal signal) async {}

  @override
  Future<Result<void>> setFollowing(String folderId, {required bool following}) async {
    followCalls.add((id: folderId, following: following));
    return Result.success<void>(null);
  }
}

class _FakeFavourites extends Fake implements FavouriteWallsRepository {
  @override
  Future<Result<List<FavouriteWallEntity>>> fetchFavourites({required String userId}) async =>
      Result.success(<FavouriteWallEntity>[]);
}

class _FakeFirestore extends Fake implements FirestoreClient {}

const DiscoverFolder _trendingFolder = DiscoverFolder(
  id: 'trend-1',
  ownerId: 'owner-a',
  name: 'Ocean Walls',
  itemCount: 12,
  ownerName: 'Ana',
);

const DiscoverFolder _newFolder = DiscoverFolder(
  id: 'new-1',
  ownerId: 'owner-b',
  name: 'Fresh Finds',
  itemCount: 9,
  ownerName: 'Ben',
);

Future<void> _pumpPage(WidgetTester tester, {double textScale = 1}) async {
  await tester.pumpWidget(
    MaterialApp(
      theme: kLightTheme,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(textScaler: TextScaler.linear(textScale)),
        child: child!,
      ),
      home: const FoldersDiscoverPage(),
    ),
  );
  // The page loads from the fake repository. Pump fixed frames rather than settle.
  for (int i = 0; i < 5; i++) {
    await tester.pump(const Duration(milliseconds: 50));
  }
}

void main() {
  late _FakePublicFolders folders;
  late FakeAppAnalytics analytics;

  void registerCubit({FolderDiscoverLists? discover, bool signedIn = true}) {
    folders.discover = discover ?? FolderDiscoverLists.empty;
    app_state.prismUser = app_constants.createGuestPrismUser()
      ..id = 'me'
      ..loggedIn = signedIn;
    final FolderDiscoverCubit cubit = FolderDiscoverCubit(
      folders,
      _FakeFavourites(),
      FakeUserBlockRepository.pending()..completeInitial(<String>{}),
      _FakeFirestore(),
      saveTraits: (_) async => <WallTraits>[],
    );
    getIt.registerFactory<FolderDiscoverCubit>(() => cubit);
  }

  setUp(() {
    folders = _FakePublicFolders();
    analytics = FakeAppAnalytics();
    AnalyticsRuntime.instance = analytics;
  });

  tearDown(() async {
    AnalyticsRuntime.reset();
    app_state.prismUser = app_constants.createGuestPrismUser();
    await getIt.reset();
  });

  testWidgets('shows the three tabs and the trending folder with its owner and wall count', (tester) async {
    registerCubit(discover: const FolderDiscoverLists(trending: <DiscoverFolder>[_trendingFolder]));

    await _pumpPage(tester);

    expect(find.text('Trending'), findsOneWidget);
    expect(find.text('New'), findsOneWidget);
    expect(find.text('Like your saves'), findsOneWidget);
    expect(find.text('Ocean Walls'), findsOneWidget);
    expect(find.text('By Ana'), findsOneWidget);
    expect(find.text('12 wallpapers'), findsOneWidget);
  });

  testWidgets('tapping New shows the new folders', (tester) async {
    registerCubit(
      discover: const FolderDiscoverLists(
        trending: <DiscoverFolder>[_trendingFolder],
        fresh: <DiscoverFolder>[_newFolder],
      ),
    );
    await _pumpPage(tester);

    await tester.tap(find.text('New'));
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('Fresh Finds'), findsOneWidget);
    expect(find.text('Ocean Walls'), findsNothing);
  });

  testWidgets('an empty New tab shows the empty state', (tester) async {
    registerCubit(discover: const FolderDiscoverLists(trending: <DiscoverFolder>[_trendingFolder]));
    await _pumpPage(tester);

    await tester.tap(find.text('New'));
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('No new folders this week'), findsOneWidget);
  });

  testWidgets('an empty Trending tab shows the empty state', (tester) async {
    registerCubit();
    await _pumpPage(tester);

    expect(find.text('No trending folders yet'), findsOneWidget);
  });

  testWidgets('Like your saves with no matching saves shows the empty state', (tester) async {
    registerCubit(discover: const FolderDiscoverLists(trending: <DiscoverFolder>[_trendingFolder]));
    await _pumpPage(tester);

    await tester.tap(find.text('Like your saves'));
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('Nothing like your saves yet'), findsOneWidget);
  });

  testWidgets('tapping Follow calls setFollowing and the button then reads Following', (tester) async {
    registerCubit(discover: const FolderDiscoverLists(trending: <DiscoverFolder>[_trendingFolder]));
    await _pumpPage(tester);

    await tester.tap(find.text('Follow'));
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pump(const Duration(milliseconds: 100));

    expect(folders.followCalls, <({String id, bool following})>[(id: 'trend-1', following: true)]);
    expect(find.text('Following'), findsOneWidget);
  });

  testWidgets('the card menu shows Report folder without submitting a report', (tester) async {
    registerCubit(discover: const FolderDiscoverLists(trending: <DiscoverFolder>[_trendingFolder]));
    await _pumpPage(tester);

    await tester.tap(find.byTooltip('More options'));
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('Report folder'), findsOneWidget);
  });

  testWidgets('large text keeps the card without overflow', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    registerCubit(discover: const FolderDiscoverLists(trending: <DiscoverFolder>[_trendingFolder]));

    await _pumpPage(tester, textScale: 2);

    expect(tester.takeException(), isNull);
    expect(find.text('Ocean Walls'), findsOneWidget);
    // The menu moves under Follow, so "Following" keeps the whole card width.
    final Rect follow = tester.getRect(find.text('Follow'));
    final Rect menu = tester.getRect(find.byIcon(Icons.more_horiz_rounded));
    expect(menu.top, greaterThan(follow.bottom));
  });

  testWidgets('the Follow button has a semantics label with the folder name', (tester) async {
    final SemanticsHandle handle = tester.ensureSemantics();
    registerCubit(discover: const FolderDiscoverLists(trending: <DiscoverFolder>[_trendingFolder]));
    await _pumpPage(tester);

    expect(find.bySemanticsLabel('Follow Ocean Walls'), findsOneWidget);

    handle.dispose();
  });
}
