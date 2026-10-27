import 'package:Prism/core/constants/app_constants.dart' as app_constants;
import 'package:Prism/core/state/app_state.dart' as app_state;
import 'package:Prism/core/utils/result.dart';
import 'package:Prism/features/favourite_walls/domain/entities/favourite_wall_entity.dart';
import 'package:Prism/features/folders/biz/bloc/folders_bloc.j.dart';
import 'package:Prism/features/folders/domain/entities/folder_entity.dart';
import 'package:Prism/features/folders/domain/repositories/folders_repository.dart';
import 'package:Prism/features/folders/views/widgets/folders_row.dart';
import 'package:Prism/l10n/l10n.dart';
import 'package:Prism/theme/theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';

class _FakeFoldersRepository implements FoldersRepository {
  _FakeFoldersRepository({this.folders = const <FolderEntity>[]});

  final List<FolderEntity> folders;

  /// One entry per repository call.
  final List<String> calls = <String>[];

  @override
  Future<Result<List<FolderEntity>>> fetchFolders(String userId) async {
    calls.add('fetchFolders:$userId');
    return Result.success(folders);
  }

  @override
  Future<Result<List<FavouriteWallEntity>?>> fetchItems(String folderId, {int? limit}) async {
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
  Future<Result<void>> deleteFolder(String folderId) async {
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

  Future<void> pumpSignedIn(WidgetTester tester, _FakeFoldersRepository repo) async {
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
}
