import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:Prism/core/cache/prism_full_image_cache.dart';
import 'package:Prism/core/offline/durable_json_store.dart';
import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';

class OfflineAssetStore {
  OfflineAssetStore({
    Directory? directory,
    BaseCacheManager? cacheManager,
    this.maxRetainedBytes = defaultMaxRetainedBytes,
    this.maxRetainedAssets = defaultMaxRetainedAssets,
  }) : _directoryOverride = directory,
       _cacheManagerOverride = cacheManager {
    if (maxRetainedBytes < 0 ||
        maxRetainedBytes > defaultMaxRetainedBytes ||
        maxRetainedAssets < 0 ||
        maxRetainedAssets > defaultMaxRetainedAssets) {
      throw ArgumentError('Retained asset limits must stay within the hard caps.');
    }
  }

  static const int defaultMaxRetainedBytes = 512 * 1024 * 1024;
  static const int defaultMaxRetainedAssets = 500;
  static final OfflineAssetStore _defaultInstance = OfflineAssetStore();
  static OfflineAssetStore instance = _defaultInstance;
  static OfflineAssetStore? _testOverride;

  @visibleForTesting
  static OfflineAssetStore? get testOverride => _testOverride;

  @visibleForTesting
  static set testOverride(OfflineAssetStore? value) {
    _testOverride = value;
    instance = value ?? _defaultInstance;
  }

  final Directory? _directoryOverride;
  final BaseCacheManager? _cacheManagerOverride;
  final int maxRetainedBytes;
  final int maxRetainedAssets;
  Future<void> _writeTail = Future<void>.value();
  Future<void>? _ready;
  Future<DurableJsonStore>? _manifestStore;
  Directory? _resolvedRoot;
  final Map<String, _PendingRetain> _retains = <String, _PendingRetain>{};
  int _fileId = 0;

  Future<File?> lookup(String source) async {
    final local = File(source);
    if (await _verifiedFile(local)) return local;
    await _ensureReady();
    final manifest = await _manifest();
    final record = await manifest.read(source);
    if (record != null) {
      final retained = _fileForRecord(record);
      if (retained != null && await _matchesRecord(retained, record)) return retained;
      await _discardRecord(source, record, retained);
    }
    try {
      final cached = await _cacheManager.getFileFromCache(source);
      if (cached != null && await _verifiedFile(cached.file)) return cached.file;
    } on Exception {
      return null;
    }
    return null;
  }

  Future<File> resolve(String source, {bool allowNetwork = true}) async {
    final local = await lookup(source);
    if (local != null) return local;
    if (!allowNetwork) throw OfflineAssetUnavailableException(source);
    final downloaded = await _cacheManager.getSingleFile(source);
    if (!await _verifiedFile(downloaded)) {
      throw const FormatException('The downloaded asset is empty, unreadable, or not a supported image.');
    }
    return downloaded;
  }

  Future<File> retain(String source, {File? file}) {
    final pending = _retains[source];
    if (pending != null) return pending.future;
    final operation = _PendingRetain();
    _retains[source] = operation;
    final save = Future<File>(() async {
      final sourceFile = file ?? await resolve(source);
      return _serialize(() {
        if (operation.cancelled) throw OfflineAssetRetainCancelledException(source);
        return _retain(source, sourceFile);
      });
    });
    return operation.future = save.whenComplete(() {
      if (identical(_retains[source], operation)) _retains.remove(source);
    });
  }

  Future<Map<String, String>> localPaths() async {
    await _ensureReady();
    final manifest = await _manifest();
    final records = await manifest.readAll();
    final result = <String, String>{};
    for (final entry in records.entries.take(maxRetainedAssets)) {
      final file = _fileForRecord(entry.value);
      if (file != null && await _matchesRecord(file, entry.value)) {
        result[entry.key] = file.path;
      } else {
        await _discardRecord(entry.key, entry.value, file);
      }
    }
    return result;
  }

  Future<void> remove(String source) async {
    _retains.remove(source)?.cancelled = true;
    await _ensureReady();
    await _serialize(() async {
      final manifest = await _manifest();
      final record = await manifest.read(source);
      final file = record == null ? null : _fileForRecord(record);
      await manifest.delete(source);
      if (file != null && await _isConfinedRetainedFile(file) && await file.exists()) await file.delete();
    });
  }

