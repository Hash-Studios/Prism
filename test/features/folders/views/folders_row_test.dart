import 'package:Prism/core/constants/app_constants.dart' as app_constants;
import 'package:Prism/core/di/injection.dart';
import 'package:Prism/core/error/failure.dart';
import 'package:Prism/core/network/connectivity_service.dart';
import 'package:Prism/core/state/app_state.dart' as app_state;
import 'package:Prism/core/utils/result.dart';
import 'package:Prism/features/favourite_walls/domain/entities/favourite_wall_entity.dart';
import 'package:Prism/features/folders/biz/bloc/folders_bloc.j.dart';
import 'package:Prism/features/folders/domain/entities/folder_entity.dart';
import 'package:Prism/features/folders/domain/repositories/folders_repository.dart';
import 'package:Prism/features/folders/views/pages/folder_screen.dart';
import 'package:Prism/features/folders/views/widgets/folders_row.dart';
import 'package:Prism/l10n/l10n.dart';
import 'package:Prism/theme/theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';

class _OnlineConnectivity implements ConnectivityService {
  @override
  Future<bool> hasConnection() async => true;

  @override
  Stream<bool> get onConnectionChange => const Stream<bool>.empty();
}

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

FolderEntity _folder(String id, String name, {int itemCount = 0}) => FolderEntity(
  id: id,
  ownerId: 'u1',
  name: name,
  createdAt: _at,
  updatedAt: _at,
  itemCount: itemCount,
  covers: const <String>[],
);

