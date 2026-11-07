import 'package:Prism/core/constants/app_constants.dart' as app_constants;
import 'package:Prism/core/di/injection.dart';
import 'package:Prism/core/network/connectivity_service.dart';
import 'package:Prism/core/state/app_state.dart' as app_state;
import 'package:Prism/core/utils/result.dart';
import 'package:Prism/core/wallpaper/wallpaper_core.dart';
import 'package:Prism/core/wallpaper/wallpaper_source.dart';
import 'package:Prism/core/wallpaper/wallpaper_variants.dart';
import 'package:Prism/core/widgets/prism/prism_ui.dart';
import 'package:Prism/features/auto_rotate/biz/bloc/auto_rotate_bloc.j.dart';
import 'package:Prism/features/favourite_walls/domain/entities/favourite_wall_entity.dart';
import 'package:Prism/features/folders/biz/bloc/folders_bloc.j.dart';
import 'package:Prism/features/folders/domain/entities/folder_entity.dart';
import 'package:Prism/features/folders/domain/entities/folder_section.dart';
import 'package:Prism/features/folders/domain/entities/public_folder_entity.dart';
import 'package:Prism/features/folders/domain/repositories/folders_repository.dart';
import 'package:Prism/features/folders/domain/repositories/public_folders_repository.dart';
import 'package:Prism/features/folders/views/pages/folder_screen.dart';
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

class _OnlineConnectivity implements ConnectivityService {
  @override
  Future<bool> hasConnection() async => true;

  @override
  Stream<bool> get onConnectionChange => const Stream<bool>.empty();
}

typedef _OrganizeCall = ({List<FolderSection>? sections, Map<String, String?> moves});

/// Applies nothing. Records each organize call and serves the walls with their sections.
class _RecordingFoldersRepository implements FoldersRepository {
  _RecordingFoldersRepository({required this.folders, required this.items, required this.sectionOf});

  final List<FolderEntity> folders;
  final Map<String, List<FavouriteWallEntity>> items;

