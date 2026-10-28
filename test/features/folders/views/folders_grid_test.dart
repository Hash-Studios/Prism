import 'package:Prism/core/constants/app_constants.dart' as app_constants;
import 'package:Prism/core/error/failure.dart';
import 'package:Prism/core/router/app_router.dart';
import 'package:Prism/core/state/app_state.dart' as app_state;
import 'package:Prism/core/utils/result.dart';
import 'package:Prism/core/widgets/prism/prism_ui.dart';
import 'package:Prism/features/favourite_walls/domain/entities/favourite_wall_entity.dart';
import 'package:Prism/features/folders/biz/bloc/folders_bloc.j.dart';
import 'package:Prism/features/folders/domain/entities/folder_entity.dart';
import 'package:Prism/features/folders/domain/entities/public_folder_entity.dart';
import 'package:Prism/features/folders/domain/repositories/folders_repository.dart';
import 'package:Prism/features/folders/domain/repositories/public_folders_repository.dart';
import 'package:Prism/features/folders/views/widgets/folders_grid.dart';
import 'package:Prism/l10n/generated/app_localizations_en.dart';
import 'package:Prism/l10n/l10n.dart';
import 'package:Prism/theme/theme.dart';
import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockStackRouter extends Mock implements StackRouter {}

class _FakeFoldersRepository implements FoldersRepository {
  _FakeFoldersRepository({this.folders = const <FolderEntity>[]});

  final List<FolderEntity> folders;
  bool failLoad = false;

  /// One entry per repository call.
  final List<String> calls = <String>[];

  @override
  Stream<FolderWriteFailure> get writeFailures => const Stream.empty();

  @override
  int get writeRevision => 0;

  @override
  Future<Result<List<FolderEntity>>> fetchFolders(String userId) async {
    calls.add('fetchFolders:$userId');
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
    return Result.success(<String>{});
  }

  @override
  Future<Result<void>> createFolder(FolderEntity folder, {FavouriteWallEntity? firstWall}) async {
    calls.add('createFolder:${folder.name}');
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
    return Result.success<void>(null);
  }

  @override
  Future<Result<void>> removeItem(FolderEntity folder, FavouriteWallEntity wall) async {
    calls.add('removeItem:${folder.id}');
    return Result.success<void>(null);
  }
}

final DateTime _at = DateTime.utc(2026, 10);

FolderEntity _folder(String id, String name, {int itemCount = 0, List<String> covers = const <String>[]}) =>
    FolderEntity(
      id: id,
      ownerId: 'u1',
      name: name,
      createdAt: _at,
      updatedAt: _at,
      itemCount: itemCount,
      covers: covers,
    );

List<String> _urls(int count) => List<String>.generate(count, (i) => 'https://example.com/$i.jpg');

class _NoPublicFolders implements PublicFoldersRepository {
  @override
  Future<Result<PublicFolderEntity?>> fetchFolder(String folderId) async => Result.success<PublicFolderEntity?>(null);

  @override
  Future<Result<List<String>>> fetchWallIds(String folderId) async => Result.success(<String>[]);

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
  setUpAll(() => registerFallbackValue(FolderRoute(folderId: 'x')));

  tearDown(() {
    app_state.prismUser = app_constants.createGuestPrismUser();
  });

