import 'package:Prism/core/constants/app_constants.dart' as app_constants;
import 'package:Prism/core/di/injection.dart';
import 'package:Prism/core/error/failure.dart';
import 'package:Prism/core/network/connectivity_service.dart';
import 'package:Prism/core/state/app_state.dart' as app_state;
import 'package:Prism/core/utils/result.dart';
import 'package:Prism/core/wallpaper/wallpaper_core.dart';
import 'package:Prism/core/wallpaper/wallpaper_source.dart';
import 'package:Prism/core/wallpaper/wallpaper_variants.dart';
import 'package:Prism/core/widgets/prism/prism_ui.dart';
import 'package:Prism/features/auto_rotate/biz/bloc/auto_rotate_bloc.j.dart';
import 'package:Prism/features/auto_rotate/domain/entities/auto_rotate_config.dart';
import 'package:Prism/features/favourite_walls/domain/entities/favourite_wall_entity.dart';
import 'package:Prism/features/folders/biz/bloc/folders_bloc.j.dart';
import 'package:Prism/features/folders/domain/entities/folder_entity.dart';
import 'package:Prism/features/folders/domain/repositories/folders_repository.dart';
import 'package:Prism/features/folders/views/pages/folder_screen.dart';
import 'package:Prism/l10n/l10n.dart';
import 'package:Prism/theme/theme.dart';
import 'package:auto_route/auto_route.dart';
import 'package:bloc_test/bloc_test.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockStackRouter extends Mock implements StackRouter {}

class _MockAutoRotateBloc extends MockBloc<AutoRotateEvent, AutoRotateState> implements AutoRotateBloc {}

class _OnlineConnectivity implements ConnectivityService {
  @override
  Future<bool> hasConnection() async => true;

  @override
  Stream<bool> get onConnectionChange => const Stream<bool>.empty();
}

class _FakeFoldersRepository implements FoldersRepository {
  _FakeFoldersRepository({this.folders = const <FolderEntity>[]});

  final List<FolderEntity> folders;
  Map<String, List<FavouriteWallEntity>> items = <String, List<FavouriteWallEntity>>{};
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
    return Result.success(items[folderId] ?? const <FavouriteWallEntity>[]);
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

_MockAutoRotateBloc _rotationBloc([AutoRotateState? state]) {
  final _MockAutoRotateBloc bloc = _MockAutoRotateBloc();
  when(() => bloc.state).thenReturn(state ?? AutoRotateState.initial());
  return bloc;
}

AutoRotateState _rotatingState({required bool enabled, required String folderId}) => AutoRotateState.initial().copyWith(
  config: AutoRotateConfig(enabled: enabled, source: AutoRotateSource.folder, folderId: folderId, folderName: 'Work'),
);

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
          child: BlocProvider<AutoRotateBloc>.value(
            value: _rotationBloc(),
            child: const FolderScreen(folderId: 'work'),
          ),
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
          child: BlocProvider<AutoRotateBloc>.value(
            value: _rotationBloc(),
            child: const FolderScreen(folderId: 'work'),
          ),
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

