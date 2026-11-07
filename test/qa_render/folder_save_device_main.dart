// Device QA entry point for Save all: the real folder page and Save all views, a fake signed-in user, a fake coin
// ledger and fake folder data. The Photos or gallery save is real: each wall is downloaded and saved into the album.
// Run: fvm flutter run -t test/qa_render/folder_save_device_main.dart -d <device>
import 'dart:io';

import 'package:Prism/core/analytics/analytics_runtime.dart';
import 'package:Prism/core/coins/coins_service.dart';
import 'package:Prism/core/constants/app_constants.dart' as app_constants;
import 'package:Prism/core/di/injection.dart';
import 'package:Prism/core/network/connectivity_service.dart';
import 'package:Prism/core/platform/pigeon/prism_media_api.g.dart';
import 'package:Prism/core/state/app_state.dart' as app_state;
import 'package:Prism/core/utils/result.dart';
import 'package:Prism/core/wallpaper/wallpaper_core.dart';
import 'package:Prism/core/wallpaper/wallpaper_source.dart';
import 'package:Prism/core/wallpaper/wallpaper_variants.dart';
import 'package:Prism/core/widgets/prism/prism_ui.dart';
import 'package:Prism/features/auto_rotate/biz/bloc/auto_rotate_bloc.j.dart';
import 'package:Prism/features/favourite_walls/domain/entities/favourite_wall_entity.dart';
import 'package:Prism/features/folders/biz/bloc/folders_bloc.j.dart';
import 'package:Prism/features/folders/biz/folder_save/folder_save_bloc.j.dart';
import 'package:Prism/features/folders/data/folder_save_gateway_impl.dart';
import 'package:Prism/features/folders/domain/entities/folder_entity.dart';
import 'package:Prism/features/folders/domain/entities/folder_save_plan.dart';
import 'package:Prism/features/folders/domain/entities/folder_save_run.dart';
import 'package:Prism/features/folders/domain/entities/folder_section.dart';
import 'package:Prism/features/folders/domain/entities/public_folder_entity.dart';
import 'package:Prism/features/folders/domain/repositories/folder_save_gateway.dart';
import 'package:Prism/features/folders/domain/repositories/folders_repository.dart';
import 'package:Prism/features/folders/domain/repositories/public_folders_repository.dart';
import 'package:Prism/features/folders/views/pages/folder_screen.dart';
import 'package:Prism/l10n/l10n.dart';
import 'package:Prism/theme/theme.dart';
import 'package:auto_route/auto_route.dart';
import 'package:bloc_test/bloc_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:mocktail/mocktail.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../support/fake_app_analytics.dart';

const List<String> _previews = <String>[
  'https://img.prismwalls.com/previews/4f2935aee606c4a151ce2a5cd20570e729bfbf38b0b40fbeea65bb1b193c1730.img',
  'https://img.prismwalls.com/previews/a76857c0fbcfd6dd01b76e7b50996edc2dfe4200cf4fa421d4f86eb8818fd351.img',
  'https://img.prismwalls.com/previews/17178b61fa1febf9269a5ebab8fbffd627e0ba2211edc7262516d990e60f089a.img',
  'https://img.prismwalls.com/previews/f3787f4b42f85a23fd26667110414d54d1ccbb20661fdbd33c6e0eeed7d3328e.img',
];
const String _folderId = 'qa-night';
const String _folderName = 'Night';
const int _wallCount = 10;

String _wallId(int i) => 'QANIGHT${i.toString().padLeft(2, '0')}';
String _preview(String id) => _previews[int.parse(id.substring(id.length - 2)) % _previews.length];

final DateTime _at = DateTime.utc(2026, 11, 5);
final List<FavouriteWallEntity> _walls = <FavouriteWallEntity>[
  for (int i = 0; i < _wallCount; i++)
    PrismFavouriteWall(
      id: _wallId(i),
      wallpaper: PrismWallpaper(
        core: WallpaperCore(
          id: _wallId(i),
          source: WallpaperSource.prism,
          fullUrl: '',
          thumbnailUrl: _preview(_wallId(i)),
          authorName: 'Mira',
        ),
      ),
    ),
];

class _QaRouter extends Mock implements StackRouter {}

class _QaAutoRotateBloc extends MockBloc<AutoRotateEvent, AutoRotateState> implements AutoRotateBloc {}

