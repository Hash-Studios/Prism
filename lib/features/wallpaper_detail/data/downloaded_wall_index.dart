import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:Prism/core/persistence/data_sources/settings_local_data_source.dart';
import 'package:Prism/core/platform/pigeon/prism_media_api.g.dart';
import 'package:Prism/core/state/app_state.dart' as app_state;
import 'package:Prism/core/utils/url_utils.dart';
import 'package:Prism/core/wallpaper/wallpaper_source.dart';
import 'package:Prism/logger/logger.dart';
import 'package:injectable/injectable.dart';
import 'package:path/path.dart' as p;

typedef DownloadedWallRef = ({String id, WallpaperSource source});

/// Maps a downloaded file back to its wallpaper, so Downloads can open the detail screen.
/// Prism files keep their upload name, so only downloads made after this index existed resolve.
@lazySingleton
class DownloadedWallIndex {
  DownloadedWallIndex(this._settingsLocal, {@ignoreParam String Function()? ownerId})
    : _ownerId = ownerId ?? (() => app_state.prismUser.id);

  final SettingsLocalDataSource _settingsLocal;
  final String Function() _ownerId;

  static const String _key = 'downloaded_walls_v1';
  static final RegExp _copySuffix = RegExp(r' \(\d+\)$');
  static final RegExp _historicalTintSuffix = RegExp(r'_tint-[0-9a-f]{6}(?: \(\d+\))?$', caseSensitive: false);
  static final RegExp _wallhavenName = RegExp(r'^wallhaven-([a-z0-9]+)(?:\.(?:jpeg|jpg|png|webp|gif))?$');
  static final RegExp _pexelsName = RegExp(r'^pexels-photo-(\d+)(?:\.(?:jpeg|jpg|png|webp|gif))?$');

  String get _currentOwner => _ownerId().trim().isEmpty ? 'guest' : _ownerId().trim();

  Map<String, Object?> _read() {
    try {
      final Object? decoded = json.decode(_settingsLocal.get<String>(_key, defaultValue: '{}'));
      return decoded is Map ? Map<String, Object?>.from(decoded) : <String, Object?>{};
    } catch (_) {
      return <String, Object?>{};
    }
  }

  Future<void> remember({
    required String link,
    required String id,
    required WallpaperSource source,
    String? ownerId,
    bool original = true,
  }) async {
    final String requestedOwner = (ownerId ?? _ownerId()).trim();
    final String owner = requestedOwner.isEmpty ? 'guest' : requestedOwner;
    if (link.trim().isEmpty || id.trim().isEmpty || source == WallpaperSource.unknown) return;
    final Map<String, Object?> index = _read()
      ..[_acquisitionKey(owner: owner, link: link, id: id, source: source)] = <String, Object?>{
        'owner': owner,
        'link': link,
        'id': id,
        'source': source.wireValue,
        'acquired': true,
        'original': original,
      };
    try {
      await _settingsLocal.set(_key, json.encode(index));
    } catch (error, stackTrace) {
      logger.w('Unable to remember downloaded wallpaper', error: error, stackTrace: stackTrace);
    }
  }

  bool has(String link) {
    final Set<(String, WallpaperSource)> identities = _records()
        .where((record) => record.owner == _currentOwner && record.link == link)
        .map((record) => (record.id, record.source))
        .toSet();
    return identities.length == 1;
  }

  bool hasAcquired({required String link, required String id, required WallpaperSource source}) => _records().any(
    (record) => record.owner == _currentOwner && record.link == link && record.id == id && record.source == source,
  );

  /// Legacy recovery evidence only. Index metadata must also resolve to a current, decodable native image.
  Future<bool> hasVerifiedLegacyNativeFile(String link) async {
    final String expectedName = downloadBaseName(link);
    final Object? legacyValue = _read()[expectedName];
    if (legacyValue is! Map ||
        legacyValue['id'] is! String ||
        (legacyValue['id'] as String).isEmpty ||
        WallpaperSourceX.fromWire(legacyValue['source']) == WallpaperSource.unknown ||
        _hasAmbiguousBasename(expectedName)) {
      return false;
    }

    final File? file = await _listedFileForName(expectedName);
    if (file == null) return false;
    ui.Codec? codec;
    try {
      final bytes = await file.readAsBytes();
      codec = await ui.instantiateImageCodec(bytes);
      final ui.FrameInfo frame = await codec.getNextFrame();
      frame.image.dispose();
      return true;
    } catch (_) {
      return false;
    } finally {
      codec?.dispose();
    }
  }

  /// Forgets everything. Used by Clear downloads and when the account data is wiped.
  Future<void> clear() async {
    try {
      await _settingsLocal.set(_key, '{}');
    } catch (error, stackTrace) {
      logger.w('Unable to clear the downloaded wallpaper index', error: error, stackTrace: stackTrace);
    }
  }

