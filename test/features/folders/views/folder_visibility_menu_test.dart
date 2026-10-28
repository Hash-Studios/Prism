import 'package:Prism/core/constants/app_constants.dart' as app_constants;
import 'package:Prism/core/di/injection.dart';
import 'package:Prism/core/network/connectivity_service.dart';
import 'package:Prism/core/state/app_state.dart' as app_state;
import 'package:Prism/core/utils/result.dart';
import 'package:Prism/core/widgets/prism/prism_ui.dart';
import 'package:Prism/features/favourite_walls/domain/entities/favourite_wall_entity.dart';
import 'package:Prism/features/folders/biz/bloc/folders_bloc.j.dart';
import 'package:Prism/features/folders/domain/entities/folder_entity.dart';
import 'package:Prism/features/folders/domain/entities/public_folder_entity.dart';
import 'package:Prism/features/folders/domain/repositories/folders_repository.dart';
import 'package:Prism/features/folders/domain/repositories/public_folders_repository.dart';
import 'package:Prism/features/folders/views/pages/folder_screen.dart';
import 'package:Prism/l10n/l10n.dart';
import 'package:Prism/theme/theme.dart';
import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockStackRouter extends Mock implements StackRouter {}

class _OnlineConnectivity implements ConnectivityService {
  @override
  Future<bool> hasConnection() async => true;

  @override
  Stream<bool> get onConnectionChange => const Stream<bool>.empty();
}

class _FakeFoldersRepository implements FoldersRepository {
  _FakeFoldersRepository({this.folders = const <FolderEntity>[]});

  final List<FolderEntity> folders;

  @override
  Stream<FolderWriteFailure> get writeFailures => const Stream.empty();

  @override
  int get writeRevision => 0;

  @override
  Future<Result<List<FolderEntity>>> fetchFolders(String userId) async => Result.success(folders);

  @override
  Future<Result<List<FavouriteWallEntity>?>> fetchItems(String folderId, {required String userId, int? limit}) async =>
      Result.success(const <FavouriteWallEntity>[]);

  @override
  Future<Result<Set<String>>> foldersContaining(List<String> folderIds, String itemKey) async =>
      Result.success(<String>{});

  @override
  Future<Result<void>> createFolder(FolderEntity folder, {FavouriteWallEntity? firstWall}) async =>
      Result.success<void>(null);

  @override
  Future<Result<void>> renameFolder(FolderEntity folder) async => Result.success<void>(null);

  @override
  Future<Result<void>> deleteFolder(String folderId, {required String userId, bool Function()? isCancelled}) async =>
      Result.success<void>(null);

  @override
  Future<Result<void>> addItem(FolderEntity folder, FavouriteWallEntity wall) async => Result.success<void>(null);

  @override
  Future<Result<void>> removeItem(FolderEntity folder, FavouriteWallEntity wall) async => Result.success<void>(null);
}

class _FakePublicFoldersRepository implements PublicFoldersRepository {
  PublicFolderEntity? folder;

  /// One entry per setPublic call: the folder id and the requested state.
  final List<(String, bool)> setPublicCalls = <(String, bool)>[];

  @override
  Future<Result<PublicFolderEntity?>> fetchFolder(String folderId) async => Result.success(folder);

  @override
  Future<Result<List<String>>> fetchWallIds(String folderId) async => Result.success(const <String>[]);

  @override
  Future<Result<List<PublicFolderEntity>>> fetchOwnerFolders(String ownerId) async =>
      Result.success(const <PublicFolderEntity>[]);

  @override
  Future<Result<List<PublicFolderEntity>>> fetchFollowedFolders(String userId) async =>
      Result.success(const <PublicFolderEntity>[]);

  @override
  Future<Result<bool>> isFollowing(String folderId, String userId) async => Result.success(false);

  @override
  Future<Result<void>> setFollowing(String folderId, {required bool following}) async => Result.success<void>(null);

  @override
  Future<Result<bool>> setPublic(String folderId, {required bool isPublic}) async {
    setPublicCalls.add((folderId, isPublic));
    return Result.success(isPublic);
  }
}

