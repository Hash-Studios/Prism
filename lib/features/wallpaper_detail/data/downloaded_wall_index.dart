import 'dart:convert';

import 'package:Prism/core/persistence/data_sources/settings_local_data_source.dart';
import 'package:Prism/core/utils/url_utils.dart';
import 'package:Prism/core/wallpaper/wallpaper_source.dart';
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
  static final RegExp _wallhavenName = RegExp('^wallhaven-([a-z0-9]+)');
  static final RegExp _pexelsName = RegExp(r'^pexels-photo-(\d+)');

  Map<String, Object?> _read() {
    try {
      final Object? decoded = json.decode(_settingsLocal.get<String>(_key, defaultValue: '{}'));
      return decoded is Map ? Map<String, Object?>.from(decoded) : <String, Object?>{};
    } catch (_) {
      return <String, Object?>{};
    }
  }

  /// [link] is the URL handed to the download, so the key matches the saved file name.
  Future<void> remember({required String link, required String id, required WallpaperSource source}) {
    final Map<String, Object?> index = _read()
      ..[downloadBaseName(link)] = <String, Object?>{'id': id, 'source': source.wireValue};
    return _settingsLocal.set(_key, json.encode(index));
  }

  DownloadedWallRef? resolve(String filePath) {
    final String name = p.basenameWithoutExtension(filePath).replaceFirst(_copySuffix, '');
    final Object? entry = _read()[name];
    if (entry is Map) {
      final Object? id = entry['id'];
      final WallpaperSource source = WallpaperSourceX.fromWire(entry['source']);
      if (id is String && id.isNotEmpty && source != WallpaperSource.unknown) return (id: id, source: source);
    }
    final String? wallhavenId = _wallhavenName.firstMatch(name)?.group(1);
    if (wallhavenId != null) return (id: wallhavenId, source: WallpaperSource.wallhaven);
    final String? pexelsId = _pexelsName.firstMatch(name)?.group(1);
    if (pexelsId != null) return (id: pexelsId, source: WallpaperSource.pexels);
    return null;
  }
}