class _QaConnectivity implements ConnectivityService {
  @override
  Future<bool> hasConnection() async => true;

  @override
  Stream<bool> get onConnectionChange => const Stream<bool>.empty();
}

class _QaAnalytics extends FakeAppAnalytics {}

class _QaFolders implements FoldersRepository {
  @override
  Stream<FolderWriteFailure> get writeFailures => const Stream<FolderWriteFailure>.empty();

  @override
  int get writeRevision => 0;

  @override
  Future<Result<List<FolderEntity>>> fetchFolders(String userId) async => Result.success(<FolderEntity>[
    FolderEntity(
      id: _folderId,
      ownerId: userId,
      name: _folderName,
      createdAt: _at,
      updatedAt: _at,
      itemCount: _walls.length,
      covers: _previews,
    ),
  ]);

  @override
  Future<Result<List<FolderItem>?>> fetchItems(String folderId, {required String userId, int? limit}) async {
    final List<FavouriteWallEntity> walls = limit == null ? _walls : _walls.take(limit).toList();
    return Result.success<List<FolderItem>?>(walls.map((w) => FolderItem(w)).toList());
  }

  @override
  Future<Result<void>> organize(
    FolderEntity folder, {
    required String userId,
    List<FolderSection>? sections,
    Map<String, String?> moves = const <String, String?>{},
  }) async => Result.success<void>(null);

  @override
  Future<Result<Set<String>>> foldersContaining(List<String> folderIds, String itemKey) async =>
      Result.success(<String>{_folderId});

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

class _QaPublicFolders implements PublicFoldersRepository {
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

/// Prices like the server with a fake ledger, and saves each preview into the real album.
class _QaGateway implements FolderSaveGateway {
  final PrismMediaHostApi _media = PrismMediaHostApi();
  final Set<String> _saved = <String>{'prism:${_wallId(9)}'};

  @override
  String get ownerId => app_state.prismUser.id;

  @override
  FolderSaveAccount account() => FolderSaveAccount(
    isPro: app_state.prismUser.premium,
    premiumUnlocked: app_state.prismUser.premium,
    balance: CoinsService.instance.balanceNotifier.value,
    graceLeft: 0,
    price: 10,
  );

  @override
  Future<Map<String, WallAccess>> wallAccess(List<String> ids) async => <String, WallAccess>{
    for (final String id in ids)
      if (id != _wallId(8)) id: id == _wallId(6) || id == _wallId(7) ? WallAccess.premium : WallAccess.open,
  };

  @override
  Future<bool> isSaved(FolderSaveWall wall) async => _saved.contains(wall.key);

  @override
  Future<FolderSaveAccess> requestAccess(String album) async {
    final OperationResult result = await _media.prepareAlbumSave(
      Platform.isAndroid ? folderAlbumDirectory(album) : album,
    );
    return result.success ? FolderSaveAccess.granted : FolderSaveAccess.denied;
  }

  @override
  Future<FolderWallOutcome> save(FolderSaveItem item, {required String album, required int maxCoins}) async {
    final File file = File(p.join((await getTemporaryDirectory()).path, 'folder_save_qa_${item.wall.id}.img'));
    try {
      final HttpClient client = HttpClient();
      try {
        final HttpClientResponse response = await (await client.getUrl(Uri.parse(_preview(item.wall.id)))).close();
        if (response.statusCode != HttpStatus.ok) return const FolderWallOutcome.failed(FolderSaveFailure.network);
        await response.pipe(file.openWrite());
      } finally {
        client.close(force: true);
      }
      await Future<void>.delayed(const Duration(milliseconds: 900));
      final OperationResult stored = await _media.enqueueDownload(
        DownloadRequest(
          link: file.path,
          filenameWithoutExtension: 'prism-qa-${item.wall.id}',
          isLocalFile: true,
          album: Platform.isAndroid ? folderAlbumDirectory(album) : album,
        ),
      );
      if (!stored.success) return const FolderWallOutcome.failed(FolderSaveFailure.storage);
      CoinsService.instance.balanceNotifier.value -= maxCoins;
      _saved.add(item.wall.key);
      return const FolderWallOutcome.saved();
    } finally {
      if (file.existsSync()) file.deleteSync();
    }
  }

