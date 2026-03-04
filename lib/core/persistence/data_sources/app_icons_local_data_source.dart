import 'package:Prism/core/persistence/local_store.dart';
import 'package:Prism/core/persistence/persistence_keys.dart';
import 'package:injectable/injectable.dart';

@lazySingleton
class AppIconsLocalDataSource {
  AppIconsLocalDataSource(this._store);

  final LocalStore _store;

  Map<String, dynamic> readIconsPayload() {
    final raw = _store.get(PersistenceKeys.cacheIconsAppsPayload);
    if (raw is Map<String, dynamic>) {
      return raw;
    }
    if (raw is Map) {
      return raw.map<String, dynamic>((key, value) => MapEntry(key.toString(), value));
    }
    return <String, dynamic>{};
  }

  Future<void> writeIconsPayload(Map<String, dynamic> payload) async {
    await _store.set(PersistenceKeys.cacheIconsAppsPayload, payload);
    await _store.set(PersistenceKeys.cacheIconsAppsUpdatedAtUtc, DateTime.now().toUtc().toIso8601String());
  }

  DateTime? lastUpdatedAtUtc() {
    final raw = _store.get(PersistenceKeys.cacheIconsAppsUpdatedAtUtc);
    if (raw is! String) {
      return null;
    }
    return DateTime.tryParse(raw)?.toUtc();
  }

  Future<void> clear() async {
    await _store.delete(PersistenceKeys.cacheIconsAppsPayload);
    await _store.delete(PersistenceKeys.cacheIconsAppsUpdatedAtUtc);
  }
}
