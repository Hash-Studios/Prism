import 'dart:convert';

import 'package:Prism/core/persistence/data_sources/settings_local_data_source.dart';
import 'package:Prism/core/wallpaper/wallpaper_core.dart';
import 'package:injectable/injectable.dart';

/// Things a user does with a wallpaper. The ranker turns these into weights,
/// like X's heavy ranker weighs predicted actions.
enum TasteAction { open, favourite, download, set, lessLikeThis }

const Set<String> _noiseTerms = <String>{'community', 'general', 'wallpaper', 'wallpapers'};

/// Lowercase, de-duplicated descriptive terms of a wallpaper.
List<String> tasteTermsOf(WallpaperCore core, {List<String>? tags, List<String>? collections}) {
  final Set<String> out = <String>{};
  for (final String? raw in <String?>[core.category, ...?tags, ...?collections]) {
    final String term = (raw ?? '').trim().toLowerCase();
    if (term.isNotEmpty && term.length <= 40 && !_noiseTerms.contains(term)) {
      out.add(term);
    }
  }
  return out.toList(growable: false);
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
    return TasteSignal(
      action: action,
      at: (at ?? DateTime.now()).toUtc(),
      terms: tasteTermsOf(core, tags: tags, collections: collections),
      creator: tasteCreatorOf(core),
    );
  }

  static TasteSignal? fromJson(Map<String, dynamic> json) {
    final TasteAction? action = TasteAction.values.asNameMap()[json['a']];
    final DateTime? at = DateTime.tryParse(json['t']?.toString() ?? '');
    final Object? terms = json['k'];
    if (action == null || at == null || terms is! List) {
      return null;
    }
    return TasteSignal(
      action: action,
      at: at.toUtc(),
      terms: terms.map((e) => e.toString()).toList(growable: false),
      creator: json['c']?.toString(),
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

  Future<void> clear() async {
    await _settingsLocal.delete(_key);
    await _settingsLocal.set(_seededKey, true);
  }
}