  Future<void> clearRetained() async {
    for (final operation in _retains.values) {
      operation.cancelled = true;
    }
    _retains.clear();
    await _ensureReady();
    await _serialize(() async {
      final assets = await _assetsDirectory(create: true);
      if (await assets.exists()) await assets.delete(recursive: true);
      await assets.create(recursive: true);
      await (await _manifest()).clear();
    });
  }

  Future<int> get storedBytes async {
    await _ensureReady();
    final records = await (await _manifest()).readAll();
    var bytes = 0;
    for (final entry in records.entries.take(maxRetainedAssets)) {
      final file = _fileForRecord(entry.value);
      final recordBytes = entry.value['bytes'];
      if (file != null && recordBytes is int && await _matchesRecord(file, entry.value)) {
        bytes += recordBytes;
      } else {
        await _discardRecord(entry.key, entry.value, file);
      }
    }
    return bytes;
  }

  Future<File> _retain(String source, File suppliedFile) async {
    await _ensureReady();
    final manifest = await _manifest();
    final oldRecord = await manifest.read(source);
    final oldFile = oldRecord == null ? null : _fileForRecord(oldRecord);
    if (oldFile != null && suppliedFile.path == oldFile.path && await _matchesRecord(oldFile, oldRecord!)) {
      return oldFile;
    }
    final sourceLength = await _validatedImageLength(suppliedFile);
    if (sourceLength > maxRetainedBytes) throw OfflineAssetStoreLimitException(maxRetainedBytes);
    final records = await manifest.readAll();
    var retainedBytes = 0;
    var retainedCount = 0;
    for (final entry in records.entries.take(maxRetainedAssets)) {
      final retained = _fileForRecord(entry.value);
      final recordBytes = entry.value['bytes'];
      if (retained != null && recordBytes is int && await _matchesRecord(retained, entry.value)) {
        retainedCount++;
        retainedBytes += recordBytes;
      }
    }
    final oldBytes = oldRecord?['bytes'];
    final replacingValid = oldFile != null && oldBytes is int && await _matchesRecord(oldFile, oldRecord!);
    if (!replacingValid && retainedCount >= maxRetainedAssets) {
      throw OfflineAssetStoreLimitException(maxRetainedBytes, reason: 'The retained asset count limit is full.');
    }
    final replacedBytes = replacingValid ? oldBytes : 0;
    final totalAfterSave = retainedBytes - replacedBytes + sourceLength;
    if (totalAfterSave > maxRetainedBytes) throw OfflineAssetStoreLimitException(maxRetainedBytes);

    final assets = await _assetsDirectory(create: true);
    final basename = '${_sourceId(source)}-${DateTime.now().microsecondsSinceEpoch}-${_fileId++}.asset';
    final destination = File(path.join(assets.path, basename));
    final part = File('${destination.path}.part');
    try {
      await _copyAndFlush(suppliedFile, part, sourceLength);
      if (!await _verifiedFile(part) || await part.length() != sourceLength) {
        throw const FormatException('The retained asset copy is incomplete or invalid.');
      }
      await part.rename(destination.path);
      final relativePath = path.join('assets', basename);
      await manifest.write(source, <String, Object?>{'file': relativePath, 'bytes': sourceLength});
    } catch (_) {
      try {
        if (await part.exists()) await part.delete();
        if (await destination.exists()) await destination.delete();
      } on FileSystemException catch (cleanupError) {
        if (cleanupError.path != part.path && cleanupError.path != destination.path) rethrow;
      }
      rethrow;
    }
    if (oldFile != null && oldFile.path != destination.path && await oldFile.exists()) {
      try {
        await oldFile.delete();
      } on FileSystemException catch (cleanupError) {
        if (cleanupError.path != oldFile.path) rethrow;
      }
    }
    return destination;
  }

  Future<void> _copyAndFlush(File source, File target, int expectedLength) async {
    final input = await source.open();
    final output = await target.open(mode: FileMode.writeOnly);
    var copied = 0;
    try {
      while (true) {
        final chunk = await input.read(64 * 1024);
        if (chunk.isEmpty) break;
        copied += chunk.length;
        if (copied > expectedLength || copied > maxRetainedBytes) {
          throw OfflineAssetStoreLimitException(maxRetainedBytes);
        }
        await output.writeFrom(chunk);
      }
      if (copied != expectedLength) throw const FileSystemException('Asset changed while it was being retained.');
      await output.flush();
    } finally {
      await input.close();
      await output.close();
    }
  }

