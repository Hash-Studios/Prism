import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:Prism/core/state/app_state.dart' as app_state;
import 'package:Prism/core/wallpaper/wallpaper_source.dart';
import 'package:Prism/features/favourite_walls/domain/entities/favourite_wall_entity.dart';
import 'package:Prism/features/ios_shortcuts/data/native_asset_paths_store.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as path;
import 'package:shared_preferences/shared_preferences.dart';

import '../../support/profile_user_fixture.dart';

FavouriteWallEntity _protectedWall(String id) =>
    LegacyFavouriteWall(id: id, source: WallpaperSource.prism, legacyPayload: const <String, dynamic>{'url': ''});

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  tearDown(() {
    NativeAssetPathsStore.supportDirectoryOverride = null;
    NativeAssetPathsStore.documentsDirectoryOverride = null;
    NativeAssetPathsStore.downloadedOriginalOverride = null;
    app_state.prismUser = profileUser(id: '', loggedIn: false);
  });

  test('drops all originals if the active account changes during lookup', () async {
    app_state.prismUser = profileUser(id: 'owner-a');
    NativeAssetPathsStore.supportDirectoryOverride = Directory('/tmp/prism-shortcuts-support');
    NativeAssetPathsStore.documentsDirectoryOverride = Directory('/tmp/prism-shortcuts-documents');
    int lookups = 0;
    NativeAssetPathsStore.downloadedOriginalOverride = (FavouriteWallEntity wall) async {
      lookups++;
      if (lookups == 1) app_state.prismUser = profileUser(id: 'owner-b');
      return File('/tmp/prism-shortcuts-documents/PrismDownloads/${wall.id}.jpg');
    };

    final Map<String, String> paths = await NativeAssetPathsStore.downloadedOriginalPaths(<FavouriteWallEntity>[
      _protectedWall('first'),
      _protectedWall('second'),
    ]);

    expect(lookups, 1);
    expect(paths, isEmpty);
  });

  test('drops originals if the account logs out but retains its id', () async {
    app_state.prismUser = profileUser(id: 'owner-a');
    NativeAssetPathsStore.supportDirectoryOverride = Directory('/tmp/prism-shortcuts-support');
    NativeAssetPathsStore.documentsDirectoryOverride = Directory('/tmp/prism-shortcuts-documents');
    NativeAssetPathsStore.downloadedOriginalOverride = (FavouriteWallEntity wall) async {
      app_state.prismUser = profileUser(id: 'owner-a', loggedIn: false);
      return File('/tmp/prism-shortcuts-documents/PrismDownloads/${wall.id}.jpg');
    };

    final Map<String, String> paths = await NativeAssetPathsStore.downloadedOriginalPaths(<FavouriteWallEntity>[
      _protectedWall('first'),
    ]);

    expect(paths, isEmpty);
  });

  test('confines downloaded originals to retained and downloads roots', () async {
    app_state.prismUser = profileUser(id: 'owner-a');
    final Directory support = Directory('/tmp/prism-shortcuts-support');
    final Directory documents = Directory('/tmp/prism-shortcuts-documents');
    NativeAssetPathsStore.supportDirectoryOverride = support;
    NativeAssetPathsStore.documentsDirectoryOverride = documents;
    final Map<String, String> sourcePaths = <String, String>{
      'nested': path.join(support.path, 'prism', 'offline', 'assets', 'assets', 'nested.asset'),
      'outside': path.join('/tmp', 'outside-private.jpg'),
    };
    NativeAssetPathsStore.downloadedOriginalOverride = (FavouriteWallEntity wall) async => File(sourcePaths[wall.id]!);

    final Map<String, String> paths = await NativeAssetPathsStore.downloadedOriginalPaths(<FavouriteWallEntity>[
      _protectedWall('nested'),
      _protectedWall('outside'),
    ]);

    expect(paths, <String, String>{
      NativeAssetPathsStore.originalAssetKey(_protectedWall('nested')): path.join('assets', 'nested.asset'),
    });
  });

  test('replacing a private group for a new owner drops the previous owner private groups', () async {
    app_state.prismUser = profileUser(id: 'owner-a');
    await NativeAssetPathsStore.replaceGroup('category', <String, String>{'category-wall': 'assets/public.asset'});
    await NativeAssetPathsStore.replaceGroup('favourites', <String, String>{'wall-a': 'assets/a.asset'});

    app_state.prismUser = profileUser(id: 'owner-b');
    await NativeAssetPathsStore.replaceGroup('shortcuts', <String, String>{'wall-b': 'b.jpg'});

    final SharedPreferences prefs = await SharedPreferences.getInstance();
    expect(jsonDecode(prefs.getString(NativeAssetPathsStore.preferenceKey)!), <String, String>{
      'category-wall': 'assets/public.asset',
      'wall-b': 'b.jpg',
    });
    expect(jsonDecode(prefs.getString('${NativeAssetPathsStore.preferenceKey}.favourites')!), isEmpty);
  });

  test('does not execute an owner A private write after switching to owner B', () async {
    app_state.prismUser = profileUser(id: 'owner-a');
    final Completer<void> firstReplace = Completer<void>();
    final Completer<void> allowFirstReplace = Completer<void>();
    final Future<void> first = NativeAssetPathsStore.replaceGroup(
      'category',
      <String, String>{'category-wall': 'assets/public.asset'},
      afterReplace: () async {
        firstReplace.complete();
        await allowFirstReplace.future;
      },
    );
    await firstReplace.future;
    final Future<void> queuedAWrite = NativeAssetPathsStore.replaceGroup('favourites', <String, String>{
      'wall-a': 'assets/a.asset',
    });
    app_state.prismUser = profileUser(id: 'owner-b');
    allowFirstReplace.complete();
    await Future.wait(<Future<void>>[first, queuedAWrite]);

    final SharedPreferences prefs = await SharedPreferences.getInstance();
    expect(prefs.getString('${NativeAssetPathsStore.preferenceKey}.favourites'), isNull);
    expect(prefs.getString(NativeAssetPathsStore.privateOwnerKey), isNull);
  });

  test('keeps a queued public category update when the account changes', () async {
    app_state.prismUser = profileUser(id: 'owner-a');
    final Completer<void> firstReplace = Completer<void>();
    final Completer<void> allowFirstReplace = Completer<void>();
    final Future<void> first = NativeAssetPathsStore.replaceGroup(
      'category',
      <String, String>{'old-category': 'assets/old.asset'},
      afterReplace: () async {
        firstReplace.complete();
        await allowFirstReplace.future;
      },
    );
    await firstReplace.future;
    final Future<void> queuedCategory = NativeAssetPathsStore.replaceGroup('category', <String, String>{
      'new-category': 'assets/new.asset',
    });
    app_state.prismUser = profileUser(id: 'owner-b');
    allowFirstReplace.complete();
    await Future.wait(<Future<void>>[first, queuedCategory]);

    final SharedPreferences prefs = await SharedPreferences.getInstance();
    expect(jsonDecode(prefs.getString('${NativeAssetPathsStore.preferenceKey}.category')!), <String, String>{
      'new-category': 'assets/new.asset',
    });
    expect(prefs.getString(NativeAssetPathsStore.privateOwnerKey), isNull);
  });
}
