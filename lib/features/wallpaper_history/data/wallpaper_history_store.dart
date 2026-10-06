import 'dart:convert';

import 'package:Prism/core/di/injection.dart';
import 'package:Prism/core/persistence/data_sources/settings_local_data_source.dart';
import 'package:Prism/core/persistence/persistence_keys.dart';
import 'package:Prism/features/wallpaper_history/domain/entities/applied_wallpaper.dart';
import 'package:Prism/logger/logger.dart';
import 'package:injectable/injectable.dart';

const int wallpaperHistoryLimit = 100;
const Duration wallpaperHistoryDedupeWindow = Duration(minutes: 1);

@lazySingleton
class WallpaperHistoryStore {
  WallpaperHistoryStore(this._settings);

  final SettingsLocalDataSource _settings;

  static WallpaperHistoryStore get instance => getIt<WallpaperHistoryStore>();

  List<AppliedWallpaper>? _cache;

  List<AppliedWallpaper> items() => List<AppliedWallpaper>.unmodifiable(_load());

  Future<void> record(AppliedWallpaper item) async {
    final List<AppliedWallpaper> current = _load();
    final bool duplicate = current.any(
      (existing) =>
          existing.fullUrl == item.fullUrl &&
          existing.target == item.target &&
          item.appliedAt.difference(existing.appliedAt).abs() < wallpaperHistoryDedupeWindow,
    );
    if (duplicate) return;
    final List<AppliedWallpaper> next = <AppliedWallpaper>[item, ...current];
    next.sort((a, b) => b.appliedAt.compareTo(a.appliedAt));
    await _save(next.length > wallpaperHistoryLimit ? next.sublist(0, wallpaperHistoryLimit) : next);
  }

  Future<void> clear() => _save(const <AppliedWallpaper>[]);

  Future<void> _save(List<AppliedWallpaper> next) async {
    _cache = next;
    await _settings.set(
      PersistenceKeys.wallpaperHistoryItems,
      jsonEncode(next.map((item) => item.toJson()).toList(growable: false)),
    );
  }

  List<AppliedWallpaper> _load() {
    final List<AppliedWallpaper>? cached = _cache;
    if (cached != null) return cached;
    final List<AppliedWallpaper> loaded = _read();
    _cache = loaded;
    return loaded;
  }

  List<AppliedWallpaper> _read() {
    try {
      final String raw = _settings.get<String>(PersistenceKeys.wallpaperHistoryItems, defaultValue: '');
      if (raw.isEmpty) return <AppliedWallpaper>[];
      final Object? decoded = jsonDecode(raw);
      if (decoded is! List<Object?>) return <AppliedWallpaper>[];
      return decoded.map(AppliedWallpaper.tryFromJson).whereType<AppliedWallpaper>().toList();
    } catch (error, stackTrace) {
      logger.w('WallpaperHistoryStore: could not read history', error: error, stackTrace: stackTrace);
      return <AppliedWallpaper>[];
    }
  }
}