  Future<void> clearOwner(String userId) async {
    final String requestedOwner = userId.trim().isEmpty ? 'guest' : userId.trim();
    final Map<String, Object?> index = _read();
    final List<String> ownedKeys = index.entries
        .where((entry) => _decode(entry.key, entry.value)?.owner == requestedOwner)
        .map((entry) => entry.key)
        .toList(growable: false);
    if (ownedKeys.isEmpty) return;
    for (final String key in ownedKeys) {
      index.remove(key);
    }
    try {
      await _settingsLocal.set(_key, json.encode(index));
    } catch (error, stackTrace) {
      logger.w(
        'Unable to clear downloaded wallpaper acquisitions for an account',
        error: error,
        stackTrace: stackTrace,
      );
    }
  }

  /// Drops the entries of deleted files. An entry stays while a file that still exists uses it, so deleting
  /// `name.jpg` keeps the entry for `name (1).jpg`. [remainingPaths] are the files that are left.
  Future<void> forget(Iterable<String> deletedPaths, {required Iterable<String> remainingPaths}) async {
    final Set<String> remaining = remainingPaths.map(p.basenameWithoutExtension).toSet();
    final Set<String> stillUsed = <String>{...remaining, ...remaining.map(_withoutCopySuffix)};
    final Set<String> candidates = deletedPaths.map(p.basenameWithoutExtension).expand((name) {
      return <String>{name, _withoutCopySuffix(name)};
    }).toSet()..removeAll(stillUsed);
    final Map<String, Object?> index = _read();
    final Iterable<String> removable = index.entries
        .where((entry) {
          final _AcquiredWall? record = _decode(entry.key, entry.value);
          if (record == null) {
            final Object? value = entry.value;
            return value is Map &&
                value['id'] is String &&
                WallpaperSourceX.fromWire(value['source']) != WallpaperSource.unknown &&
                candidates.contains(entry.key);
          }
          if (record.owner != _currentOwner) return false;
          final String name = downloadBaseName(record.link);
          return candidates.contains(name);
        })
        .map((entry) => entry.key);
    final List<String> keys = removable.toList(growable: false);
    if (keys.isEmpty) return;
    keys.forEach(index.remove);
    try {
      await _settingsLocal.set(_key, json.encode(index));
    } catch (error, stackTrace) {
      logger.w('Unable to forget deleted wallpapers', error: error, stackTrace: stackTrace);
    }
  }

  static String _withoutCopySuffix(String name) => name.replaceFirst(_copySuffix, '');

  DownloadedWallRef? resolve(String filePath) {
    final String name = p.basenameWithoutExtension(filePath);
    final String withoutCopySuffix = _withoutCopySuffix(name);
    final List<DownloadedWallRef> exact = _records()
        .where((record) => record.owner == _currentOwner && downloadBaseName(record.link) == name)
        .map((record) => (id: record.id, source: record.source))
        .toList(growable: true);
    final Set<DownloadedWallRef> exactIdentities = exact.toSet();
    if (exactIdentities.length == 1) return exactIdentities.single;
    if (exactIdentities.length > 1) return null;

    final List<DownloadedWallRef> identities = _records()
        .where(
          (record) =>
              record.owner == _currentOwner &&
              <String>{
                downloadBaseName(record.link),
                _withoutCopySuffix(downloadBaseName(record.link)),
              }.contains(withoutCopySuffix),
        )
        .map((record) => (id: record.id, source: record.source))
        .toList(growable: true);

    final Map<String, Object?> legacy = _read();
    for (final MapEntry<String, Object?> entry in legacy.entries) {
      if (_withoutCopySuffix(p.basenameWithoutExtension(entry.key)) != withoutCopySuffix || entry.value is! Map) {
        continue;
      }
      final Map value = entry.value! as Map;
      final Object? id = value['id'];
      final WallpaperSource source = WallpaperSourceX.fromWire(value['source']);
      if (id is String && id.isNotEmpty && source != WallpaperSource.unknown) {
        identities.add((id: id, source: source));
      }
    }
    final Set<DownloadedWallRef> uniqueIdentities = identities.toSet();
    if (uniqueIdentities.length == 1) return uniqueIdentities.single;
    if (uniqueIdentities.length > 1) return null;

    final String? wallhavenId = _wallhavenName.firstMatch(withoutCopySuffix)?.group(1);
    if (wallhavenId != null) return (id: wallhavenId, source: WallpaperSource.wallhaven);
    final String? pexelsId = _pexelsName.firstMatch(withoutCopySuffix)?.group(1);
    if (pexelsId != null) return (id: pexelsId, source: WallpaperSource.pexels);
    return null;
  }

