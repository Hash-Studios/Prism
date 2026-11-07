import 'package:Prism/core/constants/app_constants.dart' as app_constants;
import 'package:Prism/core/di/injection.dart';
import 'package:Prism/core/network/connectivity_service.dart';
import 'package:Prism/core/state/app_state.dart' as app_state;
import 'package:Prism/core/utils/result.dart';
import 'package:Prism/core/wallpaper/wallpaper_core.dart';
import 'package:Prism/core/wallpaper/wallpaper_source.dart';
import 'package:Prism/core/wallpaper/wallpaper_variants.dart';
import 'package:Prism/core/widgets/prism/prism_ui.dart';
import 'package:Prism/features/favourite_walls/domain/entities/favourite_wall_entity.dart';
import 'package:Prism/features/folders/biz/bloc/folders_bloc.j.dart';
import 'package:Prism/features/folders/domain/entities/folder_entity.dart';
import 'package:Prism/features/folders/domain/entities/folder_section.dart';
import 'package:Prism/features/folders/domain/entities/public_folder_entity.dart';
import 'package:Prism/features/folders/domain/repositories/folders_repository.dart';
import 'package:Prism/features/folders/domain/repositories/public_folders_repository.dart';
import 'package:Prism/features/folders/domain/section_suggester.dart';
import 'package:Prism/features/folders/views/widgets/section_suggestions_sheet.dart';
import 'package:Prism/features/moods/domain/entities/wall_mood.dart';
import 'package:Prism/l10n/l10n.dart';
import 'package:Prism/theme/theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';

typedef _OrganizeCall = ({List<FolderSection>? sections, Map<String, String?> moves});

/// Applies nothing. Records each organize call and serves the walls with their sections.
class _RecordingFoldersRepository implements FoldersRepository {
  _RecordingFoldersRepository({required this.folders, required this.items, required this.sectionOf});

  final List<FolderEntity> folders;
  final Map<String, List<FavouriteWallEntity>> items;
  final Map<String, String> sectionOf;
  final List<_OrganizeCall> organizeCalls = <_OrganizeCall>[];

  @override
  Stream<FolderWriteFailure> get writeFailures => const Stream.empty();

  @override
  int get writeRevision => 0;

  @override
  Future<Result<List<FolderEntity>>> fetchFolders(String userId) async => Result.success(folders);

  @override
  Future<Result<List<FolderItem>?>> fetchItems(String folderId, {required String userId, int? limit}) async {
    final List<FavouriteWallEntity> walls = items[folderId] ?? const <FavouriteWallEntity>[];
    return Result.success(<FolderItem>[
      for (final FavouriteWallEntity wall in walls) FolderItem(wall, sectionId: sectionOf[folderItemKey(wall)]),
    ]);
  }

  @override
  Future<Result<void>> organize(
    FolderEntity folder, {
    required String userId,
    List<FolderSection>? sections,
    Map<String, String?> moves = const <String, String?>{},
  }) async {
    organizeCalls.add((sections: sections, moves: moves));
    return Result.success<void>(null);
  }

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
  Future<Result<void>> addItem(FolderEntity folder, FavouriteWallEntity wall, {required String userId}) async =>
      Result.success<void>(null);

  @override
  Future<Result<void>> removeItem(FolderEntity folder, FavouriteWallEntity wall, {required String userId}) async =>
      Result.success<void>(null);
}

class _NoPublicFolders implements PublicFoldersRepository {
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

class _OnlineConnectivity implements ConnectivityService {
  @override
  Future<bool> hasConnection() async => true;