  Future<void> _discardRecord(String source, Map<String, Object?> expectedRecord, File? file) => _serialize(() async {
    final manifest = await _manifest();
    final current = await manifest.read(source);
    if (current == null || current['file'] != expectedRecord['file'] || current['bytes'] != expectedRecord['bytes']) {
      return;
    }
    await manifest.delete(source);
    if (file != null && await _isConfinedRetainedFile(file) && await file.exists()) await file.delete();
  });

  Future<int> _validatedImageLength(File file) async {
    final length = await file.length();
    if (length <= 0) throw const FormatException('Cannot retain an empty image.');
    if (!await _verifiedFile(file)) throw const FormatException('Cannot retain unreadable or unsupported image bytes.');
    return length;
  }

  Future<bool> _verifiedFile(File file) async {
    try {
      if (await FileSystemEntity.type(file.path, followLinks: false) != FileSystemEntityType.file ||
          await file.length() <= 0) {
        return false;
      }
      final handle = await file.open();
      late final Uint8List header;
      try {
        header = await handle.read(16);
      } finally {
        await handle.close();
      }
      return _isSupportedImage(header);
    } on FileSystemException {
      return false;
    }
  }

  bool _isSupportedImage(Uint8List bytes) =>
      (bytes.length >= 3 && bytes[0] == 0xff && bytes[1] == 0xd8 && bytes[2] == 0xff) ||
      (bytes.length >= 8 &&
          bytes[0] == 0x89 &&
          bytes[1] == 0x50 &&
          bytes[2] == 0x4e &&
          bytes[3] == 0x47 &&
          bytes[4] == 0x0d &&
          bytes[5] == 0x0a &&
          bytes[6] == 0x1a &&
          bytes[7] == 0x0a) ||
      (bytes.length >= 6 && ascii.decode(bytes.sublist(0, 6), allowInvalid: true).startsWith('GIF8')) ||
      (bytes.length >= 12 &&
          ascii.decode(bytes.sublist(0, 4), allowInvalid: true) == 'RIFF' &&
          ascii.decode(bytes.sublist(8, 12), allowInvalid: true) == 'WEBP') ||
      (bytes.length >= 2 && bytes[0] == 0x42 && bytes[1] == 0x4d) ||
      (bytes.length >= 12 &&
          ascii.decode(bytes.sublist(4, 8), allowInvalid: true) == 'ftyp' &&
          const <String>{
            'heic',
            'heix',
            'hevc',
            'mif1',
            'msf1',
            'avif',
          }.contains(ascii.decode(bytes.sublist(8, 12), allowInvalid: true)));

  Future<bool> _matchesRecord(File file, Map<String, Object?> record) async {
    try {
      final expectedBytes = record['bytes'];
      if (expectedBytes is! int ||
          expectedBytes <= 0 ||
          !await _isConfinedRetainedFile(file) ||
          await FileSystemEntity.type(file.path, followLinks: false) != FileSystemEntityType.file ||
          await file.length() != expectedBytes) {
        return false;
      }
      return await _verifiedFile(file);
    } on FileSystemException {
      return false;
    }
  }

  File? _fileForRecord(Map<String, Object?> record) {
    final relativePath = record['file'];
    if (relativePath is! String || path.isAbsolute(relativePath)) return null;
    final normalized = path.normalize(relativePath);
    if (!normalized.startsWith('assets${path.separator}') || path.split(normalized).length != 2) return null;
    final directory = _resolvedRoot;
    if (directory == null) return null;
    final candidate = File(path.join(directory.path, normalized));
    final relative = path.relative(candidate.path, from: directory.path);
    if (relative.startsWith('..${path.separator}') || path.isAbsolute(relative)) return null;
    return candidate;
  }

  Future<void> _ensureReady() {
    final existing = _ready;
    if (existing != null) return existing;
    final ready = _sweep();
    _ready = ready;
    return ready.catchError((Object error, StackTrace stackTrace) {
      _ready = null;
      Error.throwWithStackTrace(error, stackTrace);
    });
  }

