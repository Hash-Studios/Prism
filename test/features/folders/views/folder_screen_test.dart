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
import 'package:Prism/features/folders/domain/entities/folder_member.dart';
import 'package:Prism/features/folders/domain/entities/public_folder_entity.dart';
import 'package:Prism/features/folders/domain/repositories/folders_repository.dart';
import 'package:Prism/features/folders/domain/repositories/public_folders_repository.dart';
import 'package:Prism/features/folders/domain/repositories/shared_folders_repository.dart';
import 'package:Prism/features/folders/views/pages/folder_screen.dart';
import 'package:Prism/features/folders/views/widgets/folder_members_row.dart';
import 'package:Prism/features/ios_shortcuts/data/ios_shortcuts_support.dart';
import 'package:Prism/features/public_profile/domain/entities/public_profile_entity.dart';
import 'package:Prism/features/public_profile/domain/repositories/public_profile_repository.dart';
import 'package:Prism/l10n/l10n.dart';
import 'package:Prism/theme/theme.dart';
import 'package:auto_route/auto_route.dart';
import 'package:bloc_test/bloc_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockStackRouter extends Mock implements StackRouter {}

class _MockAutoRotateBloc extends MockBloc<AutoRotateEvent, AutoRotateState> implements AutoRotateBloc {}

class _MockSharedFoldersRepository extends Mock implements SharedFoldersRepository {}