  // The folder list loads from the fake repository; pump a fixed time rather than settle.
  Future<void> settle(WidgetTester tester) async {
    for (int i = 0; i < 4; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
  }

  Future<FoldersBloc> pumpGrid(
    WidgetTester tester,
    _FakeFoldersRepository repo, {
    bool signedIn = true,
    _MockStackRouter? router,
  }) async {
    app_state.prismUser = signedIn
        ? (app_constants.createGuestPrismUser()..id = 'u1')
        : app_constants.createGuestPrismUser();
    final FoldersBloc bloc = FoldersBloc(repo, _NoPublicFolders());
    addTearDown(bloc.close);
    final _MockStackRouter stackRouter = router ?? _MockStackRouter();
    when(() => stackRouter.push(any())).thenAnswer((_) async => null);
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        theme: kLightTheme,
        home: StackRouterScope(
          controller: stackRouter,
          stateHash: 0,
          child: BlocProvider<FoldersBloc>.value(
            value: bloc,
            child: const Scaffold(body: FoldersGrid()),
          ),
        ),
      ),
    );
    await settle(tester);
    return bloc;
  }

  testWidgets('a guest sees the sign-in prompt for folders', (tester) async {
    final _FakeFoldersRepository repo = _FakeFoldersRepository(folders: <FolderEntity>[_folder('work', 'Work')]);
    await pumpGrid(tester, repo, signedIn: false);

    expect(
      find.text(AppLocalizationsEn().coreSignInFeatureTitle(AppLocalizationsEn().foldersSignInFeature)),
      findsOneWidget,
    );
    expect(find.byType(SliverGrid), findsNothing);
    expect(repo.calls.where((call) => call.startsWith('fetchFolders:')), isEmpty);
  });

  testWidgets('renders nothing when no FoldersBloc is provided', (tester) async {
    app_state.prismUser = app_constants.createGuestPrismUser()..id = 'u1';
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        theme: kLightTheme,
        home: const Scaffold(body: FoldersGrid()),
      ),
    );
    await settle(tester);

    expect(find.byType(SliverGrid), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('a guest sees the sign-in prompt even when no FoldersBloc is provided', (tester) async {
    app_state.prismUser = app_constants.createGuestPrismUser();
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        theme: kLightTheme,
        home: const Scaffold(body: FoldersGrid()),
      ),
    );

    expect(
      find.text(AppLocalizationsEn().coreSignInFeatureTitle(AppLocalizationsEn().foldersSignInFeature)),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('signed in with no folders shows the empty state and opens the name sheet on New folder', (tester) async {
    final _FakeFoldersRepository repo = _FakeFoldersRepository();
    await pumpGrid(tester, repo);

    expect(find.text('No folders yet'), findsOneWidget);
    expect(find.text('Hold the heart on a wallpaper to save it to a folder.'), findsOneWidget);
    expect(find.text('New folder'), findsOneWidget);

    await tester.tap(find.text('New folder'));
    await settle(tester);

    expect(find.text('New folder'), findsNWidgets(2));
    expect(find.text('Folder name'), findsOneWidget);
    expect(repo.calls.where((call) => call.startsWith('createFolder:')), isEmpty);
  });

  testWidgets('a failed load shows the error and Try again calls fetchFolders again', (tester) async {
    final _FakeFoldersRepository repo = _FakeFoldersRepository()..failLoad = true;
    await pumpGrid(tester, repo);

    expect(find.text('Could not load your folders'), findsOneWidget);
    expect(find.text('Try again'), findsOneWidget);
    expect(repo.calls.where((call) => call == 'fetchFolders:u1'), hasLength(1));

    await tester.tap(find.text('Try again'));
    await settle(tester);

    expect(repo.calls.where((call) => call == 'fetchFolders:u1'), hasLength(2));
  });

  testWidgets('a failed refresh shows the error instead of presenting stale folders as current', (tester) async {
    final _FakeFoldersRepository repo = _FakeFoldersRepository(folders: <FolderEntity>[_folder('work', 'Work')]);
    final FoldersBloc bloc = await pumpGrid(tester, repo);

    repo.failLoad = true;
    await bloc.run((id) => FoldersEvent.started(userId: 'u1', operationId: id));
    await settle(tester);

    expect(find.text('Could not load your folders'), findsOneWidget);
    expect(find.text('Try again'), findsOneWidget);
    expect(find.text('Work'), findsNothing);

    repo.failLoad = false;
    await tester.tap(find.text('Try again'));
    await settle(tester);

    expect(find.text('Work'), findsOneWidget);
    expect(find.text('Could not load your folders'), findsNothing);
  });

  testWidgets('signed in with folders shows a card per folder with its count and no New folder tile', (tester) async {
    final _FakeFoldersRepository repo = _FakeFoldersRepository(
      folders: <FolderEntity>[
        _folder('work', 'Work'),
        _folder('trips', 'Trips', itemCount: 1, covers: _urls(1)),
        _folder('gym', 'Gym', itemCount: 7, covers: _urls(4)),
      ],
    );
    await pumpGrid(tester, repo);

    expect(find.byType(SliverGrid), findsOneWidget);
    expect(find.text('Work'), findsOneWidget);
    expect(find.text('Trips'), findsOneWidget);
    expect(find.text('Gym'), findsOneWidget);
    expect(find.text('No wallpapers'), findsOneWidget);
    expect(find.text('1 wallpaper'), findsOneWidget);
    expect(find.text('7 wallpapers'), findsOneWidget);
    expect(find.text('New folder'), findsNothing);
  });

  testWidgets('each folder card is a button labelled with its name and count', (tester) async {
    final SemanticsHandle handle = tester.ensureSemantics();
    await pumpGrid(tester, _FakeFoldersRepository(folders: <FolderEntity>[_folder('trips', 'Trips', itemCount: 7)]));

    expect(
      tester.getSemantics(find.bySemanticsLabel('Trips')),
      isSemantics(label: 'Trips', value: '7 wallpapers', isButton: true, hasTapAction: true),
    );
    handle.dispose();
  });

  testWidgets('a 390 px phone shows two folder columns', (tester) async {
    tester.view.physicalSize = const Size(1170, 2532);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await pumpGrid(
      tester,
      _FakeFoldersRepository(
        folders: <FolderEntity>[
          _folder('work', 'Work'),
          _folder('trips', 'Trips'),
          _folder('gym', 'Gym'),
          _folder('music', 'Music'),
        ],
      ),
    );

    final double workTop = tester.getTopLeft(find.text('Work')).dy;
    expect(tester.getTopLeft(find.text('Trips')).dy, workTop);
    expect(tester.getTopLeft(find.text('Gym')).dy, greaterThan(workTop));
  });

  testWidgets('an 834 px tablet shows four folder columns', (tester) async {
    tester.view.physicalSize = const Size(1668, 2388);
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await pumpGrid(
      tester,
      _FakeFoldersRepository(
        folders: <FolderEntity>[
          _folder('work', 'Work'),
          _folder('trips', 'Trips'),
          _folder('gym', 'Gym'),
          _folder('music', 'Music'),
          _folder('books', 'Books'),
        ],
      ),
    );

    final double workTop = tester.getTopLeft(find.text('Work')).dy;
    for (final String name in <String>['Trips', 'Gym', 'Music']) {
      expect(tester.getTopLeft(find.text(name)).dy, workTop);
    }
    expect(tester.getTopLeft(find.text('Books')).dy, greaterThan(workTop));
  });

  testWidgets('tapping a folder card pushes its folder route', (tester) async {
    final _MockStackRouter router = _MockStackRouter();
    await pumpGrid(
      tester,
      _FakeFoldersRepository(folders: <FolderEntity>[_folder('f1', 'Trips', itemCount: 7)]),
      router: router,
    );

    await tester.tap(find.text('Trips'));
    await tester.pump();

    verify(() => router.push(any(that: isA<FolderRoute>().having((r) => r.args?.folderId, 'id', 'f1')))).called(1);
  });

  testWidgets('a name prompt opened by one account cannot create a folder for the next account', (tester) async {
    final _FakeFoldersRepository repo = _FakeFoldersRepository();
    final FoldersBloc bloc = await pumpGrid(tester, repo);
    await tester.tap(find.text('New folder'));
    await settle(tester);
    await tester.enterText(find.byType(TextField), 'Private draft');
    app_state.prismUser = app_constants.createGuestPrismUser()..id = 'u2';
    bloc.add(const FoldersEvent.started(userId: 'u2'));
    await settle(tester);
    await tester.tap(find.text('Create'));
    await settle(tester);

    expect(repo.calls.where((call) => call.startsWith('createFolder:')), isEmpty);
  });

  testWidgets('a mounted grid hides on sign-out and returns after signing in again', (tester) async {
    final FoldersBloc bloc = await pumpGrid(
      tester,
      _FakeFoldersRepository(folders: <FolderEntity>[_folder('work', 'Work')]),
    );
    expect(find.text('Work'), findsOneWidget);

    app_state.prismUser = app_constants.createGuestPrismUser();
    bloc.add(const FoldersEvent.cleared());
    await settle(tester);
    expect(
      find.text(AppLocalizationsEn().coreSignInFeatureTitle(AppLocalizationsEn().foldersSignInFeature)),
      findsOneWidget,
    );
    expect(find.text('Work'), findsNothing);

    app_state.prismUser = app_constants.createGuestPrismUser()..id = 'u2';
    bloc.add(const FoldersEvent.started(userId: 'u2'));
    await settle(tester);
    expect(find.text('Work'), findsOneWidget);
  });

  testWidgets('after an account switch the grid hides the last account folders until it reloads', (tester) async {
    await pumpGrid(tester, _FakeFoldersRepository(folders: <FolderEntity>[_folder('work', 'Work')]));
    expect(find.text('Work'), findsOneWidget);

    app_state.prismUser = app_constants.createGuestPrismUser()..id = 'u2';
    tester.element(find.byType(FoldersGrid)).markNeedsBuild();
    await tester.pump();

    expect(find.text('Work'), findsNothing);
    expect(find.byType(PrismBone), findsWidgets);
  });

  testWidgets('folder cards fit their name and count at a large nonlinear text size', (tester) async {
    tester.view.physicalSize = const Size(1170, 2532);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    tester.platformDispatcher.textScaleFactorTestValue = 2.2;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    await pumpGrid(
      tester,
      _FakeFoldersRepository(folders: <FolderEntity>[_folder('work', 'Work', itemCount: 3, covers: _urls(3))]),
    );

    expect(tester.takeException(), isNull);
    final Rect card = tester.getRect(find.bySemanticsLabel('Work'));
    expect(tester.getBottomLeft(find.text('3 wallpapers')).dy, lessThanOrEqualTo(card.bottom));
  });

  testWidgets('folder cards fit their name and count with a large accessibility line height', (tester) async {
    tester.view.physicalSize = const Size(1170, 2532);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    tester.platformDispatcher.lineHeightScaleFactorOverrideTestValue = 3;
    addTearDown(tester.platformDispatcher.clearLineHeightScaleFactorOverrideTestValue);
    await pumpGrid(
      tester,
      _FakeFoldersRepository(folders: <FolderEntity>[_folder('work', 'Work', itemCount: 3, covers: _urls(3))]),
    );

    expect(tester.takeException(), isNull);
    final Rect card = tester.getRect(find.bySemanticsLabel('Work'));
    expect(tester.getBottomLeft(find.text('3 wallpapers')).dy, lessThanOrEqualTo(card.bottom));
  });
}