void main() {
  tearDown(() {
    app_state.prismUser = app_constants.createGuestPrismUser();
  });

  // The folder list loads from the fake repository; pump a fixed time rather than settle.
  Future<void> settle(WidgetTester tester) async {
    for (int i = 0; i < 4; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
  }

  Future<FoldersBloc> pumpSignedIn(WidgetTester tester, _FakeFoldersRepository repo) async {
    app_state.prismUser = app_constants.createGuestPrismUser()..id = 'u1';
    final FoldersBloc bloc = FoldersBloc(repo);
    addTearDown(bloc.close);
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        theme: kLightTheme,
        home: BlocProvider<FoldersBloc>.value(
          value: bloc,
          child: const Scaffold(body: FoldersRow()),
        ),
      ),
    );
    await settle(tester);
    return bloc;
  }

  testWidgets('signed in with two folders shows the heading, New folder, and each folder with its count', (
    tester,
  ) async {
    final _FakeFoldersRepository repo = _FakeFoldersRepository(
      folders: <FolderEntity>[_folder('work', 'Work', itemCount: 3), _folder('trips', 'Trips', itemCount: 1)],
    );
    await pumpSignedIn(tester, repo);

    expect(find.text('Folders'), findsOneWidget);
    expect(find.text('New folder'), findsOneWidget);
    expect(find.text('Work'), findsOneWidget);
    expect(find.text('3 wallpapers'), findsOneWidget);
    expect(find.text('Trips'), findsOneWidget);
    expect(find.text('1 wallpaper'), findsOneWidget);
  });

  testWidgets('signed in with no folders shows New folder and the hint to sort walls into folders', (tester) async {
    await pumpSignedIn(tester, _FakeFoldersRepository());

    expect(find.text('New folder'), findsOneWidget);
    expect(find.text('Sort your saved wallpapers into folders.'), findsOneWidget);
  });

  testWidgets('a failed load shows a retry action, not the empty-folder hint', (tester) async {
    final repo = _FakeFoldersRepository(folders: <FolderEntity>[_folder('work', 'Work')])..failLoad = true;
    await pumpSignedIn(tester, repo);

    expect(find.text('Sort your saved wallpapers into folders.'), findsNothing);
    expect(find.text('Try again'), findsOneWidget);
    repo.failLoad = false;
    await tester.tap(find.text('Try again'));
    await settle(tester);

    expect(find.text('Work'), findsOneWidget);
    expect(repo.calls.where((call) => call == 'fetchFolders:u1'), hasLength(2));
  });

  testWidgets('a name prompt opened by one account cannot create a folder for the next account', (tester) async {
    final repo = _FakeFoldersRepository();
    final bloc = await pumpSignedIn(tester, repo);
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

  testWidgets('a folder page shows a load error with retry when the folder list fails', (tester) async {
    app_state.prismUser = app_constants.createGuestPrismUser()..id = 'u1';
    getIt.registerSingleton<ConnectivityService>(_OnlineConnectivity());
    addTearDown(() => getIt.unregister<ConnectivityService>());
    final repo = _FakeFoldersRepository()..failLoad = true;
    final bloc = FoldersBloc(repo);
    addTearDown(bloc.close);
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        theme: kLightTheme,
        home: BlocProvider<FoldersBloc>.value(
          value: bloc,
          child: const FolderScreen(folderId: 'work'),
        ),
      ),
    );
    await settle(tester);

    expect(find.text('Try again'), findsOneWidget);
    expect(find.text('Folder not found'), findsNothing);
    expect(repo.calls.where((call) => call.startsWith('fetchItems:')), isEmpty);
    await tester.tap(find.text('Try again'));
    await settle(tester);
    expect(repo.calls.where((call) => call == 'fetchFolders:u1'), hasLength(2));
  });

  testWidgets('a mounted folder page reloads its items after switching accounts and hides them on sign-out', (
    tester,
  ) async {
    app_state.prismUser = app_constants.createGuestPrismUser()..id = 'u1';
    getIt.registerSingleton<ConnectivityService>(_OnlineConnectivity());
    addTearDown(() => getIt.unregister<ConnectivityService>());
    final repo = _FakeFoldersRepository();
    final bloc = FoldersBloc(repo);
    addTearDown(bloc.close);
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        theme: kLightTheme,
        home: BlocProvider<FoldersBloc>.value(
          value: bloc,
          child: const FolderScreen(folderId: 'work'),
        ),
      ),
    );
    await settle(tester);
    expect(repo.calls.where((call) => call == 'fetchItems:work'), hasLength(1));

    app_state.prismUser = app_constants.createGuestPrismUser()..id = 'u2';
    bloc.add(const FoldersEvent.started(userId: 'u2'));
    await settle(tester);
    expect(repo.calls.where((call) => call == 'fetchItems:work'), hasLength(2));

    app_state.prismUser = app_constants.createGuestPrismUser();
    bloc.add(const FoldersEvent.cleared());
    await settle(tester);
    expect(find.text('Sign in to use folders'), findsOneWidget);
  });

  testWidgets('a guest sees no folders row and makes no repository call, with no FoldersBloc provided', (tester) async {
    app_state.prismUser = app_constants.createGuestPrismUser();
    final _FakeFoldersRepository repo = _FakeFoldersRepository(folders: <FolderEntity>[_folder('work', 'Work')]);
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        theme: kLightTheme,
        home: const Scaffold(body: FoldersRow()),
      ),
    );
    await settle(tester);

    expect(find.text('Folders'), findsNothing);
    expect(repo.calls, isEmpty);
  });

  testWidgets('each folder card has a semantics label equal to the folder name', (tester) async {
    final SemanticsHandle handle = tester.ensureSemantics();
    await pumpSignedIn(
      tester,
      _FakeFoldersRepository(
        folders: <FolderEntity>[_folder('work', 'Work', itemCount: 3), _folder('trips', 'Trips', itemCount: 1)],
      ),
    );

    expect(tester.getSemantics(find.bySemanticsLabel('Work')).label, 'Work');
    expect(tester.getSemantics(find.bySemanticsLabel('Trips')).label, 'Trips');
    handle.dispose();
  });

  testWidgets('a mounted row hides on sign-out and returns after signing in again', (tester) async {
    final bloc = await pumpSignedIn(tester, _FakeFoldersRepository());
    expect(find.text('Folders'), findsOneWidget);
    app_state.prismUser = app_constants.createGuestPrismUser();
    bloc.add(const FoldersEvent.cleared());
    await settle(tester);
    expect(find.text('Folders'), findsNothing);

    app_state.prismUser = app_constants.createGuestPrismUser()..id = 'u2';
    bloc.add(const FoldersEvent.started(userId: 'u2'));
    await settle(tester);
    expect(find.text('Folders'), findsOneWidget);
  });
}
