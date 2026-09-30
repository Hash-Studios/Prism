import 'dart:convert';

import 'package:Prism/core/persistence/data_sources/settings_local_data_source.dart';
import 'package:injectable/injectable.dart';

/// Remembers which wallpapers the home feed already showed, so the ranker can
/// fade them out (X's previously-seen filter and feedback fatigue).
@lazySingleton
class FeedImpressionStore {
  FeedImpressionStore(this._settingsLocal);

  final SettingsLocalDataSource _settingsLocal;

  static const String _key = 'personalized_feed_impressions_v1';
  static const int _cap = 800;
  static const Duration _window = Duration(days: 14);

  /// A hidden wallpaper counts as shown this often, which sinks it for good.
  static const int hiddenShows = 99;

  /// Key to times shown within the last 14 days.
  Map<String, int> recentShows(DateTime now) {
    final DateTime cutoff = now.subtract(_window);
    return <String, int>{
      for (final MapEntry<String, _Impression> entry in _read().entries)
        if (entry.value.lastShown.isAfter(cutoff)) entry.key: entry.value.count,
    };
  }

  Future<void> recordShown(Iterable<String> keys, DateTime now) {
    final Map<String, _Impression> all = _read();
    final DateTime cutoff = now.subtract(_window);
    for (final String key in keys) {
      final _Impression? old = all.remove(key);
      final int count = old == null || old.lastShown.isBefore(cutoff) ? 1 : old.count + 1;
      all[key] = _Impression(count, now);
    }
    return _write(all);
  }

  Future<void> hide(String key, DateTime now) {
    final Map<String, _Impression> all = _read()..remove(key);
    all[key] = _Impression(hiddenShows, now);
    return _write(all);
  }

  Map<String, _Impression> _read() {
    final String raw = _settingsLocal.get<String>(_key, defaultValue: '');
    if (raw.isEmpty) {
      return <String, _Impression>{};
    }
    try {
      final Object? decoded = json.decode(raw);
      if (decoded is! Map) {
        return <String, _Impression>{};
      }
      final Map<String, _Impression> out = <String, _Impression>{};
      decoded.forEach((key, value) {
        if (value is List && value.length == 2 && value[0] is int && value[1] is int) {
          out[key.toString()] = _Impression(
            value[0] as int,
            DateTime.fromMillisecondsSinceEpoch((value[1] as int) * 60000, isUtc: true),
          );
        }
      });
      return out;
    } catch (_) {
      return <String, _Impression>{};
    }
  }

  Future<void> _write(Map<String, _Impression> all) {
    final List<MapEntry<String, _Impression>> entries = all.entries.toList()
      ..sort((a, b) => a.value.lastShown.compareTo(b.value.lastShown));
    final Iterable<MapEntry<String, _Impression>> kept = entries.length > _cap
        ? entries.skip(entries.length - _cap)
        : entries;
    return _settingsLocal.set(
      _key,
      json.encode(<String, List<int>>{
        for (final MapEntry<String, _Impression> entry in kept)
          entry.key: <int>[entry.value.count, entry.value.lastShown.millisecondsSinceEpoch ~/ 60000],
      }),
    );
  }
}

class _Impression {
  const _Impression(this.count, this.lastShown);

  final int count;
  final DateTime lastShown;
}
