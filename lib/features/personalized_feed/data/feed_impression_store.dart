import 'dart:convert';
import 'dart:math';

import 'package:Prism/core/persistence/data_sources/settings_local_data_source.dart';
import 'package:injectable/injectable.dart';

/// Remembers which wallpapers the home feed already showed, so the ranker can
/// fade them out (X's previously-seen filter and feedback fatigue).
@lazySingleton
class FeedImpressionStore {
  FeedImpressionStore(this._settingsLocal);

  final SettingsLocalDataSource _settingsLocal;

  static const String _key = 'personalized_feed_impressions_v1';
  static const String _hiddenKey = 'personalized_feed_hidden_v1';
  static const int _cap = 800;
  static const int _hiddenCap = 2000;
  static const Duration _window = Duration(days: 14);

  /// A hidden wallpaper counts as shown this often, which removes it from the feed.
  static const int hiddenShows = 99;

  /// Key to times shown within the last 14 days. Hidden walls report [hiddenShows].
  Map<String, int> recentShows(DateTime now) {
    final DateTime cutoff = now.subtract(_window);
    return <String, int>{
      for (final MapEntry<String, _Impression> entry in _read().entries)
        if (entry.value.lastShown.isAfter(cutoff)) entry.key: entry.value.count,
      for (final String key in _readHidden()) key: hiddenShows,
    };
  }

  Future<void> recordShown(Iterable<String> keys, DateTime now) {
    final Map<String, _Impression> all = _read();
    final DateTime cutoff = now.subtract(_window);
    for (final String key in keys) {
      final _Impression? old = all.remove(key);
      final int count = old != null && old.count >= hiddenShows
          ? hiddenShows
          : old == null || old.lastShown.isBefore(cutoff)
          ? 1
          : min(old.count + 1, hiddenShows - 1);
      all[key] = _Impression(count, now);
    }
    return _write(all);
  }

  /// Hides are kept apart from impressions, so a busy feed never evicts them.
  Future<void> hide(String key, DateTime now) async {
    final Map<String, _Impression> all = _read();
    if (all.values.any((entry) => entry.count >= hiddenShows)) {
      await _write(all);
    }
    final List<String> hidden = _readHidden()
      ..remove(key)
      ..add(key);
    return _writeHidden(hidden);
  }

  List<String> _readHidden() {
    final Set<String> hidden = <String>{
      for (final MapEntry<String, _Impression> entry in _read().entries)
        if (entry.value.count >= hiddenShows) entry.key,
    };
    final String raw = _settingsLocal.get<String>(_hiddenKey, defaultValue: '');
    if (raw.isEmpty) {
      return hidden.toList();
    }
    try {
      final Object? decoded = json.decode(raw);
      if (decoded is List) {
        hidden.removeAll(decoded.whereType<String>());
        hidden.addAll(decoded.whereType<String>());
      }
    } catch (_) {
      // Keep legacy hides even if the separate list is malformed.
    }
    return hidden.toList();
  }

  Future<void> _writeHidden(List<String> hidden) {
    final List<String> kept = hidden.length > _hiddenCap ? hidden.sublist(hidden.length - _hiddenCap) : hidden;
    return _settingsLocal.set(_hiddenKey, json.encode(kept));
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
        if (key is String && value is List && value.length == 2 && value[0] is int && value[1] is int) {
          final int count = value[0] as int;
          final int timestampMinutes = value[1] as int;
          if (count < 0 || timestampMinutes < -144000000000 || timestampMinutes > 144000000000) {
            return;
          }
          out[key] = _Impression(count, DateTime.fromMillisecondsSinceEpoch(timestampMinutes * 60000, isUtc: true));
        }
      });
      return out;
    } catch (_) {
      return <String, _Impression>{};
    }
  }

  Future<void> _write(Map<String, _Impression> all) async {
    if (all.values.any((entry) => entry.count >= hiddenShows)) {
      await _writeHidden(_readHidden());
    }
    final List<MapEntry<String, _Impression>> entries =
        all.entries.where((entry) => entry.value.count < hiddenShows).toList()
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
