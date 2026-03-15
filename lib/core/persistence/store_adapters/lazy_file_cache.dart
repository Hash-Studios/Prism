import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';

/// A self-contained key-value store backed by a single JSON file in the app
/// support directory. The file is loaded lazily on first access so it does not
/// block startup. All mutations persist asynchronously (fire-and-forget write
/// after the in-memory state is updated).
class LazyFileCache {
  LazyFileCache(this._fileName);

  final String _fileName;

  Map<String, Object?> _data = {};
  bool _loaded = false;
  Completer<void>? _loadCompleter;

  Future<void> _ensureLoaded() async {
    if (_loaded) return;
    if (_loadCompleter != null) {
      await _loadCompleter!.future;
      return;
    }
    final completer = Completer<void>();
    _loadCompleter = completer;
    try {
      final dir = await getApplicationSupportDirectory();
      final file = File('${dir.path}/$_fileName.json');
      if (await file.exists()) {
        final contents = await file.readAsString();
        final decoded = jsonDecode(contents);
        if (decoded is Map) {
          _data = decoded.cast<String, Object?>();
        }
      }
    } catch (_) {
      // Start with empty cache on any read error.
    } finally {
      _loaded = true;
      completer.complete();
    }
  }

  Future<Object?> get(String key) async {
    await _ensureLoaded();
    return _data[key];
  }

  Future<void> set(String key, Object? value) async {
    await _ensureLoaded();
    _data[key] = value;
    unawaited(_persist());
  }

  Future<void> delete(String key) async {
    await _ensureLoaded();
    _data.remove(key);
    unawaited(_persist());
  }

  Future<void> clearPrefix(String prefix) async {
    await _ensureLoaded();
    _data.removeWhere((k, _) => k.startsWith(prefix));
    unawaited(_persist());
  }

  Future<void> _persist() async {
    try {
      final dir = await getApplicationSupportDirectory();
      final tempPath = '${dir.path}/$_fileName.json.tmp';
      final finalPath = '${dir.path}/$_fileName.json';
      final tempFile = File(tempPath);
      await tempFile.writeAsString(jsonEncode(_data));
      await tempFile.rename(finalPath);
    } catch (_) {
      // Ignore write errors; data is still in memory.
    }
  }
}