  @override
  Future<void> clearTemporaryFiles() async {}
}

class _QaApp extends StatefulWidget {
  const _QaApp({required this.router, required this.folders, required this.rotation});

  final StackRouter router;
  final FoldersBloc folders;
  final AutoRotateBloc rotation;

  @override
  State<_QaApp> createState() => _QaAppState();
}

class _QaAppState extends State<_QaApp> {
  bool _dark = false;
  bool _largeText = false;

  @override
  Widget build(BuildContext context) {
    return StackRouterScope(
      controller: widget.router,
      stateHash: 0,
      child: MultiBlocProvider(
        providers: <BlocProvider<dynamic>>[
          BlocProvider<FoldersBloc>.value(value: widget.folders),
          BlocProvider<AutoRotateBloc>.value(value: widget.rotation),
        ],
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          debugShowCheckedModeBanner: false,
          theme: _dark ? kDarkTheme : kLightTheme,
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(textScaler: _largeText ? const TextScaler.linear(1.6) : MediaQuery.textScalerOf(context)),
            child: Stack(
              children: <Widget>[
                child!,
                PositionedDirectional(
                  top: MediaQuery.paddingOf(context).top + 4,
                  start: 0,
                  end: 0,
                  child: IgnorePointer(
                    child: Center(child: _QaBalance(dark: _dark)),
                  ),
                ),
              ],
            ),
          ),
          home: Builder(
            builder: (context) => Scaffold(
              body: SafeArea(
                child: ListView(
                  padding: const EdgeInsets.all(PrismSpace.page),
                  children: <Widget>[
                    const SizedBox(height: PrismSpace.xxl),
                    Text('Save all QA', style: PrismTextStyles.sectionTitle(context)),
                    const SizedBox(height: PrismSpace.md),
                    SwitchListTile(
                      title: const Text('Pro user'),
                      value: app_state.prismUser.premium,
                      onChanged: (value) => setState(() => app_state.prismUser.premium = value),
                    ),
                    SwitchListTile(
                      title: const Text('Dark theme'),
                      value: _dark,
                      onChanged: (value) => setState(() => _dark = value),
                    ),
                    SwitchListTile(
                      title: const Text('Large text (160%)'),
                      value: _largeText,
                      onChanged: (value) => setState(() => _largeText = value),
                    ),
                    const SizedBox(height: PrismSpace.md),
                    PrismButton(
                      key: const ValueKey<String>('qa-open-folder'),
                      label: 'Open the Night folder',
                      expand: true,
                      onPressed: () => Navigator.of(
                        context,
                      ).push(MaterialPageRoute<void>(builder: (_) => const FolderScreen(folderId: _folderId))),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _QaBalance extends StatelessWidget {
  const _QaBalance({required this.dark});

  final bool dark;

  @override
  Widget build(BuildContext context) => ValueListenableBuilder<int>(
    valueListenable: CoinsService.instance.balanceNotifier,
    builder: (context, coins, _) => Material(
      color: dark ? Colors.white12 : Colors.black12,
      borderRadius: BorderRadius.circular(PrismRadius.pill),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        child: Text('QA coins: $coins', style: TextStyle(fontSize: 12, color: dark ? Colors.white : Colors.black)),
      ),
    ),
  );
}

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  getIt.registerSingleton<ConnectivityService>(_QaConnectivity());
  getIt.registerSingleton<FolderSaveBloc>(FolderSaveBloc(_QaGateway()));
  AnalyticsRuntime.instance = _QaAnalytics();
  app_state.prismUser = app_constants.createGuestPrismUser()
    ..id = 'qa-user'
    ..name = 'Mira'
    ..premium = false
    ..loggedIn = true;
  CoinsService.instance.balanceNotifier.value = 40;

  final _QaRouter router = _QaRouter();
  when(() => router.stack).thenReturn(const <AutoRoutePage<dynamic>>[]);
  final _QaAutoRotateBloc rotation = _QaAutoRotateBloc();
  when(() => rotation.state).thenReturn(AutoRotateState.initial());
  final FoldersBloc folders = FoldersBloc(_QaFolders(), _QaPublicFolders())
    ..add(const FoldersEvent.started(userId: 'qa-user'));

  runApp(_QaApp(router: router, folders: folders, rotation: rotation));
}