  /// Item key to section id.
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

const String _me = 'me';
final DateTime _at = DateTime.utc(2026, 10);

const List<FolderSection> _sections = <FolderSection>[
  FolderSection(id: 'lock', name: 'Lock screens'),
  FolderSection(id: 'dark', name: 'Dark'),
];

const Map<String, String> _sectionOf = <String, String>{'prism_l1': 'lock', 'prism_d1': 'dark'};

/// Newest first. u1 and u2 are Unsorted, l1 is in Lock screens, d1 is in Dark.
final List<FavouriteWallEntity> _walls = <FavouriteWallEntity>[_wall('u1'), _wall('u2'), _wall('l1'), _wall('d1')];

FolderEntity _folder({String ownerId = _me, List<FolderSection> sections = _sections}) => FolderEntity(
  id: 'work',
  ownerId: ownerId,
  name: 'Work',
  createdAt: _at,
  updatedAt: _at,
  itemCount: 4,
  covers: const <String>[],
  sections: sections,
);

PrismFavouriteWall _wall(String id) => PrismFavouriteWall(
  id: id,
  wallpaper: PrismWallpaper(
    core: WallpaperCore(id: id, source: WallpaperSource.prism, fullUrl: '', thumbnailUrl: ''),
  ),
);

_MockAutoRotateBloc _rotationBloc() {
  final _MockAutoRotateBloc bloc = _MockAutoRotateBloc();
  when(() => bloc.state).thenReturn(AutoRotateState.initial());
  return bloc;
}

/// A menu entry of an overflow menu, by its label.
Finder _menuItem(String label) =>
    find.ancestor(of: find.text(label), matching: find.byWidgetPredicate((widget) => widget is PopupMenuItem));

/// A button of the page or a sheet, by its label.
Finder _button(String label) => find.descendant(of: find.byType(PrismButton), matching: find.text(label));

Future<void> _settle(WidgetTester tester) async {
  for (int i = 0; i < 10; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

void _setView(WidgetTester tester, Size logical) {
  tester.view.physicalSize = logical;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
}

/// True when [finder] is built and sits below the pinned strip and inside the screen.
bool _onScreen(WidgetTester tester, Finder finder, Finder stripChip) {
  if (finder.evaluate().isEmpty || stripChip.evaluate().isEmpty) return false;
  final Rect rect = tester.getRect(finder);
  final Rect chip = tester.getRect(stripChip);
  final Size screen = tester.view.physicalSize / tester.view.devicePixelRatio;
  return rect.top >= chip.bottom && rect.bottom <= screen.height;
}

Future<_RecordingFoldersRepository> _pump(
  WidgetTester tester, {
  required FolderEntity folder,
  List<FavouriteWallEntity> walls = const <FavouriteWallEntity>[],
  Map<String, String> sectionOf = const <String, String>{},
  TextScaler? textScaler,
}) async {
  app_state.prismUser = app_constants.createGuestPrismUser()..id = _me;
  getIt.registerSingleton<ConnectivityService>(_OnlineConnectivity());
  final _RecordingFoldersRepository repo = _RecordingFoldersRepository(
    folders: <FolderEntity>[folder],
    items: <String, List<FavouriteWallEntity>>{folder.id: walls},
    sectionOf: sectionOf,
  );
  final FoldersBloc bloc = FoldersBloc(repo, _NoPublicFolders());
  addTearDown(bloc.close);
  final _MockStackRouter router = _MockStackRouter();
  when(() => router.stack).thenReturn(const <AutoRoutePage<dynamic>>[]);
  await tester.pumpWidget(
    MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      theme: kLightTheme,
      builder: textScaler == null
          ? null
          : (context, child) => MediaQuery(
              data: MediaQuery.of(context).copyWith(textScaler: textScaler),
              child: child!,
            ),
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
  await _settle(tester);
  return repo;
}

/// Long-presses [key] with a drag: holds past the drag delay, moves to [target], and lets go.
Future<void> _dragTo(WidgetTester tester, Finder source, Finder target) async {
  final Offset from = tester.getCenter(source);
  final Offset to = tester.getCenter(target);
  final TestGesture gesture = await tester.startGesture(from);
  await tester.pump(const Duration(milliseconds: 400));
  for (int i = 1; i <= 10; i++) {
    await gesture.moveTo(Offset.lerp(from, to, i / 10)!);
    await tester.pump(const Duration(milliseconds: 16));
  }
  await gesture.up();
  await _settle(tester);
}

/// A widget test with semantics on. The handle is disposed inside the test body, because flutter_test checks for an
/// active handle before its tear-down callbacks run.
void _test(String description, Future<void> Function(WidgetTester tester) body) {
  testWidgets(description, (tester) async {
    final SemanticsHandle semantics = tester.ensureSemantics();
    try {
      await body(tester);
    } finally {
      semantics.dispose();
    }
  });
}

void main() {
  tearDown(() async {
    app_state.prismUser = app_constants.createGuestPrismUser();
    await getIt.reset();
  });

  _test('shows Unsorted, Lock screens and Dark headers in that order with their counts', (tester) async {
    _setView(tester, const Size(390, 1400));
    await _pump(tester, folder: _folder(), walls: _walls, sectionOf: _sectionOf);

    final Finder unsorted = find.bySemanticsLabel('Unsorted, 2 wallpapers');
    final Finder lock = find.bySemanticsLabel('Lock screens, 1 wallpaper');
    final Finder dark = find.bySemanticsLabel('Dark, 1 wallpaper');
    expect(unsorted, findsOneWidget);
    expect(lock, findsOneWidget);
    expect(dark, findsOneWidget);
    expect(find.text('2 wallpapers'), findsOneWidget);
    expect(find.text('1 wallpaper'), findsNWidgets(2));
    expect(tester.getTopLeft(unsorted).dy, lessThan(tester.getTopLeft(lock).dy));
    expect(tester.getTopLeft(lock).dy, lessThan(tester.getTopLeft(dark).dy));
  });

  _test('tapping the Dark strip chip scrolls the Dark header on screen', (tester) async {
    // A short screen, so the Dark header starts below the fold.
    _setView(tester, const Size(390, 600));
    await _pump(tester, folder: _folder(), walls: _walls, sectionOf: _sectionOf);

    final Finder strip = find.byWidgetPredicate((w) => w is ListView && w.scrollDirection == Axis.horizontal);
    expect(find.bySemanticsLabel('Go to Unsorted, 2 wallpapers'), findsOneWidget);
    expect(find.bySemanticsLabel('Go to Lock screens, 1 wallpaper'), findsOneWidget);

    // The Dark chip is past the right edge of the strip, so scroll the strip to it first.
    await tester.drag(strip, const Offset(-300, 0));
    await _settle(tester);
    final Finder dark = find.bySemanticsLabel('Dark, 1 wallpaper');
    final Finder chip = find.bySemanticsLabel('Go to Dark, 1 wallpaper');
    expect(chip, findsOneWidget);
    expect(_onScreen(tester, dark, chip), isFalse);

    await tester.tap(chip);
    await _settle(tester);

    expect(_onScreen(tester, dark, chip), isTrue);
  });

  _test('tapping a section header collapses and expands its walls', (tester) async {
    _setView(tester, const Size(390, 1400));
    await _pump(tester, folder: _folder(), walls: _walls, sectionOf: _sectionOf);

    final Finder lockHeader = find.bySemanticsLabel('Lock screens, 1 wallpaper');
    final Finder lockWall = find.byKey(const ValueKey<String>('prism_l1'));
    expect(lockWall, findsOneWidget);
    expect(
      tester.getSemantics(lockHeader),
      matchesSemantics(
        label: 'Lock screens, 1 wallpaper',
        isHeader: true,
        isButton: true,
        hasTapAction: true,
        hasExpandedState: true,
        isExpanded: true,
      ),
    );

    await tester.tap(lockHeader);
    await _settle(tester);
    expect(lockWall, findsNothing);
    expect(
      tester.getSemantics(lockHeader),
      matchesSemantics(
        label: 'Lock screens, 1 wallpaper',
        isHeader: true,
        isButton: true,
        hasTapAction: true,
        hasExpandedState: true,
      ),
    );

    await tester.tap(lockHeader);
    await _settle(tester);
    expect(lockWall, findsOneWidget);
    expect(
      tester.getSemantics(lockHeader),
      matchesSemantics(
        label: 'Lock screens, 1 wallpaper',
        isHeader: true,
        isButton: true,
        hasTapAction: true,
        hasExpandedState: true,
        isExpanded: true,
      ),
    );
  });

  _test('Add section from the overflow menu records a third section named Desktop', (tester) async {
    // Tall enough that the new section header, after Dark, is built.
    _setView(tester, const Size(390, 2400));
    final _RecordingFoldersRepository repo = await _pump(
      tester,
      folder: _folder(),
      walls: _walls,
      sectionOf: _sectionOf,
    );

    await tester.tap(find.byTooltip('More options'));
    await _settle(tester);
    await tester.tap(_menuItem('Add section'));
    await _settle(tester);
    await tester.enterText(find.byType(EditableText), 'Desktop');
    await _settle(tester);
    await tester.tap(_button('Add section'));
    await _settle(tester);

    expect(repo.organizeCalls, hasLength(1));
    final _OrganizeCall call = repo.organizeCalls.single;
    expect(call.sections, hasLength(3));
    expect(call.sections!.last.name, 'Desktop');
    expect(call.moves, isEmpty);
    expect(find.bySemanticsLabel('Desktop, no wallpapers'), findsOneWidget);
  });

  _test('renaming a section records the new name for that section only', (tester) async {
    _setView(tester, const Size(390, 1400));
    final _RecordingFoldersRepository repo = await _pump(
      tester,
      folder: _folder(),
      walls: _walls,
      sectionOf: _sectionOf,
    );

    await tester.tap(find.byTooltip('More options for Dark'));
    await _settle(tester);
    await tester.tap(_menuItem('Rename'));
    await _settle(tester);
    await tester.enterText(find.byType(EditableText), 'Night');
    await _settle(tester);
    await tester.tap(_button('Rename'));
    await _settle(tester);

    expect(repo.organizeCalls, hasLength(1));
    final _OrganizeCall call = repo.organizeCalls.single;
    expect(call.sections, const <FolderSection>[
      FolderSection(id: 'lock', name: 'Lock screens'),
      FolderSection(id: 'dark', name: 'Night'),
    ]);
    expect(call.moves, isEmpty);
    expect(find.bySemanticsLabel('Night, 1 wallpaper'), findsOneWidget);
  });

  _test('deleting a section moves its walls to Unsorted with no moves recorded', (tester) async {
    _setView(tester, const Size(390, 1400));
    final _RecordingFoldersRepository repo = await _pump(
      tester,
      folder: _folder(),
      walls: _walls,
      sectionOf: _sectionOf,
    );

    await tester.tap(find.byTooltip('More options for Dark'));
    await _settle(tester);
    await tester.tap(_menuItem('Delete section'));
    await _settle(tester);
    await tester.tap(_button('Delete section'));
    await _settle(tester);

    expect(repo.organizeCalls, hasLength(1));
    final _OrganizeCall call = repo.organizeCalls.single;
    expect(call.sections, const <FolderSection>[FolderSection(id: 'lock', name: 'Lock screens')]);
    expect(call.moves, isEmpty);
    expect(find.bySemanticsLabel('Dark, 1 wallpaper'), findsNothing);
    expect(find.bySemanticsLabel('Unsorted, 3 wallpapers'), findsOneWidget);
    expect(find.byKey(const ValueKey<String>('prism_d1')), findsOneWidget);
  });

  _test('long press then Move to section records the move of that wall', (tester) async {
    _setView(tester, const Size(390, 1400));
    final _RecordingFoldersRepository repo = await _pump(
      tester,
      folder: _folder(),
      walls: _walls,
      sectionOf: _sectionOf,
    );

    await tester.longPress(find.byKey(const ValueKey<String>('prism_u1')));
    await _settle(tester);
    await tester.tap(_button('Move to section'));
    await _settle(tester);
    await tester.tap(find.widgetWithText(PrismRow, 'Dark'));
    await _settle(tester);

    expect(repo.organizeCalls, hasLength(1));
    expect(repo.organizeCalls.single.moves, const <String, String?>{'prism_u1': 'dark'});
    expect(repo.organizeCalls.single.sections, isNull);
    expect(find.bySemanticsLabel('Dark, 2 wallpapers'), findsOneWidget);
  });

  _test('dragging a wall onto the Dark header records the move to Dark', (tester) async {
    _setView(tester, const Size(390, 1400));
    final _RecordingFoldersRepository repo = await _pump(
      tester,
      folder: _folder(),
      walls: _walls,
      sectionOf: _sectionOf,
    );

    await _dragTo(tester, find.byKey(const ValueKey<String>('prism_u1')), find.bySemanticsLabel('Dark, 1 wallpaper'));

    expect(repo.organizeCalls, hasLength(1));
    expect(repo.organizeCalls.single.moves, const <String, String?>{'prism_u1': 'dark'});
    expect(repo.organizeCalls.single.sections, isNull);
  });

  _test('selecting two walls and moving them records one move per wall', (tester) async {
    _setView(tester, const Size(390, 1400));
    final _RecordingFoldersRepository repo = await _pump(
      tester,
      folder: _folder(),
      walls: _walls,
      sectionOf: _sectionOf,
    );

    await tester.tap(find.byTooltip('More options'));
    await _settle(tester);
    await tester.tap(_menuItem('Select wallpapers'));
    await _settle(tester);
    expect(find.text('Tap wallpapers to select them'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey<String>('prism_u1')));
    await _settle(tester);
    await tester.tap(find.byKey(const ValueKey<String>('prism_u2')));
    await _settle(tester);
    expect(find.text('2 selected'), findsOneWidget);

    await tester.tap(_button('Move to section'));
    await _settle(tester);
    await tester.tap(find.widgetWithText(PrismRow, 'Lock screens'));
    await _settle(tester);

    expect(repo.organizeCalls, hasLength(1));
    expect(repo.organizeCalls.single.moves, const <String, String?>{'prism_u1': 'lock', 'prism_u2': 'lock'});
    expect(find.text('2 selected'), findsNothing);
  });

  _test('large text renders the headers without overflow and a collapse target of at least 44 points', (tester) async {
    _setView(tester, const Size(390, 1400));
    await _pump(
      tester,
      folder: _folder(),
      walls: _walls,
      sectionOf: _sectionOf,
      textScaler: const TextScaler.linear(2.0),
    );

    expect(tester.takeException(), isNull);
    final Finder lockHeader = find.bySemanticsLabel('Lock screens, 1 wallpaper');
    expect(lockHeader, findsOneWidget);
    final Finder ink = find.descendant(of: lockHeader, matching: find.byType(InkWell));
    expect(ink, findsWidgets);
    final Size size = tester.getSize(ink.first);
    expect(size.height, greaterThanOrEqualTo(44));
    expect(size.width, greaterThanOrEqualTo(44));
  });

  _test('a folder with no sections shows a plain grid with no strip and no Unsorted header', (tester) async {
    _setView(tester, const Size(390, 1400));
    await _pump(
      tester,
      folder: _folder(sections: const <FolderSection>[]),
      walls: <FavouriteWallEntity>[_wall('u1'), _wall('u2')],
    );

    expect(find.byType(PrismWallTile), findsNWidgets(2));
    expect(find.text('Unsorted'), findsNothing);
    expect(find.bySemanticsLabel(RegExp('^Go to ')), findsNothing);
    expect(find.bySemanticsLabel(RegExp(r'wallpapers?$')), findsNothing);
  });

  _test('a viewer who is neither owner nor editor never sees Add section in the menu', (tester) async {
    _setView(tester, const Size(390, 1400));
    await _pump(
      tester,
      folder: _folder(ownerId: 'owner'),
      walls: _walls,
      sectionOf: _sectionOf,
    );

    expect(find.bySemanticsLabel('Dark, 1 wallpaper'), findsOneWidget);
    expect(find.byTooltip('More options for Dark'), findsNothing);

    await tester.tap(find.byTooltip('More options'));
    await _settle(tester);

    expect(_menuItem('People'), findsOneWidget);
    expect(_menuItem('Add section'), findsNothing);
    expect(_menuItem('Select wallpapers'), findsNothing);
    expect(_menuItem('Reorder sections'), findsNothing);
  });
}
