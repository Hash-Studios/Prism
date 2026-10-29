import 'dart:async';

import 'package:Prism/core/analytics/analytics_runtime.dart';
import 'package:Prism/core/constants/app_constants.dart' as app_constants;
import 'package:Prism/core/di/injection.dart';
import 'package:Prism/core/error/failure.dart';
import 'package:Prism/core/persistence/data_sources/favorites_local_data_source.dart';
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
import 'package:Prism/features/folders/domain/entities/folder_entity.dart';
import 'package:Prism/features/folders/domain/repositories/folders_repository.dart';
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
  Completer<void>? loadGate;
  Completer<void>? saveGate;

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
  Future<Result<List<FavouriteWallEntity>?>> fetchItems(String folderId, {required String userId, int? limit}) async {
    calls.add('fetchItems:$folderId');
    return Result.success(const <FavouriteWallEntity>[]);
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
  Future<Result<void>> addItem(FolderEntity folder, FavouriteWallEntity wall) async {
    calls.add('addItem:${folder.id}');
    await saveGate?.future;
    return Result.success<void>(null);
  }

  @override
  Future<Result<void>> removeItem(FolderEntity folder, FavouriteWallEntity wall) async {
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

/// The tick icon inside the row titled [title], for example Icons.check_circle_rounded.
Finder _tickIn(String title, IconData icon) => find.descendant(
  of: find.ancestor(of: find.text(title), matching: find.byType(FolderCheckRow)),
  matching: find.byIcon(icon),
);

/// The tag text inside the row titled [title].
Finder _tagIn(String title, String tag) => find.descendant(
  of: find.ancestor(of: find.text(title), matching: find.byType(FolderCheckRow)),
  matching: find.text(tag),
);

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
  Future<void> openSheet(WidgetTester tester, FoldersBloc bloc, FavouriteWallEntity wall) async {
    final FavouriteWallsBloc favourites = FavouriteWallsBloc(
      fetchUseCase,
      toggleUseCase,
      clearUseCase,
      _MockSetFavouritePinUseCase(),
    );
    addTearDown(favourites.close);
    await tester.pumpWidget(
      MaterialApp(
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
    final FoldersBloc bloc = FoldersBloc(repo);
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

  testWidgets('a folder the wall is already in starts ticked, and unticking it removes the wall', (tester) async {
    final FavouriteWallEntity wall = _wall();
    final _FakeFoldersRepository repo = _FakeFoldersRepository(
      folders: <FolderEntity>[_folder('blue', 'Blue', itemCount: 1), _folder('calm', 'Calm')],
      containing: <String, Set<String>>{
        folderItemKey(wall): <String>{'blue'},
      },
    );
    final FoldersBloc bloc = FoldersBloc(repo);
    addTearDown(bloc.close);
    await openSheet(tester, bloc, wall);

    expect(_tickIn('Blue', Icons.check_circle_rounded), findsOneWidget);
    expect(_tickIn('Calm', Icons.radio_button_unchecked_rounded), findsOneWidget);

    await tester.tap(find.text('Blue'));
    await settle(tester);
    await tester.tap(find.text('Done'));
    await settle(tester);

    expect(repo.calls, contains('removeItem:blue'));
    expect(repo.calls.where((call) => call.startsWith('addItem:')), isEmpty);
  });

  testWidgets('typing a name and tapping the create button adds a New row, saved as a new folder', (tester) async {
    final FavouriteWallEntity wall = _wall();
    final _FakeFoldersRepository repo = _FakeFoldersRepository();
    final FoldersBloc bloc = FoldersBloc(repo);
    addTearDown(bloc.close);
    await openSheet(tester, bloc, wall);

    await tester.enterText(find.byType(TextField), 'Night');
    await tester.tap(find.byTooltip('Create folder'));
    await settle(tester);

    expect(find.text('Night'), findsOneWidget);
    expect(_tagIn('Night', 'New'), findsOneWidget);

    await tester.tap(find.text('Done'));
    await settle(tester);

    expect(repo.calls, contains('createFolder:Night:1'));
  });

  testWidgets('with no folders, the sheet suggests names from the wall, and tapping one makes it a New row', (
    tester,
  ) async {
    final FavouriteWallEntity wall = _wall(category: 'Nature', colors: <String>['blue']);
    final _FakeFoldersRepository repo = _FakeFoldersRepository();
    final FoldersBloc bloc = FoldersBloc(repo);
    addTearDown(bloc.close);
    await openSheet(tester, bloc, wall);

    // The category label, the main colour, then the screen name fill the three suggestion slots.
    expect(find.text('Suggested'), findsNWidgets(3));
    expect(_tagIn('Nature', 'Suggested'), findsOneWidget);
    expect(_tagIn('Blue', 'Suggested'), findsOneWidget);
    expect(_tagIn('Lock screen', 'Suggested'), findsOneWidget);

    await tester.tap(find.text('Blue'));
    await settle(tester);

    expect(_tagIn('Blue', 'New'), findsOneWidget);
    // Once a name is added the suggestions go away.
    expect(find.text('Suggested'), findsNWidgets(2));
  });

  testWidgets('a guest sees the sign-in prompt, no Done button, and no repository call', (tester) async {
    app_state.prismUser = app_constants.createGuestPrismUser();
    final FavouriteWallEntity wall = _wall();
    final _FakeFoldersRepository repo = _FakeFoldersRepository(folders: <FolderEntity>[_folder('blue', 'Blue')]);
    final FoldersBloc bloc = FoldersBloc(repo);
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
    final FoldersBloc bloc = FoldersBloc(repo);
    addTearDown(bloc.close);
    await openSheet(tester, bloc, wall);

    expect(tester.widget<PrismButton>(find.widgetWithText(PrismButton, 'Done')).onPressed, isNull);

    gate.complete();
    await settle(tester);

    expect(tester.widget<PrismButton>(find.widgetWithText(PrismButton, 'Done')).onPressed, isNotNull);
  });

  testWidgets('failed folder loading keeps Done disabled until retry succeeds', (tester) async {
    final repo = _FakeFoldersRepository(folders: <FolderEntity>[_folder('blue', 'Blue')])..failLoad = true;
    final bloc = FoldersBloc(repo);
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
    final repo = _FakeFoldersRepository();
    final bloc = FoldersBloc(repo);
    addTearDown(bloc.close);
    await openSheet(tester, bloc, _wall());
    await tester.enterText(find.byType(TextField), 'Private draft');
    await tester.tap(find.byTooltip('Create folder'));
    await settle(tester);
    expect(find.text('Private draft'), findsOneWidget);

    app_state.prismUser = app_constants.createGuestPrismUser()..id = 'u2';
    bloc.add(const FoldersEvent.started(userId: 'u2'));
    await settle(tester);

    expect(find.byType(FolderSheet), findsNothing);
    expect(repo.calls.where((call) => call.startsWith('createFolder:')), isEmpty);
    verifyNever(() => toggleUseCase(any()));
  });

  testWidgets('switching accounts during the first load closes the original picker', (tester) async {
    final gate = Completer<void>();
    final repo = _FakeFoldersRepository()..loadGate = gate;
    final bloc = FoldersBloc(repo);
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
    final bloc = FoldersBloc(repo);
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
    final bloc = FoldersBloc(repo);
    addTearDown(bloc.close);
    await openSheet(tester, bloc, _wall());
    await tester.tap(find.text('Blue'));
    await tester.tap(find.text('Done'));
    await settle(tester);

    verify(() => toggleUseCase(any())).called(1);
    expect(repo.calls.where((call) => call.startsWith('addItem:')), isEmpty);
  });

  testWidgets('opening a picker during an existing folder load waits and then loads membership', (tester) async {
    final gate = Completer<void>();
    final repo = _FakeFoldersRepository(folders: <FolderEntity>[_folder('blue', 'Blue')])..loadGate = gate;
    final bloc = FoldersBloc(repo);
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

  testWidgets('clear then a new account closes only the picker, not the page beneath it', (tester) async {
    final repo = _FakeFoldersRepository();
    final bloc = FoldersBloc(repo);
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
    final bloc = FoldersBloc(repo);
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
}