class _MockPublicProfileRepository extends Mock implements PublicProfileRepository {}

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
  Future<Result<void>> addItem(FolderEntity folder, FavouriteWallEntity wall, {required String userId}) async {
    calls.add('addItem:${folder.id}');
    return Result.success<void>(null);
  }

  @override
  Future<Result<void>> removeItem(FolderEntity folder, FavouriteWallEntity wall, {required String userId}) async {
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

const PublicProfileEntity _anaProfile = PublicProfileEntity(
  id: 'owner',
  name: 'Ana',
  email: '',
  username: 'ana',
  profilePhoto: '',
  bio: '',
  links: <String, String>{},
  coverPhoto: '',
);

FolderMember _editor(String uid, String addedBy) =>
    FolderMember(uid: uid, role: FolderRole.editor, addedBy: addedBy, addedAt: _at);

FolderEntity _teamFolder({required String ownerId, List<FolderMember> editors = const <FolderMember>[]}) =>
    FolderEntity(
      id: 'work',
      ownerId: ownerId,
      name: 'Work',
      createdAt: _at,
      updatedAt: _at,
      itemCount: 2,
      covers: const <String>[],
      editors: editors,
    );

PrismFavouriteWall _wall(String id) => PrismFavouriteWall(
  id: id,
  wallpaper: PrismWallpaper(
    core: WallpaperCore(id: id, source: WallpaperSource.prism, fullUrl: '', thumbnailUrl: ''),
  ),
);

/// A menu entry of the folder's overflow menu, by its label.
Finder _menuItem(String label) =>
    find.ancestor(of: find.text(label), matching: find.byWidgetPredicate((widget) => widget is PopupMenuItem));

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
  final Future<int?> Function() originalIosMajorVersion = iosMajorVersion;

  tearDown(() {
    iosMajorVersion = originalIosMajorVersion;
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
    final bloc = FoldersBloc(repo, _NoPublicFolders());
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
    // Both accounts have a folder with this id, so the page loads it as the owner each time.
    final repo = _FakeFoldersRepository(folders: <FolderEntity>[_folder('work', 'Work')]);
    final bloc = FoldersBloc(repo, _NoPublicFolders());
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
              value: _rotationBloc(),
              child: const FolderScreen(folderId: 'work'),
            ),
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
    final bloc = FoldersBloc(repo, _NoPublicFolders());
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
    final bloc = FoldersBloc(repo, _NoPublicFolders());
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

  Future<({_FakeFoldersRepository repo, _MockSharedFoldersRepository shared})> pumpTeamFolder(
    WidgetTester tester, {
    required String userId,
    required FolderEntity folder,
    List<FavouriteWallEntity> walls = const <FavouriteWallEntity>[],
    String addedByUid = 'owner',
  }) async {
    app_state.prismUser = app_constants.createGuestPrismUser()..id = userId;
    getIt.registerSingleton<ConnectivityService>(_OnlineConnectivity());
    final _MockSharedFoldersRepository shared = _MockSharedFoldersRepository();
    when(() => shared.addedBy(any(), any())).thenAnswer((_) async => Result.success<String?>(addedByUid));
    when(() => shared.removeMember(any(), any())).thenAnswer((_) async => Result.success<void>(null));
    final _MockPublicProfileRepository profiles = _MockPublicProfileRepository();
    when(() => profiles.watchProfile(any())).thenAnswer(
      (invocation) =>
          Stream<PublicProfileEntity?>.value(invocation.positionalArguments.first == 'owner' ? _anaProfile : null),
    );
    getIt.registerSingleton<SharedFoldersRepository>(shared);
    getIt.registerSingleton<PublicProfileRepository>(profiles);
    addTearDown(getIt.reset);
    final _FakeFoldersRepository repo = _FakeFoldersRepository(folders: <FolderEntity>[folder])
      ..items = <String, List<FavouriteWallEntity>>{folder.id: walls};
    final FoldersBloc bloc = FoldersBloc(repo, _NoPublicFolders());
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
              value: _rotationBloc(),
              child: FolderScreen(folderId: folder.id),
            ),
          ),
        ),
      ),
    );
    await settle(tester);
    return (repo: repo, shared: shared);
  }

  testWidgets('the owner of a folder with an editor sees Invite in the header and the owner actions in the menu', (
    tester,
  ) async {
    await pumpTeamFolder(
      tester,
      userId: 'me',
      folder: _teamFolder(ownerId: 'me', editors: <FolderMember>[_editor('friend', 'me')]),
    );

    expect(find.text('2 people'), findsOneWidget);
    expect(find.descendant(of: find.byType(FolderMembersRow), matching: find.text('Invite')), findsOneWidget);

    await tester.tap(find.byIcon(Icons.more_vert_rounded));
    await settle(tester);

    for (final String label in <String>['Rotate this folder', 'Invite', 'People', 'Make public', 'Rename', 'Delete']) {
      expect(_menuItem(label), findsOneWidget, reason: label);
    }
  }, variant: TargetPlatformVariant.only(TargetPlatform.android));

  testWidgets('an editor sees People in the menu and no owner actions or Invite button', (tester) async {
    await pumpTeamFolder(
      tester,
      userId: 'me',
      folder: _teamFolder(ownerId: 'owner', editors: <FolderMember>[_editor('me', 'owner')]),
    );

    expect(find.text('2 people'), findsOneWidget);
    expect(find.descendant(of: find.byType(FolderMembersRow), matching: find.text('Invite')), findsNothing);

    await tester.tap(find.byIcon(Icons.more_vert_rounded));
    await settle(tester);

    expect(_menuItem('People'), findsOneWidget);
    for (final String label in <String>['Rotate this folder', 'Invite', 'Make public', 'Rename', 'Delete']) {
      expect(_menuItem(label), findsNothing, reason: label);
    }
  }, variant: TargetPlatformVariant.only(TargetPlatform.android));

  testWidgets('removing an editor reloads the open folder items', (tester) async {
    final result = await pumpTeamFolder(
      tester,
      userId: 'me',
      folder: _teamFolder(ownerId: 'me', editors: <FolderMember>[_editor('friend', 'me')]),
      walls: <FavouriteWallEntity>[_wall('wall-1')],
    );
    final _FakeFoldersRepository repo = result.repo;
    final _MockSharedFoldersRepository shared = result.shared;
    final Finder wallTile = find.byType(PrismWallTile);
    expect(wallTile, findsOneWidget);

    await tester.tap(find.text('2 people'));
    await settle(tester);
    await tester.tap(find.text('Remove').first);
    await settle(tester);
    await tester.tap(find.text('Remove person'));
    await settle(tester);

    verify(() => shared.removeMember('work', 'friend')).called(1);
    expect(repo.calls.where((call) => call == 'fetchItems:work'), hasLength(2));
    expect(find.text('2 people'), findsOneWidget);
    expect(wallTile, findsOneWidget);
  });

  testWidgets('an editor long-press on a wall names the editor who added it', (tester) async {
    await pumpTeamFolder(
      tester,
      userId: 'me',
      folder: _teamFolder(ownerId: 'owner', editors: <FolderMember>[_editor('me', 'owner')]),
      walls: <FavouriteWallEntity>[_wall('w1')],
    );

    await tester.longPress(find.byType(PrismWallTile));
    await settle(tester);

    expect(find.text('Remove from folder'), findsOneWidget);
    expect(find.text('Added by Ana'), findsOneWidget);
  });

  testWidgets('an editor long-press on their own wall says Added by you', (tester) async {
    await pumpTeamFolder(
      tester,
      userId: 'me',
      folder: _teamFolder(ownerId: 'owner', editors: <FolderMember>[_editor('me', 'owner')]),
      walls: <FavouriteWallEntity>[_wall('w1')],
      addedByUid: 'me',
    );

    await tester.longPress(find.byType(PrismWallTile));
    await settle(tester);

    expect(find.text('Added by you'), findsOneWidget);
    expect(find.text('Remove from folder'), findsOneWidget);
  });

  testWidgets('a solo owner long-press on a wall still asks to remove it from this folder', (tester) async {
    await pumpTeamFolder(
      tester,
      userId: 'me',
      folder: _teamFolder(ownerId: 'me'),
      walls: <FavouriteWallEntity>[_wall('w1')],
    );

    await tester.longPress(find.byType(PrismWallTile));
    await settle(tester);

    expect(find.text('Remove from this folder?'), findsOneWidget);
  });

  testWidgets('deleting a folder with editors warns that the people you invited lose it', (tester) async {
    await pumpTeamFolder(
      tester,
      userId: 'me',
      folder: _teamFolder(ownerId: 'me', editors: <FolderMember>[_editor('friend', 'me')]),
    );

    await tester.tap(find.byIcon(Icons.more_vert_rounded));
    await settle(tester);
    await tester.tap(_menuItem('Delete'));
    await settle(tester);

    expect(
      find.text('The people you invited lose it too. Wallpapers that are in your favourites stay there.'),
      findsOneWidget,
    );
  });

  testWidgets('the editor view with walls fits at large text on a 375 point phone', (tester) async {
    tester.view.physicalSize = const Size(375, 812);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    tester.platformDispatcher.textScaleFactorTestValue = 2.0;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    await pumpTeamFolder(
      tester,
      userId: 'me',
      folder: _teamFolder(ownerId: 'owner', editors: <FolderMember>[_editor('me', 'owner')]),
      walls: <FavouriteWallEntity>[_wall('w1'), _wall('w2')],
    );

    expect(tester.takeException(), isNull);
    expect(find.text('2 people'), findsOneWidget);
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
    final bloc = FoldersBloc(repo, _NoPublicFolders());
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

  testWidgets('the folder path shows Rotate this folder daily on iOS 17 with the user own folder', (tester) async {
    iosMajorVersion = () async => 17;
    await pumpFolderPage(tester, folderId: 'work', rotation: AutoRotateState.initial());

    await tester.tap(find.byIcon(Icons.more_vert_rounded));
    await settle(tester);

    expect(find.text('Rotate this folder daily'), findsOneWidget);
  }, variant: TargetPlatformVariant.only(TargetPlatform.iOS));

  testWidgets('the Android overflow menu does not offer Rotate this folder daily', (tester) async {
    iosMajorVersion = () async => 17;
    await pumpFolderPage(tester, folderId: 'work', rotation: AutoRotateState.initial());

    await tester.tap(find.byIcon(Icons.more_vert_rounded));
    await settle(tester);

    expect(find.text('Rotate this folder daily'), findsNothing);
  }, variant: TargetPlatformVariant.only(TargetPlatform.android));

  testWidgets('the iOS 15 overflow menu does not offer Rotate this folder daily', (tester) async {
    iosMajorVersion = () async => 15;
    await pumpFolderPage(tester, folderId: 'work', rotation: AutoRotateState.initial());

    await tester.tap(find.byIcon(Icons.more_vert_rounded));
    await settle(tester);

    expect(find.text('Rename'), findsOneWidget);
    expect(find.text('Rotate this folder daily'), findsNothing);
  }, variant: TargetPlatformVariant.only(TargetPlatform.iOS));

  testWidgets('the folder page hides Rotating when rotation uses another folder', (tester) async {
    await pumpFolderPage(
      tester,
      folderId: 'work',
      rotation: _rotatingState(enabled: true, folderId: 'trips'),
    );

    expect(find.text('Rotating'), findsNothing);
  }, variant: TargetPlatformVariant.only(TargetPlatform.android));
}
