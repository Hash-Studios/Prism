import 'dart:async';

import 'package:Prism/core/analytics/analytics_runtime.dart';
import 'package:Prism/core/constants/app_constants.dart' as app_constants;
import 'package:Prism/core/di/injection.dart';
import 'package:Prism/core/error/failure.dart';
import 'package:Prism/core/persistence/data_sources/favorites_local_data_source.dart';
import 'package:Prism/core/persistence/data_sources/settings_local_data_source.dart';
import 'package:Prism/core/personalization/taste_signals.dart';
import 'package:Prism/core/state/app_state.dart' as app_state;
import 'package:Prism/core/utils/result.dart';
import 'package:Prism/core/utils/status.dart';
import 'package:Prism/core/wallpaper/wallpaper_core.dart';
import 'package:Prism/core/wallpaper/wallpaper_source.dart';
import 'package:Prism/core/wallpaper/wallpaper_variants.dart';
import 'package:Prism/core/widgets/prism/prism_ui.dart';
import 'package:Prism/features/favourite_walls/biz/bloc/favourite_walls_bloc.j.dart';
import 'package:Prism/features/favourite_walls/domain/entities/favourite_wall_entity.dart';
import 'package:Prism/features/favourite_walls/domain/usecases/favourite_walls_usecases.dart';
import 'package:Prism/features/folders/biz/bloc/folders_bloc.j.dart';
import 'package:Prism/features/folders/domain/entities/discover_folder.dart';
import 'package:Prism/features/folders/domain/entities/folder_entity.dart';
import 'package:Prism/features/folders/domain/entities/folder_member.dart';
import 'package:Prism/features/folders/domain/entities/folder_section.dart';
import 'package:Prism/features/folders/domain/entities/public_folder_entity.dart';
import 'package:Prism/features/folders/domain/entities/smart_rule.dart';
import 'package:Prism/features/folders/domain/repositories/folders_repository.dart';
import 'package:Prism/features/folders/domain/repositories/public_folders_repository.dart';
import 'package:Prism/features/folders/views/widgets/folder_sheet.dart';
import 'package:Prism/l10n/l10n.dart';
import 'package:Prism/theme/theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import '../../../support/fake_app_analytics.dart';
import '../../../support/favourite_test_scope.dart';
import '../../../support/in_memory_local_store.dart';

class _MockFetchFavouriteWallsUseCase extends Mock implements FetchFavouriteWallsUseCase {}

class _MockToggleFavouriteWallUseCase extends Mock implements ToggleFavouriteWallUseCase {}

class _MockClearFavouriteWallsUseCase extends Mock implements ClearFavouriteWallsUseCase {}

class _MockSetFavouritePinUseCase extends Mock implements SetFavouritePinUseCase {}

class _FakeFoldersRepository implements FoldersRepository {
  _FakeFoldersRepository({
    this.folders = const <FolderEntity>[],
    this.containing = const <String, Set<String>>{},
    this.gate,
  });

  final List<FolderEntity> folders;
  bool failLoad = false;
  bool failCreate = false;
  Completer<void>? loadGate;
  Completer<void>? saveGate;
  Completer<void>? createGate;
  final List<FolderEntity> createdFolders = <FolderEntity>[];

  /// Folder ids that hold each item, keyed by folderItemKey.
  final Map<String, Set<String>> containing;

  /// When set, foldersContaining waits on this until the test completes it.
  final Completer<void>? gate;

  /// One entry per repository call, for example 'addItem:blue'.
  final List<String> calls = <String>[];

  @override
  Stream<FolderWriteFailure> get writeFailures => const Stream.empty();

  @override
  int get writeRevision => 0;

  @override
  Future<Result<List<FolderEntity>>> fetchFolders(String userId) async {
    calls.add('fetchFolders:$userId');
    await loadGate?.future;
    if (failLoad) return Result.error(const NetworkFailure('offline'));
    return Result.success(folders);
  }

  @override
  Future<Result<List<FolderItem>?>> fetchItems(String folderId, {required String userId, int? limit}) async {
    calls.add('fetchItems:$folderId');
    return Result.success(const <FolderItem>[]);
  }

  @override
  Future<Result<void>> organize(
    FolderEntity folder, {
    required String userId,
    List<FolderSection>? sections,
    Map<String, String?> moves = const <String, String?>{},
  }) async {
    calls.add('organize:${folder.id}');
    return Result.success<void>(null);
  }

  @override
  Future<Result<Set<String>>> foldersContaining(List<String> folderIds, String itemKey) async {
    calls.add('foldersContaining:$itemKey');
    await gate?.future;
    return Result.success(containing[itemKey] ?? <String>{});
  }

  @override
  Future<Result<void>> createFolder(FolderEntity folder, {FavouriteWallEntity? firstWall}) async {
    calls.add('createFolder:${folder.name}:${folder.itemCount}');
    await createGate?.future;
    if (failCreate) return Result.error(const ServerFailure('boom'));
    createdFolders.add(folder);
    return Result.success<void>(null);
  }

  @override
  Future<Result<void>> renameFolder(FolderEntity folder) async {
    calls.add('renameFolder:${folder.id}');
    return Result.success<void>(null);
  }

  @override
  Future<Result<void>> deleteFolder(String folderId, {required String userId, bool Function()? isCancelled}) async {
    calls.add('deleteFolder:$folderId');
    return Result.success<void>(null);
  }

  @override
  Future<Result<void>> addItem(FolderEntity folder, FavouriteWallEntity wall, {required String userId}) async {
    calls.add('addItem:${folder.id}');
    await saveGate?.future;
    return Result.success<void>(null);
  }

