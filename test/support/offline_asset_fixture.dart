import 'dart:convert';
import 'dart:io';

import 'package:Prism/core/offline/offline_asset_store.dart';
import 'package:flutter/services.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:flutter_cache_manager/file.dart' as cache_file;
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockCacheManager extends Mock implements BaseCacheManager {}

class _ImmediateResolverAssetStore extends OfflineAssetStore {
  _ImmediateResolverAssetStore({required this.filesBySource, required super.directory});

  final Map<String, File> filesBySource;

  @override
  Future<File?> lookup(String source) async => filesBySource[source];

  @override
  Future<File> resolve(String source, {bool allowNetwork = true}) async {
    final File? file = filesBySource[source];
    if (file != null) return file;
    throw OfflineAssetUnavailableException(source);
  }
}

class OfflineAssetFixture {
  OfflineAssetFixture._(this.directory, this.cacheManager, this.cacheMissByDefault)
    : _cacheKey = 'prism-offline-wallpaper-test-${directory.path.hashCode}';

  final Directory directory;
  final _MockCacheManager cacheManager;
  final bool cacheMissByDefault;
  final String _cacheKey;
  final Map<String, Future<cache_file.File>> _cacheFiles = <String, Future<cache_file.File>>{};
  final Map<String, File> _sourceFiles = <String, File>{};

  static Future<OfflineAssetFixture> create({bool cacheMissByDefault = false}) async {
    final Directory directory = await Directory.systemTemp.createTemp('prism-offline-wallpaper-test-');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
      const MethodChannel('plugins.flutter.io/path_provider'),
      (_) async => directory.path,
    );
    final _MockCacheManager cacheManager = _MockCacheManager();
    final OfflineAssetFixture fixture = OfflineAssetFixture._(directory, cacheManager, cacheMissByDefault);
    when(() => cacheManager.getFileFromCache(any())).thenAnswer((invocation) async {
      final String source = invocation.positionalArguments.single as String;
      if (fixture.cacheMissByDefault) return null;
      return FileInfo(await fixture.cachedImageFor(source), FileSource.Cache, DateTime(2000), source);
    });
    when(() => cacheManager.getSingleFile(any())).thenAnswer((_) async {
      throw StateError('Unexpected network request in offline wallpaper test.');
    });
    return fixture;
  }

  void install({bool immediateResolver = false}) {
    OfflineAssetStore.testOverride = immediateResolver
        ? _ImmediateResolverAssetStore(filesBySource: _sourceFiles, directory: Directory('${directory.path}/retained'))
        : OfflineAssetStore(directory: Directory('${directory.path}/retained'), cacheManager: cacheManager);
  }

  void mapSource(String source, File file) => _sourceFiles[source] = file;

  Future<cache_file.File> cachedImageFor(String source) => _cacheFiles.putIfAbsent(source, () async {
    final int index = _cacheFiles.length;
    final File image = createImageSync('cache-source-$index.jpg');
    final cache_file.File cached = await IOFileSystem(_cacheKey).createFile('cache-$index.jpg');
    await cached.writeAsBytes(await image.readAsBytes());
    return cached;
  });

  Future<File> createImage(String name) async {
    return createImageSync(name);
  }

  File createImageSync(String name) {
    final Directory images = Directory('${directory.path}/images');
    images.createSync(recursive: true);
    final File image = File('${images.path}/$name');
    image.writeAsBytesSync(base64Decode('R0lGODlhAQABAAD/ACwAAAAAAQABAAACADs='));
    _sourceFiles[image.path] = image;
    _sourceFiles[image.uri.toString()] = image;
    return image;
  }

  Future<String> cachedPathFor(String source) async => (await cachedImageFor(source)).path;

  Future<void> dispose() async {
    OfflineAssetStore.testOverride = null;
    for (final pendingFile in _cacheFiles.values) {
      final cacheDirectory = (await pendingFile).parent;
      if (await cacheDirectory.exists()) await cacheDirectory.delete(recursive: true);
    }
    if (await directory.exists()) await directory.delete(recursive: true);
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
      const MethodChannel('plugins.flutter.io/path_provider'),
      null,
    );
  }
}