  testWidgets('a folder page reused for another folder loads and shows that folder', (tester) async {
    app_state.prismUser = app_constants.createGuestPrismUser()..id = 'u1';
    getIt.registerSingleton<ConnectivityService>(_OnlineConnectivity());
    addTearDown(() => getIt.unregister<ConnectivityService>());
    final repo = _FakeFoldersRepository(folders: <FolderEntity>[_folder('work', 'Work'), _folder('trips', 'Trips')]);
    final bloc = FoldersBloc(repo);
    addTearDown(bloc.close);
    final _MockStackRouter router = _MockStackRouter();
    when(() => router.stack).thenReturn(const <AutoRoutePage<dynamic>>[]);
    Widget page(String folderId) => MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      theme: kLightTheme,
      home: StackRouterScope(
        controller: router,
        stateHash: 0,
        child: BlocProvider<FoldersBloc>.value(
          value: bloc,
          child: BlocProvider<AutoRotateBloc>.value(
            value: _rotationBloc(),
            child: FolderScreen(folderId: folderId),
          ),
        ),
      ),
    );
    await tester.pumpWidget(page('work'));
    await settle(tester);
    expect(find.text('Work'), findsOneWidget);

    await tester.pumpWidget(page('trips'));
    await settle(tester);
    expect(repo.calls, contains('fetchItems:trips'));
    expect(find.text('Trips'), findsOneWidget);
    expect(find.text('Work'), findsNothing);
  });

  testWidgets('a remove confirmed after the page moved to another folder removes nothing', (tester) async {
    app_state.prismUser = app_constants.createGuestPrismUser()..id = 'u1';
    getIt.registerSingleton<ConnectivityService>(_OnlineConnectivity());
    addTearDown(() => getIt.unregister<ConnectivityService>());
    const FavouriteWallEntity wall = PrismFavouriteWall(
      id: 'wall_1',
      wallpaper: PrismWallpaper(
        core: WallpaperCore(id: 'wall_1', source: WallpaperSource.prism, fullUrl: '', thumbnailUrl: ''),
      ),
    );
    final repo = _FakeFoldersRepository(
      folders: <FolderEntity>[_folder('work', 'Work', itemCount: 1), _folder('trips', 'Trips', itemCount: 1)],
    );
    // The wall is in both folders, so a remove sent to the wrong folder would reach the repository.
    repo.items = <String, List<FavouriteWallEntity>>{
      'work': <FavouriteWallEntity>[wall],
      'trips': <FavouriteWallEntity>[wall],
    };
    final bloc = FoldersBloc(repo);
    addTearDown(bloc.close);
    final _MockStackRouter router = _MockStackRouter();
    when(() => router.stack).thenReturn(const <AutoRoutePage<dynamic>>[]);
    Widget page(String folderId) => MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      theme: kLightTheme,
      home: StackRouterScope(
        controller: router,
        stateHash: 0,
        child: BlocProvider<FoldersBloc>.value(
          value: bloc,
          child: BlocProvider<AutoRotateBloc>.value(
            value: _rotationBloc(),
            child: FolderScreen(folderId: folderId),
          ),
        ),
      ),
    );
    await tester.pumpWidget(page('work'));
    await settle(tester);
    await tester.longPress(find.byType(PrismWallTile));
    await settle(tester);
    expect(find.text('Remove from this folder?'), findsOneWidget);

    await tester.pumpWidget(page('trips'));
    await settle(tester);
    await tester.tap(find.text('Remove'));
    await settle(tester);
    expect(repo.calls.where((call) => call.startsWith('removeItem:')), isEmpty);
  });

  // The rotation tests run the folder page on one platform and pump it with a given rotation state.
  Future<void> pumpFolderPage(
    WidgetTester tester, {
    required String folderId,
    required AutoRotateState rotation,
  }) async {
    app_state.prismUser = app_constants.createGuestPrismUser()..id = 'u1';
    getIt.registerSingleton<ConnectivityService>(_OnlineConnectivity());
    addTearDown(() => getIt.unregister<ConnectivityService>());
    final repo = _FakeFoldersRepository(folders: <FolderEntity>[_folder('work', 'Work')]);
    final bloc = FoldersBloc(repo);
    addTearDown(bloc.close);
    final _MockStackRouter router = _MockStackRouter();
    when(() => router.stack).thenReturn(const <AutoRoutePage<dynamic>>[]);
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        theme: kLightTheme,
        home: StackRouterScope(
          controller: router,
          stateHash: 0,
          child: BlocProvider<FoldersBloc>.value(
            value: bloc,
            child: BlocProvider<AutoRotateBloc>.value(
              value: _rotationBloc(rotation),
              child: FolderScreen(folderId: folderId),
            ),
          ),
        ),
      ),
    );
    await settle(tester);
  }

  testWidgets('the Android overflow menu offers Rotate this folder', (tester) async {
    await pumpFolderPage(tester, folderId: 'work', rotation: AutoRotateState.initial());

    await tester.tap(find.byIcon(Icons.more_vert_rounded));
    await settle(tester);

    expect(find.text('Rotate this folder'), findsOneWidget);
  }, variant: TargetPlatformVariant.only(TargetPlatform.android));

  testWidgets('the iOS overflow menu does not offer Rotate this folder', (tester) async {
    await pumpFolderPage(tester, folderId: 'work', rotation: AutoRotateState.initial());

    await tester.tap(find.byIcon(Icons.more_vert_rounded));
    await settle(tester);

    expect(find.text('Rename'), findsOneWidget);
    expect(find.text('Rotate this folder'), findsNothing);
  }, variant: TargetPlatformVariant.only(TargetPlatform.iOS));

  testWidgets('the folder page shows Rotating while rotation uses this folder', (tester) async {
    await pumpFolderPage(
      tester,
      folderId: 'work',
      rotation: _rotatingState(enabled: true, folderId: 'work'),
    );

    expect(find.text('Rotating'), findsOneWidget);
  }, variant: TargetPlatformVariant.only(TargetPlatform.android));

  testWidgets('the folder page hides Rotating when rotation is off', (tester) async {
    await pumpFolderPage(
      tester,
      folderId: 'work',
      rotation: _rotatingState(enabled: false, folderId: 'work'),
    );

    expect(find.text('Rotating'), findsNothing);
  }, variant: TargetPlatformVariant.only(TargetPlatform.android));

  testWidgets('the folder page hides Rotating when rotation uses another folder', (tester) async {
    await pumpFolderPage(
      tester,
      folderId: 'work',
      rotation: _rotatingState(enabled: true, folderId: 'trips'),
    );

    expect(find.text('Rotating'), findsNothing);
  }, variant: TargetPlatformVariant.only(TargetPlatform.android));
}