  @override
  Future<Result<void>> removeItem(FolderEntity folder, FavouriteWallEntity wall, {required String userId}) async {
    calls.add('removeItem:${folder.id}');
    return Result.success<void>(null);
  }
}

final DateTime _at = DateTime.utc(2026, 10);

FolderEntity _folder(String id, String name, {int itemCount = 0}) => FolderEntity(
  id: id,
  ownerId: 'u1',
  name: name,
  createdAt: _at,
  updatedAt: _at,
  itemCount: itemCount,
  covers: const <String>[],
);

FavouriteWallEntity _wall({String? category, List<String>? colors}) => PrismFavouriteWall(
  id: 'wall_1',
  wallpaper: PrismWallpaper(
    core: WallpaperCore(id: 'wall_1', source: WallpaperSource.prism, fullUrl: '', thumbnailUrl: '', category: category),
    colors: colors,
  ),
);

bool _checked(WidgetTester tester, String title) =>
    tester.widget<FolderCheckRow>(find.widgetWithText(FolderCheckRow, title)).checked;

/// The onPressed of the PrismButton labelled [label]. Null means the button is disabled.
VoidCallback? _onPressedOf(WidgetTester tester, String label) =>
    tester.widget<PrismButton>(find.widgetWithText(PrismButton, label)).onPressed;

class _NoPublicFolders implements PublicFoldersRepository {
  @override
  Future<Result<Set<String>>> fetchFollowedIds(String userId) async => Result.success(<String>{});

  @override
  Future<Result<FolderDiscoverLists>> fetchDiscover() async => Result.success(FolderDiscoverLists.empty);

  @override
  Future<void> recordSignal(String folderId, FolderSignal signal) async {}

  @override
  Future<Result<PublicFolderEntity?>> fetchFolder(String folderId) async => Result.success<PublicFolderEntity?>(null);

  @override
  Future<Result<List<PublicFolderWall>>> fetchWallIds(String folderId) async => Result.success(<PublicFolderWall>[]);

  @override
  Future<Result<List<PublicFolderEntity>>> fetchOwnerFolders(String ownerId) async =>
      Result.success(<PublicFolderEntity>[]);

  @override
  Future<Result<List<PublicFolderEntity>>> fetchFollowedFolders(String userId) async =>
      Result.success(<PublicFolderEntity>[]);

  @override
  Future<Result<bool>> isFollowing(String folderId, String userId) async => Result.success(false);

  @override
  Future<Result<void>> setFollowing(String folderId, {required bool following}) async => Result.success<void>(null);

  @override
  Future<Result<bool>> setPublic(String folderId, {required bool isPublic}) async => Result.success(isPublic);
}