  Future<File?> localFileFor({required String link, required String id, required WallpaperSource source}) async {
    final String expectedName = downloadBaseName(link);
    final bool currentIdentity = _records().any(
      (record) => record.owner == _currentOwner && record.link == link && record.id == id && record.source == source,
    );
    final Object? legacyValue = _read()[expectedName];
    final bool legacyIdentity =
        legacyValue is Map && legacyValue['id'] == id && WallpaperSourceX.fromWire(legacyValue['source']) == source;
    if ((!currentIdentity && !legacyIdentity) || _hasAmbiguousBasename(expectedName)) return null;

    return _listedFileForName(expectedName);
  }

  Future<File?> localFileForIdentity({required String id, required WallpaperSource source}) async {
    final owner = _currentOwner;
    final names = _records()
        .where((record) => record.owner == owner && record.id == id && record.source == source && record.original)
        .map((record) => downloadBaseName(record.link))
        .toSet();
    final files = <String, File>{};
    for (final name in names) {
      if (_hasAmbiguousBasename(name)) continue;
      final file = await _listedFileForName(name);
      if (_currentOwner != owner) return null;
      if (file != null) files[file.path] = file;
    }
    return files.length == 1 ? files.values.single : null;
  }

  Future<File?> localFileForLink(String link) async {
    final List<_AcquiredWall> matches = _records()
        .where((record) => record.owner == _currentOwner && record.link == link)
        .toList(growable: false);
    if (matches.isEmpty || matches.map((record) => (record.id, record.source)).toSet().length != 1) return null;
    final String expectedName = downloadBaseName(link);
    if (_hasAmbiguousBasename(expectedName)) return null;
    return _listedFileForName(expectedName);
  }

  bool _hasAmbiguousBasename(String expectedName) {
    final String normalizedName = _withoutCopySuffix(expectedName);
    final Set<String> identities = _records()
        .where((record) => _withoutCopySuffix(downloadBaseName(record.link)) == normalizedName)
        .map((record) => '${record.id}\u0000${record.source.wireValue}')
        .toSet();
    for (final MapEntry<String, Object?> entry in _read().entries) {
      if (_withoutCopySuffix(p.basenameWithoutExtension(entry.key)) != normalizedName || entry.value is! Map) continue;
      final Map value = entry.value! as Map;
      final Object? id = value['id'];
      final WallpaperSource source = WallpaperSourceX.fromWire(value['source']);
      if (id is String && id.isNotEmpty && source != WallpaperSource.unknown) {
        identities.add('$id\u0000${source.wireValue}');
      }
    }
    return identities.length > 1;
  }

  Future<File?> _listedFileForName(String expectedName) async {
    try {
      final DownloadItemsResult result = await PrismMediaHostApi().listDownloads();
      if (!result.success) return null;
      final List<File> matches = result.items
          .where((filePath) {
            final String name = p.basenameWithoutExtension(filePath);
            return name == expectedName || _withoutCopySuffix(name) == expectedName;
          })
          .map(File.new)
          .where((file) => file.existsSync())
          .toList(growable: false);
      return matches.length == 1 ? matches.single : null;
    } catch (error, stackTrace) {
      logger.w('Could not resolve an existing native download', error: error, stackTrace: stackTrace);
      return null;
    }
  }

  List<_AcquiredWall> _records() => _read().entries.map((entry) => _decode(entry.key, entry.value)).nonNulls.toList();

  _AcquiredWall? _decode(String key, Object? value) {
    if (!key.startsWith('acquired:') || value is! Map) return null;
    final Object? owner = value['owner'];
    final Object? link = value['link'];
    final Object? id = value['id'];
    final WallpaperSource source = WallpaperSourceX.fromWire(value['source']);
    if (owner is! String || owner.isEmpty || link is! String || link.isEmpty || id is! String || id.isEmpty) {
      return null;
    }
    if (source == WallpaperSource.unknown || value['acquired'] != true) return null;
    return _AcquiredWall(
      owner: owner,
      link: link,
      id: id,
      source: source,
      original:
          value['original'] == true ||
          (value['original'] == null && !_historicalTintSuffix.hasMatch(downloadBaseName(link))),
    );
  }

  String _acquisitionKey({
    required String owner,
    required String link,
    required String id,
    required WallpaperSource source,
  }) => 'acquired:${base64Url.encode(utf8.encode(json.encode(<String>[owner, source.wireValue, id, link])))}';
}

class _AcquiredWall {
  const _AcquiredWall({
    required this.owner,
    required this.link,
    required this.id,
    required this.source,
    required this.original,
  });

  final String owner;
  final String link;
  final String id;
  final WallpaperSource source;
  final bool original;
}
