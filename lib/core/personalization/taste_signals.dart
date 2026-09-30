import 'dart:convert';

import 'package:Prism/core/persistence/data_sources/settings_local_data_source.dart';
import 'package:Prism/core/wallpaper/wallpaper_core.dart';
import 'package:Prism/core/wallpaper/wallpaper_source.dart';
import 'package:flutter/foundation.dart';
import 'package:injectable/injectable.dart';

/// Things a user does with a wallpaper. The ranker turns these into weights,
/// like X's heavy ranker weighs predicted actions.
enum TasteAction { open, favourite, download, set, lessLikeThis }

const Set<String> _noiseTerms = <String>{'community', 'general', 'wallpaper', 'wallpapers'};

/// Lowercase, de-duplicated descriptive terms of a wallpaper.
List<String> tasteTermsOf(WallpaperCore core, {List<String>? tags, List<String>? collections}) {
  return _normalizeTasteTerms(<String?>[core.category, ...?tags, ...?collections]);
}

List<String> _normalizeTasteTerms(Iterable<String?> rawTerms) {
  final Set<String> out = <String>{};
  for (final String? raw in rawTerms) {
    final String term = (raw ?? '').trim().toLowerCase();
    if (term.isNotEmpty && term.length <= 40 && !_noiseTerms.contains(term)) {
      out.add(term);
    }
  }
  return out.toList(growable: false);
}

final Map<String, List<String>> _feedTerms = <String, List<String>>{};
const int _feedTermsCap = 500;

/// Remembers terms the feed knew for a wall, such as the search query that
/// found it. Wallhaven and Pexels search results carry no tags, so without
/// this their signals would have nothing to learn from.
// ponytail: in-memory only, so a cold start forgets them until the next feed load.
void rememberFeedTerms(String fullUrl, List<String> terms) {
  final String key = fullUrl.trim().toLowerCase();
  if (key.isEmpty || terms.isEmpty) {
    return;
  }
  _feedTerms[key] = _normalizeTasteTerms(<String?>[...?_feedTerms.remove(key), ...terms]);
  if (_feedTerms.length > _feedTermsCap) {
    _feedTerms.remove(_feedTerms.keys.first);
  }
}

/// Who made a wallpaper: the creator email for Prism walls, else the author name.
String? tasteCreatorOf(WallpaperCore core) {
  final String creator = (core.authorEmail ?? core.authorName ?? '').trim().toLowerCase();
  return creator.isEmpty ? null : creator;
}

class TasteSignal {
  const TasteSignal({required this.action, required this.at, required this.terms, this.creator});

  factory TasteSignal.forWallpaper(
    TasteAction action,
    WallpaperCore core, {
    List<String>? tags,
    List<String>? collections,
    DateTime? at,
  }) {
    final String url = core.fullUrl.trim().toLowerCase();
    final String key = url.isEmpty ? '${core.source.wireValue}:${core.id.trim().toLowerCase()}' : url;
    final List<String>? feedTerms = _feedTerms.remove(key);
    if (feedTerms != null) {
      _feedTerms[key] = feedTerms;
    }
    return TasteSignal(
      action: action,
      at: (at ?? DateTime.now()).toUtc(),
      terms: _normalizeTasteTerms(<String?>[
        ...tasteTermsOf(core, tags: tags, collections: collections),
        ...?feedTerms,
      ]),
      creator: tasteCreatorOf(core),
    );
  }

  @visibleForTesting
  static void clearRememberedFeedTerms() => _feedTerms.clear();

  static TasteSignal? fromJson(Map<String, dynamic> json) {
    final TasteAction? action = TasteAction.values.asNameMap()[json['a']];
    final DateTime? at = DateTime.tryParse(json['t']?.toString() ?? '');
    final Object? terms = json['k'];
    if (action == null || at == null || terms is! List) {
      return null;
    }
    final List<String> normalizedTerms = _normalizeTasteTerms(terms.whereType<String>());
    final String creator = json['c']?.toString().trim().toLowerCase() ?? '';
    if (normalizedTerms.isEmpty && creator.isEmpty) {
      return null;
    }
    return TasteSignal(
      action: action,
      at: at.toUtc(),
      terms: normalizedTerms,
      creator: creator.isEmpty ? null : creator,
    );
  }

  final TasteAction action;
  final DateTime at;
  final List<String> terms;
  final String? creator;

  Map<String, Object?> toJson() => <String, Object?>{
    'a': action.name,
    't': at.toIso8601String(),
    'k': terms,
    if (creator != null) 'c': creator,
  };
}

/// On-device log of recent [TasteSignal]s. Nothing leaves the device.
@lazySingleton
class TasteSignalStore {
  TasteSignalStore(this._settingsLocal);

  final SettingsLocalDataSource _settingsLocal;

  static const String _key = 'personalized_taste_signals_v1';
  static const String _seededKey = 'personalized_taste_seeded_v1';
  static const int _cap = 300;
  int _revision = 0;

  int get revision => _revision;

  List<TasteSignal> read() {
    final String raw = _settingsLocal.get<String>(_key, defaultValue: '');
    if (raw.isEmpty) {
      return const <TasteSignal>[];
    }
    try {
      final Object? decoded = json.decode(raw);
      if (decoded is! List) {
        return const <TasteSignal>[];
      }
      return decoded
          .whereType<Map>()
          .map((e) => TasteSignal.fromJson(Map<String, dynamic>.from(e)))
          .whereType<TasteSignal>()
          .toList(growable: false);
    } catch (_) {
      return const <TasteSignal>[];
    }
  }

  Future<void> record(TasteSignal signal) => recordAll(<TasteSignal>[signal]);

  Future<void> recordAll(List<TasteSignal> signals) {
    final List<TasteSignal> all = <TasteSignal>[
      ...read(),
      ...signals.where((s) => s.terms.isNotEmpty || s.creator != null),
    ]..sort((a, b) => a.at.compareTo(b.at));
    final List<TasteSignal> kept = all.length > _cap ? all.sublist(all.length - _cap) : all;
    return _settingsLocal.set(_key, json.encode(kept.map((s) => s.toJson()).toList(growable: false)));
  }

  /// Seeding from older data (for example favourites) runs once per install.
  bool get isSeeded => _settingsLocal.get<bool>(_seededKey, defaultValue: false);

  Future<void> markSeeded() => _settingsLocal.set(_seededKey, true);

  /// [allowReseed] lets the next user seed from their own favourites (sign-out).
  /// Without it, a user who cleared their history is not re-learned from favourites.
  Future<void> clear({bool allowReseed = false}) async {
    _revision++;
    _feedTerms.clear();
    await Future.wait<void>(<Future<void>>[_settingsLocal.delete(_key), _settingsLocal.set(_seededKey, !allowReseed)]);
  }
}
