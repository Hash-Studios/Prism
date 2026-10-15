import 'dart:convert';

import 'package:Prism/core/persistence/data_sources/settings_local_data_source.dart';
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
  DownloadedWallIndex(this._settingsLocal);

  final SettingsLocalDataSource _settingsLocal;

  static const String _key = 'downloaded_walls_v1';
  static final RegExp _copySuffix = RegExp(r' \(\d+\)$');
  static final RegExp _wallhavenName = RegExp(r'^wallhaven-([a-z0-9]+)(?:\.(?:jpeg|jpg|png|webp|gif))?$');
  static final RegExp _pexelsName = RegExp(r'^pexels-photo-(\d+)(?:\.(?:jpeg|jpg|png|webp|gif))?$');

  Map<String, Object?> _read() {
    try {
      final Object? decoded = json.decode(_settingsLocal.get<String>(_key, defaultValue: '{}'));
      return decoded is Map ? Map<String, Object?>.from(decoded) : <String, Object?>{};
    } catch (_) {
      return <String, Object?>{};
    }
  }

  /// Records the URL-derived filename sent to the native download request.
  Future<void> remember({required String link, required String id, required WallpaperSource source}) async {
    final Map<String, Object?> index = _read()
      ..[downloadBaseName(link)] = <String, Object?>{'id': id, 'source': source.wireValue};
    try {
      await _settingsLocal.set(_key, json.encode(index));
    } catch (error, stackTrace) {
      logger.w('Unable to remember downloaded wallpaper', error: error, stackTrace: stackTrace);
    }
  }

  /// True when [link] was downloaded before and is still remembered. The file may have been moved since, so
  /// callers that charge for a download also check the file list.
  bool has(String link) => _read().containsKey(downloadBaseName(link));

  /// Forgets everything. Used by Clear downloads and when the account data is wiped.
  Future<void> clear() async {
    try {
      await _settingsLocal.set(_key, '{}');
    } catch (error, stackTrace) {
      logger.w('Unable to clear the downloaded wallpaper index', error: error, stackTrace: stackTrace);
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
    if (!candidates.any(index.containsKey)) return;
    candidates.forEach(index.remove);
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
    final Map<String, Object?> index = _read();

    DownloadedWallRef? readEntry(String key) {
      final Object? entry = index[key];
      if (entry is Map) {
        final Object? id = entry['id'];
        final WallpaperSource source = WallpaperSourceX.fromWire(entry['source']);
        if (id is String && id.isNotEmpty && source != WallpaperSource.unknown) return (id: id, source: source);
      }
      return null;
    }

    final DownloadedWallRef? exact = readEntry(name);
    if (exact != null) return exact;
    if (withoutCopySuffix != name) {
      final DownloadedWallRef? original = readEntry(withoutCopySuffix);
      if (original != null) return original;
    }

    final String? wallhavenId = _wallhavenName.firstMatch(withoutCopySuffix)?.group(1);
    if (wallhavenId != null) return (id: wallhavenId, source: WallpaperSource.wallhaven);
    final String? pexelsId = _pexelsName.firstMatch(withoutCopySuffix)?.group(1);
    if (pexelsId != null) return (id: pexelsId, source: WallpaperSource.pexels);
    return null;
  }
}