void main() {
  setUpFavouriteCounts();

  setUpAll(() {
    registerFallbackValue(const FetchFavouriteWallsParams(userId: 'u1'));
    registerFallbackValue(
      const ToggleFavouriteWallParams(
        userId: 'u1',
        currentlyFavourited: false,
        wall: LegacyFavouriteWall(id: 'wall_1', source: WallpaperSource.prism, legacyPayload: <String, Object?>{}),
      ),
    );
    registerFallbackValue(const ClearFavouriteWallsParams(userId: 'u1', wallIds: <String>[]));
  });

  late _MockFetchFavouriteWallsUseCase fetchUseCase;
  late _MockToggleFavouriteWallUseCase toggleUseCase;
  late _MockClearFavouriteWallsUseCase clearUseCase;
  late FakeAppAnalytics analytics;

  final List<MethodCall> toasts = <MethodCall>[];

  setUp(() {
    analytics = FakeAppAnalytics();
    AnalyticsRuntime.instance = analytics;
    fetchUseCase = _MockFetchFavouriteWallsUseCase();
    toggleUseCase = _MockToggleFavouriteWallUseCase();
    clearUseCase = _MockClearFavouriteWallsUseCase();
    when(() => fetchUseCase(any())).thenAnswer((_) async => Result.success(const <FavouriteWallEntity>[]));
    when(() => toggleUseCase(any())).thenAnswer((_) async => Result.success(true));
    when(() => clearUseCase(any())).thenAnswer((_) async => Result.success(true));
    app_state.prismUser = app_constants.createGuestPrismUser()
      ..id = 'u1'
      ..loggedIn = true;
    getIt.registerSingleton<FavoritesLocalDataSource>(FavoritesLocalDataSource(InMemoryLocalStore()));
    toasts.clear();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
      const MethodChannel('PonnamKarthik/fluttertoast'),
      (call) async {
        toasts.add(call);
        return true;
      },
    );
  });

  tearDown(() async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
      const MethodChannel('PonnamKarthik/fluttertoast'),
      null,
    );
    AnalyticsRuntime.reset();
    app_state.prismUser = app_constants.createGuestPrismUser();
    await getIt.reset();
  });

  // The sheet's skeleton and tick animations keep the frame busy, so pump a fixed time instead of settling.
  Future<void> settle(WidgetTester tester) async {
    for (int i = 0; i < 6; i++) {
      await tester.pump(const Duration(milliseconds: 500));
    }
  }

  /// Pumps a button that opens the folder sheet for [wall], then taps it.
  Future<void> openSheet(
    WidgetTester tester,
    FoldersBloc bloc,
    FavouriteWallEntity wall, {
    GlobalKey<NavigatorState>? navigatorKey,
  }) async {
    final FavouriteWallsBloc favourites = FavouriteWallsBloc(
      fetchUseCase,
      toggleUseCase,
      clearUseCase,
      _MockSetFavouritePinUseCase(),
    );
    addTearDown(favourites.close);
    await tester.pumpWidget(
      MaterialApp(
        navigatorKey: navigatorKey,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        theme: kLightTheme,
        // Providers sit above the Navigator so the sheet route, pushed on top of home, can read them.
        builder: (context, navigator) => MultiBlocProvider(
          providers: <BlocProvider<dynamic>>[
            BlocProvider<FoldersBloc>.value(value: bloc),
            BlocProvider<FavouriteWallsBloc>.value(value: favourites),
          ],
          child: navigator!,
        ),
        home: Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: TextButton(onPressed: () => unawaited(showFolderSheet(context, wall)), child: const Text('open')),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await settle(tester);
  }

  testWidgets('ticking two folders and tapping Done adds the wall to both', (tester) async {
    final FavouriteWallEntity wall = _wall();
    final _FakeFoldersRepository repo = _FakeFoldersRepository(
      folders: <FolderEntity>[_folder('blue', 'Blue'), _folder('calm', 'Calm')],
    );
    final FoldersBloc bloc = FoldersBloc(repo, _NoPublicFolders());
    addTearDown(bloc.close);
    await openSheet(tester, bloc, wall);

    await tester.tap(find.text('Blue'));
    await settle(tester);
    await tester.tap(find.text('Calm'));
    await settle(tester);
    await tester.tap(find.text('Done'));
    await settle(tester);

    expect(
      repo.calls.where((call) => call.startsWith('addItem:')),
      unorderedEquals(<String>['addItem:blue', 'addItem:calm']),
    );
    expect(bloc.state.membership[folderItemKey(wall)], unorderedEquals(<String>['blue', 'calm']));
  });

  testWidgets('saving a Prism wall to a folder records a folderAdd taste signal', (tester) async {
    const String fullUrl = 'https://Img.test/Wall-1.jpg';
    final TasteSignalStore store = TasteSignalStore(SettingsLocalDataSource(InMemoryLocalStore()));
    getIt.registerSingleton<TasteSignalStore>(store);
    const FavouriteWallEntity wall = PrismFavouriteWall(
      id: 'wall_1',
      wallpaper: PrismWallpaper(
        core: WallpaperCore(
          id: 'wall_1',
          source: WallpaperSource.prism,
          fullUrl: fullUrl,
          thumbnailUrl: '',
          category: 'nature',
        ),
      ),
    );
    final _FakeFoldersRepository repo = _FakeFoldersRepository(folders: <FolderEntity>[_folder('blue', 'Blue')]);
    final FoldersBloc bloc = FoldersBloc(repo, _NoPublicFolders());
    addTearDown(bloc.close);
    await openSheet(tester, bloc, wall);

    await tester.tap(find.text('Blue'));
    await settle(tester);
    await tester.tap(find.text('Done'));
    await settle(tester);

    expect(store.read().single.action, TasteAction.folderAdd);
    expect(store.read().single.wallKey, fullUrl.toLowerCase());
  });

  testWidgets('a folder the wall is already in starts ticked, and unticking it removes the wall', (tester) async {
    final FavouriteWallEntity wall = _wall();
    final _FakeFoldersRepository repo = _FakeFoldersRepository(
      folders: <FolderEntity>[_folder('blue', 'Blue', itemCount: 1), _folder('calm', 'Calm')],
      containing: <String, Set<String>>{
        folderItemKey(wall): <String>{'blue'},
      },
    );
    final FoldersBloc bloc = FoldersBloc(repo, _NoPublicFolders());
    addTearDown(bloc.close);
    await openSheet(tester, bloc, wall);

    expect(_checked(tester, 'Blue'), isTrue);
    expect(_checked(tester, 'Calm'), isFalse);

    await tester.tap(find.text('Blue'));
    await settle(tester);
    await tester.tap(find.text('Done'));
    await settle(tester);

    expect(repo.calls, contains('removeItem:blue'));
    expect(repo.calls.where((call) => call.startsWith('addItem:')), isEmpty);
  });

  testWidgets('a guest sees the sign-in prompt, no Done button, and no repository call', (tester) async {
    app_state.prismUser = app_constants.createGuestPrismUser();
    final FavouriteWallEntity wall = _wall();
    final _FakeFoldersRepository repo = _FakeFoldersRepository(folders: <FolderEntity>[_folder('blue', 'Blue')]);
    final FoldersBloc bloc = FoldersBloc(repo, _NoPublicFolders());
    addTearDown(bloc.close);
    await openSheet(tester, bloc, wall);

    expect(find.text('Sign in to use folders'), findsOneWidget);
    expect(find.text('Done'), findsNothing);
    expect(repo.calls, isEmpty);
  });

  testWidgets('Done is disabled while the wall membership is still loading', (tester) async {
    final Completer<void> gate = Completer<void>();
    final FavouriteWallEntity wall = _wall();
    final _FakeFoldersRepository repo = _FakeFoldersRepository(
      folders: <FolderEntity>[_folder('blue', 'Blue')],
      gate: gate,
    );
    final FoldersBloc bloc = FoldersBloc(repo, _NoPublicFolders());
    addTearDown(bloc.close);
    await openSheet(tester, bloc, wall);

    expect(tester.widget<PrismButton>(find.widgetWithText(PrismButton, 'Done')).onPressed, isNull);

    gate.complete();
    await settle(tester);

    expect(tester.widget<PrismButton>(find.widgetWithText(PrismButton, 'Done')).onPressed, isNotNull);
  });

  testWidgets('failed folder loading keeps Done disabled until retry succeeds', (tester) async {
    final repo = _FakeFoldersRepository(folders: <FolderEntity>[_folder('blue', 'Blue')])..failLoad = true;
    final bloc = FoldersBloc(repo, _NoPublicFolders());
    addTearDown(bloc.close);
    await openSheet(tester, bloc, _wall());

    expect(find.text('Try again'), findsOneWidget);
    expect(tester.widget<PrismButton>(find.widgetWithText(PrismButton, 'Done')).onPressed, isNull);
    repo.failLoad = false;
    await tester.tap(find.text('Try again'));
    await settle(tester);

    expect(find.text('Blue'), findsOneWidget);
    expect(tester.widget<PrismButton>(find.widgetWithText(PrismButton, 'Done')).onPressed, isNotNull);
  });

  testWidgets('an open picker closes and discards its draft when the account changes', (tester) async {
    final repo = _FakeFoldersRepository(folders: <FolderEntity>[_folder('blue', 'Blue')]);
    final bloc = FoldersBloc(repo, _NoPublicFolders());
    addTearDown(bloc.close);
    await openSheet(tester, bloc, _wall());
    await tester.tap(find.text('Blue'));
    await settle(tester);
    expect(_checked(tester, 'Blue'), isTrue);

    app_state.prismUser = app_constants.createGuestPrismUser()..id = 'u2';
    bloc.add(const FoldersEvent.started(userId: 'u2'));
    await settle(tester);

    expect(find.byType(FolderSheet), findsNothing);
    expect(repo.calls.where((call) => call.startsWith('addItem:')), isEmpty);
    expect(repo.calls.where((call) => call.startsWith('createFolder:')), isEmpty);
    verifyNever(() => toggleUseCase(any()));
  });

  testWidgets('switching accounts during the first load closes the original picker', (tester) async {
    final gate = Completer<void>();
    final repo = _FakeFoldersRepository()..loadGate = gate;
    final bloc = FoldersBloc(repo, _NoPublicFolders());
    addTearDown(bloc.close);
    await openSheet(tester, bloc, _wall());

    app_state.prismUser = app_constants.createGuestPrismUser()..id = 'u2';
    bloc.add(const FoldersEvent.started(userId: 'u2'));
    await settle(tester);
    expect(find.byType(FolderSheet), findsNothing);
    gate.complete();
    await settle(tester);
    expect(repo.calls.where((call) => call.startsWith('createFolder:')), isEmpty);
  });

  testWidgets('the wall is favourited for the original account before the save, not after an account change', (
    tester,
  ) async {
    final gate = Completer<void>();
    final repo = _FakeFoldersRepository(folders: <FolderEntity>[_folder('blue', 'Blue')])..saveGate = gate;
    final bloc = FoldersBloc(repo, _NoPublicFolders());
    addTearDown(bloc.close);
    await openSheet(tester, bloc, _wall());
    await tester.tap(find.text('Blue'));
    await tester.tap(find.text('Done'));
    await settle(tester);
    expect(repo.calls, contains('addItem:blue'));
    verify(() => toggleUseCase(any())).called(1);

    // App state changes before the debounced SessionBloc notification reaches the folder bloc.
    app_state.prismUser = app_constants.createGuestPrismUser()..id = 'u2';
    gate.complete();
    await settle(tester);

    verifyNever(() => toggleUseCase(any()));
  });

  testWidgets('a failed favourite stops the folder save', (tester) async {
    when(() => toggleUseCase(any())).thenAnswer((_) async => Result.error(const NetworkFailure('offline')));
    final repo = _FakeFoldersRepository(folders: <FolderEntity>[_folder('blue', 'Blue')]);
    final bloc = FoldersBloc(repo, _NoPublicFolders());
    addTearDown(bloc.close);
    await openSheet(tester, bloc, _wall());
    await tester.tap(find.text('Blue'));
    await tester.tap(find.text('Done'));
    await settle(tester);

    verify(() => toggleUseCase(any())).called(1);
    expect(repo.calls.where((call) => call.startsWith('addItem:')), isEmpty);
  });

  testWidgets('a failed favourite list read does not block a successful favourite and folder save', (tester) async {
    when(() => fetchUseCase(any())).thenAnswer((_) async => Result.error(const NetworkFailure('offline')));
    final repo = _FakeFoldersRepository(folders: <FolderEntity>[_folder('blue', 'Blue')]);
    final bloc = FoldersBloc(repo, _NoPublicFolders());
    addTearDown(bloc.close);
    await openSheet(tester, bloc, _wall());
    await tester.tap(find.text('Blue'));
    await tester.tap(find.text('Done'));
    await settle(tester);

    verify(() => toggleUseCase(any())).called(1);
    expect(repo.calls.where((call) => call.startsWith('addItem:')), <String>['addItem:blue']);
  });

  testWidgets('opening a picker during an existing folder load waits and then loads membership', (tester) async {
    final gate = Completer<void>();
    final repo = _FakeFoldersRepository(folders: <FolderEntity>[_folder('blue', 'Blue')])..loadGate = gate;
    final bloc = FoldersBloc(repo, _NoPublicFolders());
    addTearDown(bloc.close);
    final started = bloc.run((id) => FoldersEvent.started(userId: 'u1', operationId: id));
    await tester.pump();
    expect(bloc.state.status, LoadStatus.loading);
    await openSheet(tester, bloc, _wall());

    gate.complete();
    await settle(tester);
    expect(await started, isTrue);
    expect(find.text('Blue'), findsOneWidget);
    expect(tester.widget<PrismButton>(find.widgetWithText(PrismButton, 'Done')).onPressed, isNotNull);
  });

  testWidgets('cached membership does not enable Done before the membership refresh can run', (tester) async {
    final wall = _wall();
    final repo = _FakeFoldersRepository(folders: <FolderEntity>[_folder('blue', 'Blue')]);
    final bloc = FoldersBloc(repo, _NoPublicFolders());
    addTearDown(bloc.close);
    bloc.add(const FoldersEvent.started(userId: 'u1'));
    bloc.add(FoldersEvent.membershipRequested(wall: wall));
    await tester.pump();
    expect(bloc.state.membershipStatus[folderItemKey(wall)], LoadStatus.success);

    final gate = Completer<void>();
    repo.loadGate = gate;
    bloc.add(const FoldersEvent.folderOpened(folderId: 'blue'));
    await openSheet(tester, bloc, wall);
    expect(_onPressedOf(tester, 'Done'), isNull);
    expect(find.text('Blue'), findsNothing);

    gate.complete();
    await settle(tester);
    expect(_onPressedOf(tester, 'Done'), isNotNull);
    expect(_checked(tester, 'Blue'), isFalse);
  });

  testWidgets('clear then a new account closes only the picker, not the page beneath it', (tester) async {
    final repo = _FakeFoldersRepository();
    final bloc = FoldersBloc(repo, _NoPublicFolders());
    addTearDown(bloc.close);
    await openSheet(tester, bloc, _wall());

    app_state.prismUser = app_constants.createGuestPrismUser()..id = 'u2';
    bloc.add(const FoldersEvent.cleared());
    await tester.pump();
    bloc.add(const FoldersEvent.started(userId: 'u2'));
    await tester.pump();
    await settle(tester);

    expect(find.text('open'), findsOneWidget);
    expect(find.byType(FolderSheet), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('an account clear during Done dismissal does not pop the page beneath the picker', (tester) async {
    final repo = _FakeFoldersRepository();
    final bloc = FoldersBloc(repo, _NoPublicFolders());
    addTearDown(bloc.close);
    await openSheet(tester, bloc, _wall());
    await tester.tap(find.text('Done'));
    await tester.pump();
    app_state.prismUser = app_constants.createGuestPrismUser();
    bloc.add(const FoldersEvent.cleared());
    await settle(tester);

    expect(find.text('open'), findsOneWidget);
    expect(find.byType(FolderSheet), findsNothing);
  });

  testWidgets('ticking two folders does not write until Done, then saves both in one batch', (tester) async {
    final FavouriteWallEntity wall = _wall();
    final _FakeFoldersRepository repo = _FakeFoldersRepository(
      folders: <FolderEntity>[_folder('blue', 'Blue'), _folder('calm', 'Calm')],
    );
    final FoldersBloc bloc = FoldersBloc(repo, _NoPublicFolders());
    addTearDown(bloc.close);
    await openSheet(tester, bloc, wall);

    await tester.tap(find.text('Blue'));
    await settle(tester);
    await tester.tap(find.text('Calm'));
    await settle(tester);
    expect(repo.calls.where((call) => call.startsWith('addItem:')), isEmpty);

    await tester.tap(find.text('Done'));
    await settle(tester);

    expect(
      repo.calls.where((call) => call.startsWith('addItem:')),
      unorderedEquals(<String>['addItem:blue', 'addItem:calm']),
    );
    verify(() => toggleUseCase(any())).called(1);
  });

  testWidgets('closing with X discards the ticks and writes nothing', (tester) async {
    final _FakeFoldersRepository repo = _FakeFoldersRepository(folders: <FolderEntity>[_folder('blue', 'Blue')]);
    final FoldersBloc bloc = FoldersBloc(repo, _NoPublicFolders());
    addTearDown(bloc.close);
    await openSheet(tester, bloc, _wall());
    await tester.tap(find.text('Blue'));
    await settle(tester);

    await tester.tap(find.byTooltip('Close'));
    await settle(tester);

    expect(find.byType(FolderSheet), findsNothing);
    expect(
      repo.calls.where(
        (call) => call.startsWith('addItem:') || call.startsWith('removeItem:') || call.startsWith('createFolder:'),
      ),
      isEmpty,
    );
    verifyNever(() => toggleUseCase(any()));
  });

  testWidgets('tapping Done twice saves once', (tester) async {
    final _FakeFoldersRepository repo = _FakeFoldersRepository(folders: <FolderEntity>[_folder('blue', 'Blue')]);
    final FoldersBloc bloc = FoldersBloc(repo, _NoPublicFolders());
    addTearDown(bloc.close);
    await openSheet(tester, bloc, _wall());
    await tester.tap(find.text('Blue'));
    await settle(tester);

    // A fast double tap reaches the handler twice before the closing route stops pointer events.
    final VoidCallback done = tester.widget<PrismButton>(find.widgetWithText(PrismButton, 'Done')).onPressed!;
    done();
    done();
    await settle(tester);

    expect(repo.calls.where((call) => call.startsWith('addItem:')), equals(<String>['addItem:blue']));
    verify(() => toggleUseCase(any())).called(1);
    expect(toasts.where((call) => call.method == 'showToast'), hasLength(1));
    expect(find.text('open'), findsOneWidget);
  });

  testWidgets('Create folder is disabled for an empty or blank name', (tester) async {
    final _FakeFoldersRepository repo = _FakeFoldersRepository(folders: <FolderEntity>[_folder('blue', 'Blue')]);
    final FoldersBloc bloc = FoldersBloc(repo, _NoPublicFolders());
    addTearDown(bloc.close);
    await openSheet(tester, bloc, _wall());
    await tester.tap(find.text('Create new folder'));
    await settle(tester);

    expect(find.text('New folder'), findsOneWidget);
    expect(find.text('Make a folder for your walls. You can edit it later.'), findsOneWidget);
    expect(_onPressedOf(tester, 'Create folder'), isNull);

    await tester.enterText(find.byType(TextField), '   ');
    await settle(tester);
    expect(_onPressedOf(tester, 'Create folder'), isNull);

    await tester.enterText(find.byType(TextField), 'Night');
    await settle(tester);
    expect(_onPressedOf(tester, 'Create folder'), isNotNull);
    expect(find.byTooltip('Clear name'), findsOneWidget);

    await tester.tap(find.byTooltip('Clear name'));
    await settle(tester);
    expect(tester.widget<TextField>(find.byType(TextField)).controller!.text, isEmpty);
    expect(_onPressedOf(tester, 'Create folder'), isNull);
  });

  testWidgets('page 2 focuses the name field', (tester) async {
    final _FakeFoldersRepository repo = _FakeFoldersRepository(folders: <FolderEntity>[_folder('blue', 'Blue')]);
    final FoldersBloc bloc = FoldersBloc(repo, _NoPublicFolders());
    addTearDown(bloc.close);
    await openSheet(tester, bloc, _wall());
    await tester.tap(find.text('Create new folder'));
    await settle(tester);

    expect(tester.widget<EditableText>(find.byType(EditableText)).focusNode.hasFocus, isTrue);
  });

  testWidgets('creating a folder returns to page 1 with it first and checked, and Done adds the wall to it', (
    tester,
  ) async {
    final FavouriteWallEntity wall = _wall();
    final _FakeFoldersRepository repo = _FakeFoldersRepository(folders: <FolderEntity>[_folder('blue', 'Blue')]);
    final FoldersBloc bloc = FoldersBloc(repo, _NoPublicFolders());
    addTearDown(bloc.close);
    await openSheet(tester, bloc, wall);
    await tester.tap(find.text('Create new folder'));
    await settle(tester);
    await tester.enterText(find.byType(TextField), 'Night');
    await settle(tester);

    await tester.tap(find.text('Create folder'));
    await settle(tester);

    expect(repo.calls, contains('createFolder:Night:0'));
    expect(find.text('Add to folder'), findsOneWidget);
    final FolderCheckRow first = tester.widgetList<FolderCheckRow>(find.byType(FolderCheckRow)).first;
    expect(first.title, 'Night');
    expect(first.checked, isTrue);
    expect(_checked(tester, 'Blue'), isFalse);

    await tester.tap(find.text('Done'));
    await settle(tester);

    final String nightId = bloc.state.folders.firstWhere((folder) => folder.name == 'Night').id;
    expect(repo.calls, contains('addItem:$nightId'));
  });

  testWidgets('back from page 2 keeps the ticks on page 1', (tester) async {
    final _FakeFoldersRepository repo = _FakeFoldersRepository(folders: <FolderEntity>[_folder('blue', 'Blue')]);
    final FoldersBloc bloc = FoldersBloc(repo, _NoPublicFolders());
    addTearDown(bloc.close);
    await openSheet(tester, bloc, _wall());
    await tester.tap(find.text('Blue'));
    await settle(tester);
    await tester.tap(find.text('Create new folder'));
    await settle(tester);

    await tester.tap(find.byTooltip('Back'));
    await settle(tester);

    expect(_checked(tester, 'Blue'), isTrue);
    expect(repo.calls.where((call) => call.startsWith('createFolder:')), isEmpty);
  });

  testWidgets('a failed create shows the error under the field, and retry works', (tester) async {
    final _FakeFoldersRepository repo = _FakeFoldersRepository(folders: <FolderEntity>[_folder('blue', 'Blue')])
      ..failCreate = true;
    final FoldersBloc bloc = FoldersBloc(repo, _NoPublicFolders());
    addTearDown(bloc.close);
    await openSheet(tester, bloc, _wall());
    await tester.tap(find.text('Create new folder'));
    await settle(tester);
    await tester.enterText(find.byType(TextField), 'Night');
    await settle(tester);

    await tester.tap(find.text('Create folder'));
    await settle(tester);

    expect(find.text('Could not create the folder. Try again.'), findsOneWidget);
    expect(find.text('New folder'), findsOneWidget);

    repo.failCreate = false;
    await tester.tap(find.text('Create folder'));
    await settle(tester);

    expect(find.text('Add to folder'), findsOneWidget);
    expect(_checked(tester, 'Night'), isTrue);
  });

  testWidgets('a same-name folder discovered before create is not selected instead of the new folder', (tester) async {
    final folders = <FolderEntity>[_folder('blue', 'Blue')];
    final repo = _FakeFoldersRepository(folders: folders);
    final bloc = FoldersBloc(repo, _NoPublicFolders());
    addTearDown(bloc.close);
    await openSheet(tester, bloc, _wall());
    await tester.tap(find.text('Create new folder'));
    await settle(tester);
    await tester.enterText(find.byType(TextField), 'Night');
    await settle(tester);

    final gate = Completer<void>();
    repo.loadGate = gate;
    folders.add(_folder('other-night', 'Night').copyWith(updatedAt: DateTime.utc(2100)));
    bloc.add(const FoldersEvent.folderOpened(folderId: 'blue'));
    await tester.tap(find.text('Create folder'));
    await tester.pump();
    expect(repo.createdFolders, isEmpty);
    gate.complete();
    await settle(tester);

    final createdId = repo.createdFolders.single.id;
    final rows = tester.widgetList<FolderCheckRow>(find.byType(FolderCheckRow));
    expect(rows.first.key, ValueKey<String>(createdId));
    expect(rows.first.checked, isTrue);
    expect(rows.singleWhere((row) => row.key == const ValueKey<String>('other-night')).checked, isFalse);
    await tester.tap(find.text('Done'));
    await settle(tester);
    expect(repo.calls.where((call) => call.startsWith('addItem:')), <String>['addItem:$createdId']);
  });

  testWidgets('a same-account refresh reloads membership and preserves draft ticks', (tester) async {
    final wall = _wall();
    final repo = _FakeFoldersRepository(
      folders: <FolderEntity>[_folder('blue', 'Blue'), _folder('calm', 'Calm')],
      containing: <String, Set<String>>{
        folderItemKey(wall): <String>{'blue'},
      },
    );
    final bloc = FoldersBloc(repo, _NoPublicFolders());
    addTearDown(bloc.close);
    await openSheet(tester, bloc, wall);
    await tester.tap(find.text('Calm'));
    bloc.add(const FoldersEvent.started(userId: 'u1'));
    await settle(tester);

    expect(_checked(tester, 'Blue'), isTrue);
    expect(_checked(tester, 'Calm'), isTrue);
    await tester.tap(find.text('Done'));
    await settle(tester);
    expect(bloc.state.membership[folderItemKey(wall)], <String>{'blue', 'calm'});
    expect(repo.calls.where((call) => call.startsWith('addItem:')), <String>['addItem:calm']);
  });

  testWidgets('a deleted draft target does not block saving the remaining checked folder', (tester) async {
    final wall = _wall();
    final repo = _FakeFoldersRepository(folders: <FolderEntity>[_folder('blue', 'Blue'), _folder('calm', 'Calm')]);
    final bloc = FoldersBloc(repo, _NoPublicFolders());
    addTearDown(bloc.close);
    await openSheet(tester, bloc, wall);
    await tester.tap(find.text('Blue'));
    await tester.tap(find.text('Calm'));
    bloc.add(const FoldersEvent.deleteRequested(folderId: 'blue'));
    await settle(tester);

    expect(find.text('Blue'), findsNothing);
    expect(_checked(tester, 'Calm'), isTrue);
    await tester.tap(find.text('Done'));
    await settle(tester);
    expect(bloc.state.membership[folderItemKey(wall)], <String>{'calm'});
  });

  testWidgets('an account change removes the picker without popping a route pushed above it', (tester) async {
    final navigator = GlobalKey<NavigatorState>();
    final bloc = FoldersBloc(_FakeFoldersRepository(), _NoPublicFolders());
    addTearDown(bloc.close);
    await openSheet(tester, bloc, _wall(), navigatorKey: navigator);
    unawaited(
      navigator.currentState!.push<void>(
        MaterialPageRoute<void>(builder: (_) => const Scaffold(body: Text('New destination'))),
      ),
    );
    await settle(tester);

    app_state.prismUser = app_constants.createGuestPrismUser()..id = 'u2';
    bloc.add(const FoldersEvent.started(userId: 'u2'));
    await settle(tester);

    expect(find.text('New destination'), findsOneWidget);
    expect(find.byType(FolderSheet, skipOffstage: false), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('dismissing the route before a stale Done callback discards its ticks', (tester) async {
    final navigator = GlobalKey<NavigatorState>();
    final repo = _FakeFoldersRepository(folders: <FolderEntity>[_folder('blue', 'Blue')]);
    final bloc = FoldersBloc(repo, _NoPublicFolders());
    addTearDown(bloc.close);
    await openSheet(tester, bloc, _wall(), navigatorKey: navigator);
    await tester.tap(find.text('Blue'));
    await settle(tester);
    final done = _onPressedOf(tester, 'Done')!;
    navigator.currentState!.pop();
    done();
    await settle(tester);

    expect(find.text('open'), findsOneWidget);
    expect(find.byType(FolderSheet), findsNothing);
    expect(repo.calls.where((call) => call.startsWith('addItem:')), isEmpty);
    verifyNever(() => toggleUseCase(any()));
  });

  testWidgets('closing during a pending create leaves exactly one empty folder', (tester) async {
    final gate = Completer<void>();
    final repo = _FakeFoldersRepository()..createGate = gate;
    final bloc = FoldersBloc(repo, _NoPublicFolders());
    addTearDown(bloc.close);
    await openSheet(tester, bloc, _wall());
    await tester.tap(find.text('Create new folder'));
    await settle(tester);
    await tester.enterText(find.byType(TextField), 'Night');
    await settle(tester);
    final create = _onPressedOf(tester, 'Create folder')!;
    create();
    create();
    await tester.pump();
    await tester.tap(find.byTooltip('Close'));
    await settle(tester);
    gate.complete();
    await settle(tester);

    expect(find.text('open'), findsOneWidget);
    expect(find.byType(FolderSheet), findsNothing);
    expect(bloc.state.folders.single.name, 'Night');
    expect(bloc.state.items[repo.createdFolders.single.id], isEmpty);
    expect(repo.calls.where((call) => call.startsWith('addItem:')), isEmpty);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Create does not write for a previous account before the bloc receives the account change', (
    tester,
  ) async {
    final repo = _FakeFoldersRepository();
    final bloc = FoldersBloc(repo, _NoPublicFolders());
    addTearDown(bloc.close);
    await openSheet(tester, bloc, _wall());
    await tester.tap(find.text('Create new folder'));
    await settle(tester);
    await tester.enterText(find.byType(TextField), 'Night');
    await settle(tester);

    app_state.prismUser = app_constants.createGuestPrismUser()..id = 'u2';
    await tester.tap(find.text('Create folder'));
    await settle(tester);

    expect(find.text('open'), findsOneWidget);
    expect(find.byType(FolderSheet), findsNothing);
    expect(repo.calls.where((call) => call.startsWith('createFolder:')), isEmpty);
  });

  testWidgets('a fit-only picker can be swiped away without saving ticks', (tester) async {
    final repo = _FakeFoldersRepository(folders: <FolderEntity>[_folder('blue', 'Blue')]);
    final bloc = FoldersBloc(repo, _NoPublicFolders());
    addTearDown(bloc.close);
    await openSheet(tester, bloc, _wall());
    await tester.tap(find.text('Blue'));
    expect(find.text('Add to folder'), findsOneWidget);
    await tester.fling(find.text('Add to folder'), const Offset(0, 600), 3000);
    await settle(tester);

    expect(find.text('open'), findsOneWidget);
    expect(find.byType(FolderSheet), findsNothing);
    expect(repo.calls.where((call) => call.startsWith('addItem:')), isEmpty);
  });

  testWidgets('with no folders, page 1 shows only Create new folder and the empty line', (tester) async {
    final _FakeFoldersRepository repo = _FakeFoldersRepository();
    final FoldersBloc bloc = FoldersBloc(repo, _NoPublicFolders());
    addTearDown(bloc.close);
    await openSheet(tester, bloc, _wall());

    expect(find.text('Create new folder'), findsOneWidget);
    expect(find.text('You have no folders yet.'), findsOneWidget);
    expect(find.byType(FolderCheckRow), findsNothing);
    expect(_onPressedOf(tester, 'Done'), isNotNull);
  });

  testWidgets('smart folders and folders the user cannot edit are hidden', (tester) async {
    final _FakeFoldersRepository repo = _FakeFoldersRepository(
      folders: <FolderEntity>[
        _folder('blue', 'Blue'),
        FolderEntity(
          id: 'smart',
          ownerId: 'u1',
          name: 'Smart',
          createdAt: _at,
          updatedAt: _at,
          itemCount: 0,
          covers: const <String>[],
          smartRules: const <SmartRule>[SmartRule(SmartRuleKind.desktop)],
        ),
        FolderEntity(
          id: 'theirs',
          ownerId: 'u9',
          name: 'Theirs',
          createdAt: _at,
          updatedAt: _at,
          itemCount: 0,
          covers: const <String>[],
        ),
        FolderEntity(
          id: 'shared',
          ownerId: 'u9',
          name: 'Shared',
          createdAt: _at,
          updatedAt: _at,
          itemCount: 0,
          covers: const <String>[],
          editors: <FolderMember>[FolderMember(uid: 'u1', role: FolderRole.editor, addedBy: 'u9', addedAt: _at)],
        ),
      ],
    );
    final FoldersBloc bloc = FoldersBloc(repo, _NoPublicFolders());
    addTearDown(bloc.close);
    await openSheet(tester, bloc, _wall());

    expect(find.text('Blue'), findsOneWidget);
    expect(find.text('Shared'), findsOneWidget);
    expect(find.text('Smart'), findsNothing);
    expect(find.text('Theirs'), findsNothing);
  });

  testWidgets('each folder row is one checkable semantics node', (tester) async {
    final SemanticsHandle handle = tester.ensureSemantics();
    final _FakeFoldersRepository repo = _FakeFoldersRepository(
      folders: <FolderEntity>[_folder('blue', 'Blue'), _folder('calm', 'Calm')],
    );
    final FoldersBloc bloc = FoldersBloc(repo, _NoPublicFolders());
    addTearDown(bloc.close);
    await openSheet(tester, bloc, _wall());
    await tester.tap(find.text('Blue'));
    await settle(tester);

    expect(
      tester.getSemantics(find.widgetWithText(FolderCheckRow, 'Blue')),
      isSemantics(label: 'Blue', hasCheckedState: true, isChecked: true),
    );
    expect(
      tester.getSemantics(find.widgetWithText(FolderCheckRow, 'Calm')),
      isSemantics(label: 'Calm', hasCheckedState: true, isChecked: false),
    );
    expect(find.byTooltip('Close'), findsOneWidget);

    await tester.tap(find.text('Create new folder'));
    await settle(tester);
    expect(find.byTooltip('Back'), findsOneWidget);
    handle.dispose();
  });

  testWidgets('the New folder page fits a small phone with the keyboard up', (tester) async {
    tester.view.physicalSize = const Size(750, 1334);
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.reset);
    final _FakeFoldersRepository repo = _FakeFoldersRepository(folders: <FolderEntity>[_folder('blue', 'Blue')]);
    final FoldersBloc bloc = FoldersBloc(repo, _NoPublicFolders());
    addTearDown(bloc.close);
    await openSheet(tester, bloc, _wall());
    await tester.tap(find.text('Create new folder'));
    await settle(tester);

    // 520 physical pixels is a 260 logical pixel keyboard at 2x.
    tester.view.viewInsets = const FakeViewPadding(bottom: 520);
    await settle(tester);

    expect(tester.takeException(), isNull);
    expect(find.text('Create folder'), findsOneWidget);
    expect(tester.getCenter(find.text('Create folder')).dy, lessThan(667 - 260));
  });

  testWidgets('page 1 with 12 folders fits a small phone', (tester) async {
    tester.view.physicalSize = const Size(750, 1334);
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.reset);
    final _FakeFoldersRepository repo = _FakeFoldersRepository(
      folders: <FolderEntity>[for (int i = 0; i < 12; i++) _folder('f$i', 'Folder $i')],
    );
    final FoldersBloc bloc = FoldersBloc(repo, _NoPublicFolders());
    addTearDown(bloc.close);
    await openSheet(tester, bloc, _wall());

    expect(tester.takeException(), isNull);
    expect(find.text('Done'), findsOneWidget);
    expect(tester.getRect(find.text('Done')).bottom, lessThanOrEqualTo(667));
  });
}
