import 'package:async_wallpaper/async_wallpaper.dart' as aw;
import 'package:freezed_annotation/freezed_annotation.dart';

part 'auto_rotate_config_entity.freezed.dart';

enum AutoRotateSourceType { collection, category, favourites }

enum AutoRotateOrder { sequential, shuffle }

@freezed
abstract class AutoRotateConfigEntity with _$AutoRotateConfigEntity {
  const factory AutoRotateConfigEntity({
    required bool isEnabled,
    required AutoRotateSourceType sourceType,
    String? collectionName,
    String? categoryName,
    required aw.WallpaperTarget target,
    required int intervalMinutes,
    required bool chargingTrigger,
    required AutoRotateOrder order,
  }) = _AutoRotateConfigEntity;

  static AutoRotateConfigEntity get defaults => const AutoRotateConfigEntity(
        isEnabled: false,
        sourceType: AutoRotateSourceType.favourites,
        target: aw.WallpaperTarget.both,
        intervalMinutes: 60,
        chargingTrigger: false,
        order: AutoRotateOrder.shuffle,
      );
}