  Future<void> _sweep() async {
    final root = await _rootDirectory();
    final assets = Directory(path.join(root.path, 'assets'));
    if (await FileSystemEntity.type(assets.path, followLinks: false) == FileSystemEntityType.link) return;
    if (!await assets.exists()) return;
    if (!await _isConfinedAssetsDirectory(assets)) return;
    final records = await (await _manifest()).readAll();
    final liveFiles = <String>{};
    for (final record in records.values.take(maxRetainedAssets)) {
      final file = _fileForRecord(record);
      if (file != null && await _matchesRecord(file, record)) liveFiles.add(path.normalize(file.path));
    }
    var scanned = 0;
    await for (final entity in assets.list(followLinks: false)) {
      if (scanned++ >= maxRetainedAssets * 2) break;
      if (entity is! File) continue;
      final normalized = path.normalize(entity.path);
      final isPart = path.extension(entity.path) == '.part';
      if (isPart || !liveFiles.contains(normalized)) {
        try {
          await entity.delete();
        } on FileSystemException {
          continue;
        }
      }
    }
  }

  Future<Directory> _rootDirectory() async {
    final root =
        _directoryOverride ??
        Directory(path.join((await getApplicationSupportDirectory()).path, 'prism', 'offline', 'assets'));
    _resolvedRoot = root;
    return root;
  }

  Future<Directory> _assetsDirectory({required bool create}) async {
    final root = await _rootDirectory();
    if (create) await root.create(recursive: true);
    if (!await root.exists()) throw FileSystemException('Retained root does not exist.', root.path);
    final assets = Directory(path.join(root.path, 'assets'));
    final type = await FileSystemEntity.type(assets.path, followLinks: false);
    if (type == FileSystemEntityType.link) {
      throw FileSystemException('Retained assets directory must not be a symlink.', assets.path);
    }
    if (create && type == FileSystemEntityType.notFound) await assets.create(recursive: true);
    if (!await _isConfinedAssetsDirectory(assets)) {
      throw FileSystemException('Retained assets directory is outside the retained root.', assets.path);
    }
    return assets;
  }

  Future<bool> _isConfinedAssetsDirectory(Directory assets) async {
    try {
      if (await FileSystemEntity.type(assets.path, followLinks: false) != FileSystemEntityType.directory) return false;
      final root = await _rootDirectory();
      final canonicalRoot = await root.resolveSymbolicLinks();
      final canonicalAssets = await assets.resolveSymbolicLinks();
      return path.equals(canonicalAssets, path.join(canonicalRoot, 'assets'));
    } on FileSystemException {
      return false;
    }
  }

  Future<bool> _isConfinedRetainedFile(File file) async {
    try {
      final assets = await _assetsDirectory(create: false);
      if (await FileSystemEntity.type(file.path, followLinks: false) != FileSystemEntityType.file) return false;
      final canonicalAssets = await assets.resolveSymbolicLinks();
      final canonicalFile = await file.resolveSymbolicLinks();
      return path.equals(path.dirname(canonicalFile), canonicalAssets) &&
          path.equals(canonicalFile, path.join(canonicalAssets, path.basename(file.path)));
    } on FileSystemException {
      return false;
    }
  }

  Future<DurableJsonStore> _manifest() =>
      _manifestStore ??= _rootDirectory().then((root) => DurableJsonStore('asset_manifest', directory: root));

  BaseCacheManager get _cacheManager => _cacheManagerOverride ?? PrismFullImageCache.instance;

  Future<T> _serialize<T>(Future<T> Function() operation) {
    final result = _writeTail.then((_) => operation());
    _writeTail = result.then<void>((_) {}, onError: (Object _, StackTrace _) {});
    return result;
  }

  static String _sourceId(String source) => sha256.convert(utf8.encode(source)).toString();
}

class _PendingRetain {
  late Future<File> future;
  bool cancelled = false;
}

class OfflineAssetRetainCancelledException implements Exception {
  const OfflineAssetRetainCancelledException(this.source);

  final String source;

  @override
  String toString() => 'The pending retain for $source was cancelled.';
}

class OfflineAssetStoreLimitException implements Exception {
  const OfflineAssetStoreLimitException(this.limit, {this.reason = 'The retained asset byte limit is full.'});

  final int limit;
  final String reason;

  @override
  String toString() => 'OfflineAssetStoreLimitException($limit): $reason';
}

class OfflineAssetUnavailableException implements Exception {
  const OfflineAssetUnavailableException(this.source);

  final String source;

  @override
  String toString() => 'No local asset is available for $source.';
}