final DateTime _at = DateTime.utc(2026, 10);

FolderEntity _folder({bool isPublic = false}) => FolderEntity(
  id: 'f1',
  ownerId: 'u1',
  name: 'Night Owl',
  createdAt: _at,
  updatedAt: _at,
  itemCount: 0,
  covers: const <String>[],
  isPublic: isPublic,
);

late _MockStackRouter _router;
late _FakePublicFoldersRepository _publicRepo;

Future<void> _pumpFolder(WidgetTester tester, FolderEntity folder) async {
  final _FakeFoldersRepository repo = _FakeFoldersRepository(folders: <FolderEntity>[folder]);
  final FoldersBloc bloc = FoldersBloc(repo, _publicRepo);
  addTearDown(bloc.close);
  await tester.pumpWidget(
    MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      theme: kLightTheme,
      home: StackRouterScope(
        controller: _router,
        stateHash: 0,
        child: BlocProvider<FoldersBloc>.value(
          value: bloc,
          child: const FolderScreen(folderId: 'f1'),
        ),
      ),
    ),
  );
  await _settle(tester);
}

// The folder list loads from the fake repository; pump a fixed time rather than settle.
Future<void> _settle(WidgetTester tester) async {
  for (int i = 0; i < 4; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

void main() {
  setUp(() {
    _router = _MockStackRouter();
    when(() => _router.stack).thenReturn(const <AutoRoutePage<dynamic>>[]);
    _publicRepo = _FakePublicFoldersRepository();
    app_state.prismUser = app_constants.createGuestPrismUser()..id = 'u1';
    getIt.registerSingleton<ConnectivityService>(_OnlineConnectivity());
    getIt.registerSingleton<PublicFoldersRepository>(_publicRepo);
  });

  tearDown(() async {
    app_state.prismUser = app_constants.createGuestPrismUser();
    await getIt.reset();
  });

  testWidgets('a private folder offers Make public, and confirming calls setPublic', (tester) async {
    _publicRepo.folder = null;
    await _pumpFolder(tester, _folder());

    await tester.tap(find.byTooltip('More options'));
    await _settle(tester);
    await tester.tap(find.text('Make public'));
    await _settle(tester);

    expect(find.text('Make this folder public?'), findsOneWidget);
    expect(find.text('Anyone on Prism can see its name and wallpapers, follow it and open its link.'), findsOneWidget);

    await tester.tap(find.widgetWithText(PrismButton, 'Make public'));
    await _settle(tester);

    expect(_publicRepo.setPublicCalls, <(String, bool)>[('f1', true)]);
  });

  testWidgets('a public folder offers Make private and its dialog warns about followers', (tester) async {
    _publicRepo.folder = const PublicFolderEntity(
      id: 'f1',
      ownerId: 'u1',
      name: 'Night Owl',
      itemCount: 0,
      covers: <String>[],
      followerCount: 0,
    );
    await _pumpFolder(tester, _folder(isPublic: true));

    await tester.tap(find.byTooltip('More options'));
    await _settle(tester);
    await tester.tap(find.text('Make private'));
    await _settle(tester);

    expect(find.text('Make this folder private?'), findsOneWidget);
    expect(find.text('Only you will see it. Its link stops working and its followers lose it.'), findsOneWidget);
  });

  testWidgets('cancelling the visibility dialog does not call setPublic', (tester) async {
    _publicRepo.folder = null;
    await _pumpFolder(tester, _folder());

    await tester.tap(find.byTooltip('More options'));
    await _settle(tester);
    await tester.tap(find.text('Make public'));
    await _settle(tester);
    expect(find.text('Make this folder public?'), findsOneWidget);

    await tester.tap(find.text('Cancel'));
    await tester.pump(const Duration(seconds: 1));
    await _settle(tester);

    expect(find.text('Make this folder public?'), findsNothing);
    expect(_publicRepo.setPublicCalls, isEmpty);
  });
}