  @override
  Stream<bool> get onConnectionChange => const Stream<bool>.empty();
}

const String _me = 'me';
final DateTime _at = DateTime.utc(2026, 10);

PrismFavouriteWall _wall(String id) => PrismFavouriteWall(
  id: id,
  wallpaper: PrismWallpaper(
    core: WallpaperCore(id: id, source: WallpaperSource.prism, fullUrl: '', thumbnailUrl: ''),
  ),
);

/// Newest first. a, b, c are dark and quiet. d, e are dreamy. All five are Abstract. a and b are blue.
final List<FavouriteWallEntity> _walls = <FavouriteWallEntity>[
  _wall('a'),
  _wall('b'),
  _wall('c'),
  _wall('d'),
  _wall('e'),
];

Map<String, WallTraits> _moodTraits() => <String, WallTraits>{
  'prism_a': const WallTraits(moods: <WallMood>[WallMood.darkQuiet], category: 'Abstract', colours: <String>['blue']),
  'prism_b': const WallTraits(moods: <WallMood>[WallMood.darkQuiet], category: 'Abstract', colours: <String>['blue']),
  'prism_c': const WallTraits(moods: <WallMood>[WallMood.darkQuiet], category: 'Abstract'),
  'prism_d': const WallTraits(moods: <WallMood>[WallMood.dreamy], category: 'Abstract'),
  'prism_e': const WallTraits(moods: <WallMood>[WallMood.dreamy], category: 'Abstract'),
};

FolderEntity _folder({List<FolderSection> sections = const <FolderSection>[]}) => FolderEntity(
  id: 'work',
  ownerId: _me,
  name: 'Work',
  createdAt: _at,
  updatedAt: _at,
  itemCount: 5,
  covers: const <String>[],
  sections: sections,
);

Future<void> _settle(WidgetTester tester) async {
  for (int i = 0; i < 10; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

/// A host page with a button that opens the sheet. [loadTraits] is called once per load.
Future<({_RecordingFoldersRepository repo, FoldersBloc bloc})> _pumpHost(
  WidgetTester tester, {
  required WallTraitsLoader loadTraits,
  List<FolderSection> sections = const <FolderSection>[],
  Map<String, String> sectionOf = const <String, String>{},
}) async {
  tester.view.physicalSize = const Size(390, 1200);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  app_state.prismUser = app_constants.createGuestPrismUser()..id = _me;
  getIt.registerSingleton<ConnectivityService>(_OnlineConnectivity());
  final FolderEntity folder = _folder(sections: sections);
  final _RecordingFoldersRepository repo = _RecordingFoldersRepository(
    folders: <FolderEntity>[folder],
    items: <String, List<FavouriteWallEntity>>{folder.id: _walls},
    sectionOf: sectionOf,
  );
  final FoldersBloc bloc = FoldersBloc(repo, _NoPublicFolders());
  addTearDown(bloc.close);
  await bloc.run((id) => FoldersEvent.started(userId: _me, operationId: id));
  await bloc.run((id) => FoldersEvent.folderOpened(folderId: folder.id, operationId: id));

  await tester.pumpWidget(
    MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      theme: kLightTheme,
      home: BlocProvider<FoldersBloc>.value(
        value: bloc,
        child: Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: ElevatedButton(
                onPressed: () => showSectionSuggestionsSheet(
                  context,
                  folder: folder,
                  walls: _walls,
                  sectionOf: sectionOf,
                  loadTraits: loadTraits,
                ),
                child: const Text('Open suggestions'),
              ),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('Open suggestions'));
  await _settle(tester);
  return (repo: repo, bloc: bloc);
}

Future<Map<String, WallTraits>> Function(List<FavouriteWallEntity>) _traitsOf(Map<String, WallTraits> traits) =>
    (walls) async => traits;

/// The main button of the sheet.
PrismButton _mainButton(WidgetTester tester) => tester.widget<PrismButton>(find.byType(PrismButton).last);

void main() {
  tearDown(() async {
    app_state.prismUser = app_constants.createGuestPrismUser();
    await getIt.reset();
  });

  testWidgets('opens on Mood, lists its two groups with counts and offers Add 2 sections', (tester) async {
    await _pumpHost(tester, loadTraits: _traitsOf(_moodTraits()));

    expect(find.text('Suggested sections'), findsOneWidget);
    expect(find.text('Dark and quiet'), findsOneWidget);
    expect(find.text('3 wallpapers'), findsOneWidget);
    expect(find.text('Dreamy'), findsOneWidget);
    expect(find.text('2 wallpapers'), findsOneWidget);
    expect(find.text('Add 2 sections'), findsOneWidget);
  });

  testWidgets('unticking one group changes the button to Add 1 section and adds only the kept group', (tester) async {
    final result = await _pumpHost(tester, loadTraits: _traitsOf(_moodTraits()));

    await tester.tap(find.text('Dreamy'));
    await _settle(tester);
    expect(find.text('Add 1 section'), findsOneWidget);

    await tester.tap(find.text('Add 1 section'));
    await _settle(tester);

    expect(result.repo.organizeCalls, hasLength(1));
    final _OrganizeCall call = result.repo.organizeCalls.single;
    expect(call.sections, hasLength(1));
    expect(call.sections!.single.name, 'Dark and quiet');
    expect(call.moves, <String, String?>{
      'prism_a': call.sections!.single.id,
      'prism_b': call.sections!.single.id,
      'prism_c': call.sections!.single.id,
    });
    expect(find.text('Suggested sections'), findsNothing);
  });

  testWidgets('switching to Colour shows only the groups with at least 2 walls', (tester) async {
    await _pumpHost(tester, loadTraits: _traitsOf(_moodTraits()));

    await tester.tap(find.text('Colour'));
    await _settle(tester);

    expect(find.text('Blue'), findsOneWidget);
    expect(find.text('2 wallpapers'), findsOneWidget);
    expect(find.text('Dark and quiet'), findsNothing);
    expect(find.text('Dreamy'), findsNothing);
    expect(find.text('Add 1 section'), findsOneWidget);
  });

  testWidgets('a kind with no groups shows the empty state and disables the button', (tester) async {
    // Every wall is General, so Category has no group, and no wall has a colour.
    final Map<String, WallTraits> general = <String, WallTraits>{
      for (final String key in _moodTraits().keys)
        key: WallTraits(moods: _moodTraits()[key]!.moods, category: 'General'),
    };
    await _pumpHost(tester, loadTraits: _traitsOf(general));

    await tester.tap(find.text('Category'));
    await _settle(tester);

    expect(find.text('No groups to suggest'), findsOneWidget);
    expect(_mainButton(tester).onPressed, isNull);
  });

  testWidgets('closing the sheet without accepting never calls organize', (tester) async {
    final result = await _pumpHost(tester, loadTraits: _traitsOf(_moodTraits()));

    // Tap the dim outside the sheet: sheets float 8 pt in from the screen edge.
    await tester.tapAt(const Offset(2, 2));
    await _settle(tester);

    expect(find.text('Suggested sections'), findsNothing);
    expect(result.repo.organizeCalls, isEmpty);
  });

  testWidgets('a group named like an existing section joins it and adds no new section for it', (tester) async {
    const FolderSection existing = FolderSection(id: 'dq', name: 'Dark and quiet');
    final result = await _pumpHost(
      tester,
      loadTraits: _traitsOf(_moodTraits()),
      sections: <FolderSection>[existing],
      sectionOf: <String, String>{'prism_a': 'dq'},
    );

    // Wall a is already in the section, so the group offers only the two Unsorted walls b and c.
    expect(find.text('2 wallpapers. Goes into your section with this name.'), findsOneWidget);
    expect(find.text('Add 1 section'), findsOneWidget);

    await tester.tap(find.text('Add 1 section'));
    await _settle(tester);

    expect(result.repo.organizeCalls, hasLength(1));
    final _OrganizeCall call = result.repo.organizeCalls.single;
    expect(call.sections, hasLength(2));
    expect(call.sections![0], existing);
    expect(call.sections![1].name, 'Dreamy');
    expect(call.moves.containsKey('prism_a'), isFalse);
    expect(call.moves['prism_b'], 'dq');
    expect(call.moves['prism_c'], 'dq');
    expect(call.moves['prism_d'], call.sections![1].id);
    expect(call.moves['prism_e'], call.sections![1].id);
  });

  testWidgets('a failed load shows the error state and Try again calls loadTraits again', (tester) async {
    int calls = 0;
    Future<Map<String, WallTraits>> loader(List<FavouriteWallEntity> walls) async {
      calls++;
      if (calls == 1) throw StateError('offline');
      return _moodTraits();
    }

    await _pumpHost(tester, loadTraits: loader);

    expect(calls, 1);
    expect(find.text('Could not load suggestions'), findsOneWidget);
    expect(find.text('Dark and quiet'), findsNothing);

    await tester.tap(find.text('Try again'));
    await _settle(tester);

    expect(calls, 2);
    expect(find.text('Could not load suggestions'), findsNothing);
    expect(find.text('Dark and quiet'), findsOneWidget);
  });
}
