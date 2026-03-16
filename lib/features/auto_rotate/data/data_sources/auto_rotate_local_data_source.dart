import 'package:Prism/core/persistence/local_store.dart';
import 'package:Prism/core/persistence/persistence_keys.dart';
import 'package:Prism/features/auto_rotate/domain/entities/auto_rotate_config_entity.dart';
import 'package:async_wallpaper/async_wallpaper.dart' as aw;
import 'package:injectable/injectable.dart';

@lazySingleton
class AutoRotateLocalDataSource {
  AutoRotateLocalDataSource(this._store);

  final LocalStore _store;

  AutoRotateConfigEntity loadConfig() {
    final defaults = AutoRotateConfigEntity.defaults;

    final isEnabled = _store.get(PersistenceKeys.autoRotateEnabled) as bool? ?? defaults.isEnabled;

    final sourceTypeRaw = _store.get(PersistenceKeys.autoRotateSourceType) as String?;
    final sourceType = sourceTypeRaw != null
        ? AutoRotateSourceType.values.firstWhere(
            (e) => e.name == sourceTypeRaw,
            orElse: () => defaults.sourceType,
          )
        : defaults.sourceType;

    final collectionName = _store.get(PersistenceKeys.autoRotateCollectionName) as String?;
    final categoryName = _store.get(PersistenceKeys.autoRotateCategoryName) as String?;

    final targetRaw = _store.get(PersistenceKeys.autoRotateTarget) as String?;
    final target = targetRaw != null
        ? aw.WallpaperTarget.values.firstWhere(
            (e) => e.name == targetRaw,
            orElse: () => defaults.target,
          )
        : defaults.target;

    final intervalMinutes =
        _store.get(PersistenceKeys.autoRotateIntervalMinutes) as int? ?? defaults.intervalMinutes;
    final chargingTrigger =
        _store.get(PersistenceKeys.autoRotateChargingTrigger) as bool? ?? defaults.chargingTrigger;

    final orderRaw = _store.get(PersistenceKeys.autoRotateOrder) as String?;
    final order = orderRaw != null
        ? AutoRotateOrder.values.firstWhere(
            (e) => e.name == orderRaw,
            orElse: () => defaults.order,
          )
        : defaults.order;

    return AutoRotateConfigEntity(
      isEnabled: isEnabled,
      sourceType: sourceType,
      collectionName: collectionName,
      categoryName: categoryName,
      target: target,
      intervalMinutes: intervalMinutes,
      chargingTrigger: chargingTrigger,
      order: order,
    );
  }

  Future<void> saveConfig(AutoRotateConfigEntity config) async {
    await Future.wait([
      _store.set(PersistenceKeys.autoRotateEnabled, config.isEnabled),
      _store.set(PersistenceKeys.autoRotateSourceType, config.sourceType.name),
      if (config.collectionName != null)
        _store.set(PersistenceKeys.autoRotateCollectionName, config.collectionName)
      else
        _store.delete(PersistenceKeys.autoRotateCollectionName),
      if (config.categoryName != null)
        _store.set(PersistenceKeys.autoRotateCategoryName, config.categoryName)
      else
        _store.delete(PersistenceKeys.autoRotateCategoryName),
      _store.set(PersistenceKeys.autoRotateTarget, config.target.name),
      _store.set(PersistenceKeys.autoRotateIntervalMinutes, config.intervalMinutes),
      _store.set(PersistenceKeys.autoRotateChargingTrigger, config.chargingTrigger),
      _store.set(PersistenceKeys.autoRotateOrder, config.order.name),
    ]);
  }
}
