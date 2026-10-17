import 'dart:io';

import 'package:Prism/core/persistence/data_sources/settings_local_data_source.dart';
import 'package:Prism/core/platform/pigeon/prism_media_api.g.dart';
import 'package:Prism/core/wallpaper/wallpaper_source.dart';
import 'package:Prism/features/wallpaper_detail/data/downloaded_wall_index.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../support/in_memory_local_store.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late DownloadedWallIndex index;

  setUp(() => index = DownloadedWallIndex(SettingsLocalDataSource(InMemoryLocalStore())));

  test('resolves a remembered Prism download by its file name', () async {
    await index.remember(
      link: 'https://raw.githubusercontent.com/o/r/main/image_picker1529041162.png',
      id: 'abc123',
      source: WallpaperSource.prism,
    );

    expect(index.resolve('/Pictures/Prism/Downloads/image_picker1529041162.jpg'), (
      id: 'abc123',
      source: WallpaperSource.prism,
    ));
    expect(index.resolve('/Pictures/Prism/Downloads/image_picker1529041162 (1).jpg')?.id, 'abc123');
  });

  test('legacy basename rows resolve navigation identity but never acquisition', () {
    final InMemoryLocalStore store = InMemoryLocalStore()
      ..data['settings.downloaded_walls_v1'] = '{"legacy-wall":{"id":"legacy-id","source":"prism"}}';
    final DownloadedWallIndex legacyIndex = DownloadedWallIndex(SettingsLocalDataSource(store));

    expect(legacyIndex.resolve('/Pictures/legacy-wall.jpg'), (id: 'legacy-id', source: WallpaperSource.prism));
    expect(legacyIndex.has('https://example.com/legacy-wall.jpg'), isFalse);
    expect(
      legacyIndex.hasAcquired(
        link: 'https://example.com/legacy-wall.jpg',
        id: 'legacy-id',
        source: WallpaperSource.prism,
      ),
      isFalse,
    );
  });

  test('ambiguous legacy basenames do not resolve to either wallpaper', () {
    final InMemoryLocalStore store = InMemoryLocalStore()
      ..data['settings.downloaded_walls_v1'] =
          '{"legacy-wall":{"id":"legacy-a","source":"prism"},"legacy-wall (1)":{"id":"legacy-b","source":"pexels"}}';
    final DownloadedWallIndex legacyIndex = DownloadedWallIndex(SettingsLocalDataSource(store));

    expect(legacyIndex.resolve('/Pictures/legacy-wall (1).jpg'), isNull);
  });

  test('a legacy identity resolves its native download only when source and id match', () async {
    final InMemoryLocalStore store = InMemoryLocalStore()
      ..data['settings.downloaded_walls_v1'] = '{"legacy-wall":{"id":"legacy-id","source":"prism"}}';
    final DownloadedWallIndex legacyIndex = DownloadedWallIndex(SettingsLocalDataSource(store));
    final Directory directory = Directory.systemTemp.createTempSync('prism_legacy_download');
    addTearDown(() => directory.deleteSync(recursive: true));
    final File saved = File('${directory.path}/legacy-wall.jpg')..writeAsBytesSync(<int>[1]);
    const BasicMessageChannel<Object?> channel = BasicMessageChannel<Object?>(
      'dev.flutter.pigeon.Prism.PrismMediaHostApi.listDownloads',
      PrismMediaHostApi.pigeonChannelCodec,
    );
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockDecodedMessageHandler<Object?>(
      channel,
      (_) async => <Object?>[
        DownloadItemsResult(success: true, items: <String>[saved.path]),
      ],
    );
    addTearDown(
      () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockDecodedMessageHandler<Object?>(
        channel,
        null,
      ),
    );

    expect(
      (await legacyIndex.localFileFor(
        link: 'https://example.com/legacy-wall.jpg',
        id: 'legacy-id',
        source: WallpaperSource.prism,
      ))?.path,
      saved.path,
    );
    expect(
      await legacyIndex.localFileFor(
        link: 'https://example.com/legacy-wall.jpg',
        id: 'different-id',
        source: WallpaperSource.prism,
      ),
      isNull,
    );
  });

  test('legacy native verification requires the indexed image file to exist and decode', () async {
    final InMemoryLocalStore store = InMemoryLocalStore()
      ..data['settings.downloaded_walls_v1'] = '{"legacy-wall":{"id":"legacy-id","source":"prism"}}';
    final DownloadedWallIndex legacyIndex = DownloadedWallIndex(SettingsLocalDataSource(store));
    final Directory directory = Directory.systemTemp.createTempSync('prism_verified_legacy_download');
    addTearDown(() => directory.deleteSync(recursive: true));
    final File saved = File('${directory.path}/legacy-wall.jpg')
      ..writeAsBytesSync(File('assets/images/prism.webp').readAsBytesSync());
    const BasicMessageChannel<Object?> channel = BasicMessageChannel<Object?>(
      'dev.flutter.pigeon.Prism.PrismMediaHostApi.listDownloads',
      PrismMediaHostApi.pigeonChannelCodec,
    );
    var listedFiles = <String>[saved.path];
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockDecodedMessageHandler<Object?>(
      channel,
      (_) async => <Object?>[DownloadItemsResult(success: true, items: listedFiles)],
    );
    addTearDown(
      () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockDecodedMessageHandler<Object?>(
        channel,
        null,
      ),
    );

    expect(await legacyIndex.hasVerifiedLegacyNativeFile('https://example.com/legacy-wall.jpg'), isTrue);
    expect(legacyIndex.has('https://example.com/legacy-wall.jpg'), isFalse);
    expect(
      legacyIndex.hasAcquired(
        link: 'https://example.com/legacy-wall.jpg',
        id: 'legacy-id',
        source: WallpaperSource.prism,
      ),
      isFalse,
    );

    await saved.writeAsBytes(<int>[1]);
    expect(await legacyIndex.hasVerifiedLegacyNativeFile('https://example.com/legacy-wall.jpg'), isFalse);

    await saved.writeAsBytes(File('assets/images/prism.webp').readAsBytesSync());
    saved.deleteSync();
    listedFiles = <String>[saved.path];
    expect(await legacyIndex.hasVerifiedLegacyNativeFile('https://example.com/legacy-wall.jpg'), isFalse);

    listedFiles = <String>[];
    expect(await legacyIndex.hasVerifiedLegacyNativeFile('https://example.com/legacy-wall.jpg'), isFalse);
  });

  test('a cold-restarted index resolves an acquired native download by exact identity', () async {
    final InMemoryLocalStore store = InMemoryLocalStore();
    final DownloadedWallIndex firstRun = DownloadedWallIndex(
      SettingsLocalDataSource(store),
      ownerId: () => 'account-a',
    );
    await firstRun.remember(
      link: 'https://example.com/a/wall.jpg',
      id: 'wall-a',
      source: WallpaperSource.prism,
      ownerId: 'account-a',
    );
    final Directory directory = Directory.systemTemp.createTempSync('prism_restarted_download');
    addTearDown(() => directory.deleteSync(recursive: true));
    final File saved = File('${directory.path}/wall.jpg')..writeAsBytesSync(<int>[1]);
    const BasicMessageChannel<Object?> channel = BasicMessageChannel<Object?>(
      'dev.flutter.pigeon.Prism.PrismMediaHostApi.listDownloads',
      PrismMediaHostApi.pigeonChannelCodec,
    );
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockDecodedMessageHandler<Object?>(
      channel,
      (_) async => <Object?>[
        DownloadItemsResult(success: true, items: <String>[saved.path]),
      ],
    );
    addTearDown(
      () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockDecodedMessageHandler<Object?>(
        channel,
        null,
      ),
    );

    final DownloadedWallIndex coldStart = DownloadedWallIndex(
      SettingsLocalDataSource(store),
      ownerId: () => 'account-a',
    );

    expect(
      (await coldStart.localFileFor(
        link: 'https://example.com/a/wall.jpg',
        id: 'wall-a',
        source: WallpaperSource.prism,
      ))?.path,
      saved.path,
    );
  });

  test('prefers an exact remembered name before interpreting a duplicate suffix', () async {
    await index.remember(link: 'https://example.com/image_picker.png', id: 'original', source: WallpaperSource.prism);
    await index.remember(
      link: 'https://example.com/image_picker%20(1).png',
      id: 'copy',
      source: WallpaperSource.pexels,
    );

    expect(index.resolve('/Pictures/image_picker (1).jpg'), (id: 'copy', source: WallpaperSource.pexels));
  });

  test('parses Wallhaven and Pexels ids from older downloads', () {
    expect(index.resolve('/d/wallhaven-mlp858 (1).jpg'), (id: 'mlp858', source: WallpaperSource.wallhaven));
    expect(index.resolve('/d/pexels-photo-1563016.jpeg.jpg'), (id: '1563016', source: WallpaperSource.pexels));
    expect(index.resolve('/d/pexels-photo-123abc.jpg'), isNull);
  });

  test('a persistence failure does not fail a completed download callback or erase old entries', () async {
    final FailingSetLocalStore store = FailingSetLocalStore();
    store.data['settings.downloaded_walls_v1'] = '{"existing":{"id":"old","source":"prism"}}';
    final DownloadedWallIndex failingIndex = DownloadedWallIndex(SettingsLocalDataSource(store));

    await expectLater(
      failingIndex.remember(link: 'https://example.com/new.png', id: 'new', source: WallpaperSource.prism),
      completes,
    );
    expect(failingIndex.resolve('/d/existing.jpg'), (id: 'old', source: WallpaperSource.prism));
  });

  test('has() is true for a remembered link, whatever the extension, and false for others', () async {
    await index.remember(link: 'https://example.com/a/image_picker1.png', id: 'w1', source: WallpaperSource.prism);

    expect(index.has('https://example.com/a/image_picker1.png'), isTrue);
    expect(index.has('https://example.com/b/image_picker1.jpg'), isFalse);
    expect(index.has('https://example.com/a/image_picker2.png'), isFalse);
  });

  test('an acquired download is not visible as acquired after an account switch', () async {
    String owner = 'account-a';
    final InMemoryLocalStore backing = InMemoryLocalStore();
    final DownloadedWallIndex accountIndex = DownloadedWallIndex(
      SettingsLocalDataSource(backing),
      ownerId: () => owner,
    );
    await accountIndex.remember(link: 'https://example.com/wall.jpg', id: 'wall-a', source: WallpaperSource.prism);

    expect(
      accountIndex.hasAcquired(link: 'https://example.com/wall.jpg', id: 'wall-a', source: WallpaperSource.prism),
      isTrue,
    );
    final DownloadedWallIndex restartedIndex = DownloadedWallIndex(
      SettingsLocalDataSource(backing),
      ownerId: () => owner,
    );
    expect(
      restartedIndex.hasAcquired(link: 'https://example.com/wall.jpg', id: 'wall-a', source: WallpaperSource.prism),
      isTrue,
    );
    owner = 'account-b';
    expect(
      accountIndex.hasAcquired(link: 'https://example.com/wall.jpg', id: 'wall-a', source: WallpaperSource.prism),
      isFalse,
    );
    expect(accountIndex.resolve('/d/wall.jpg'), isNull);
  });

  test('a same-basename URL on another account is not treated as the acquired wallpaper', () async {
    String owner = 'account-a';
    final DownloadedWallIndex accountIndex = DownloadedWallIndex(
      SettingsLocalDataSource(InMemoryLocalStore()),
      ownerId: () => owner,
    );
    await accountIndex.remember(
      link: 'https://account-a.example/shared.jpg',
      id: 'shared-id',
      source: WallpaperSource.prism,
    );

    owner = 'account-b';
    expect(
      accountIndex.hasAcquired(
        link: 'https://account-b.example/shared.jpg',
        id: 'shared-id',
        source: WallpaperSource.prism,
      ),
      isFalse,
    );
    expect(accountIndex.has('https://account-b.example/shared.jpg'), isFalse);
  });

  test('clear() forgets every entry', () async {
    await index.remember(link: 'https://example.com/one.png', id: 'w1', source: WallpaperSource.prism);
    await index.remember(link: 'https://example.com/two.png', id: 'w2', source: WallpaperSource.prism);

    await index.clear();

    expect(index.has('https://example.com/one.png'), isFalse);
    expect(index.resolve('/d/two.jpg'), isNull);
  });

  test('clearOwner removes only that account acquisitions', () async {
    final InMemoryLocalStore store = InMemoryLocalStore();
    final DownloadedWallIndex accountA = DownloadedWallIndex(
      SettingsLocalDataSource(store),
      ownerId: () => 'account-a',
    );
    final DownloadedWallIndex accountB = DownloadedWallIndex(
      SettingsLocalDataSource(store),
      ownerId: () => 'account-b',
    );
    await accountA.remember(link: 'https://example.test/a.jpg', id: 'wall-a', source: WallpaperSource.prism);
    await accountB.remember(link: 'https://example.test/b.jpg', id: 'wall-b', source: WallpaperSource.pexels);

    await accountA.clearOwner('account-a');

    expect(
      accountA.hasAcquired(link: 'https://example.test/a.jpg', id: 'wall-a', source: WallpaperSource.prism),
      isFalse,
    );
    expect(
      accountB.hasAcquired(link: 'https://example.test/b.jpg', id: 'wall-b', source: WallpaperSource.pexels),
      isTrue,
    );
  });

  test('forget() drops the entry of a deleted file', () async {
    await index.remember(link: 'https://example.com/one.png', id: 'w1', source: WallpaperSource.prism);
    await index.remember(link: 'https://example.com/two.png', id: 'w2', source: WallpaperSource.prism);

    await index.forget(<String>['/d/one.jpg'], remainingPaths: <String>['/d/two.jpg']);

    expect(index.has('https://example.com/one.png'), isFalse);
    expect(index.has('https://example.com/two.png'), isTrue);
  });

  test('forget() keeps the entry while a copy of the file is left', () async {
    await index.remember(link: 'https://example.com/one.png', id: 'w1', source: WallpaperSource.prism);

    await index.forget(<String>['/d/one.jpg'], remainingPaths: <String>['/d/one (1).jpg']);
    expect(index.resolve('/d/one (1).jpg')?.id, 'w1');

    await index.forget(<String>['/d/one (1).jpg'], remainingPaths: const <String>[]);
    expect(index.has('https://example.com/one.png'), isFalse);
  });

  test('a copy of another wall with the same file name opens its own wall, not the first one', () async {
    await index.remember(link: 'https://example.com/shared.png', id: 'first', source: WallpaperSource.prism);
    await index.remember(link: 'https://example.com/shared%20(1).png', id: 'second', source: WallpaperSource.prism);

    expect(index.resolve('/d/shared (1).jpg')?.id, 'second');
    expect(index.resolve('/d/shared.jpg')?.id, 'first');
  });

  test('ambiguous same-basename acquisitions do not resolve to the wrong wallpaper', () async {
    await index.remember(link: 'https://a.test/shared.jpg', id: 'first', source: WallpaperSource.prism);
    await index.remember(link: 'https://b.test/shared.jpg', id: 'second', source: WallpaperSource.pexels);

    expect(index.has('https://a.test/shared.jpg'), isTrue);
    expect(index.has('https://b.test/shared.jpg'), isTrue);
    expect(index.resolve('/d/shared.jpg'), isNull);
  });

  test('ambiguous same-basename acquisitions cannot adopt either native file by exact URL', () async {
    await index.remember(link: 'https://a.test/shared.jpg', id: 'first', source: WallpaperSource.prism);
    await index.remember(link: 'https://b.test/shared.jpg', id: 'second', source: WallpaperSource.pexels);
    final Directory directory = Directory.systemTemp.createTempSync('prism_ambiguous_download');
    addTearDown(() => directory.deleteSync(recursive: true));
    final File saved = File('${directory.path}/shared.jpg')..writeAsBytesSync(<int>[1]);
    const BasicMessageChannel<Object?> channel = BasicMessageChannel<Object?>(
      'dev.flutter.pigeon.Prism.PrismMediaHostApi.listDownloads',
      PrismMediaHostApi.pigeonChannelCodec,
    );
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockDecodedMessageHandler<Object?>(
      channel,
      (_) async => <Object?>[
        DownloadItemsResult(success: true, items: <String>[saved.path]),
      ],
    );
    addTearDown(
      () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockDecodedMessageHandler<Object?>(
        channel,
        null,
      ),
    );

    expect(await index.localFileForLink('https://a.test/shared.jpg'), isNull);
    expect(
      await index.localFileFor(link: 'https://b.test/shared.jpg', id: 'second', source: WallpaperSource.pexels),
      isNull,
    );
  });

  test('returns null for unknown files', () {
    expect(index.resolve('/d/image_picker42.jpg'), isNull);
    expect(index.resolve('/d/default_1700000000.png'), isNull);
  });
}

class FailingSetLocalStore extends InMemoryLocalStore {
  @override
  Future<void> set(String key, Object? value) => Future<void>.error(StateError('set failed'));
}
