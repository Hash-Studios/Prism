import 'package:Prism/core/wallpaper/wallpaper_core.dart';
import 'package:Prism/core/wallpaper/wallpaper_source.dart';
import 'package:Prism/core/wallpaper/wallpaper_variants.dart';
import 'package:Prism/features/day_night/domain/day_night_variants.dart';
import 'package:Prism/features/wallpaper_detail/domain/entities/variant_group.dart';
import 'package:flutter_test/flutter_test.dart';

PrismWallpaper _wall(String id, List<String>? colors) => PrismWallpaper(
  core: WallpaperCore(id: id, source: WallpaperSource.prism, fullUrl: 'https://example.com/$id.jpg', thumbnailUrl: ''),
  colors: colors,
);

void main() {
  test('the lightest variant is day and the darkest is night', () {
    final VariantGroup group = VariantGroup(
      id: 'g',
      walls: <PrismWallpaper>[
        _wall('mid', <String>['#808080']),
        _wall('dark', <String>['#000000']),
        _wall('light', <String>['#ffffff']),
      ],
    );

    final result = dayNightFromVariants(group);

    expect(result?.day.id, 'light');
    expect(result?.night.id, 'dark');
  });

  test('palette ids compare by their palette luminance', () {
    final VariantGroup group = VariantGroup(
      id: 'g',
      walls: <PrismWallpaper>[
        _wall('purple', <String>['purple']),
        _wall('grey', <String>['grey']),
      ],
    );

    final result = dayNightFromVariants(group);

    expect(result?.day.id, 'grey');
    expect(result?.night.id, 'purple');
  });

  test('fewer than two coloured walls gives null', () {
    final VariantGroup group = VariantGroup(
      id: 'g',
      walls: <PrismWallpaper>[
        _wall('only', <String>['#ffffff']),
        _wall('plain', null),
      ],
    );

    expect(dayNightFromVariants(group), isNull);
  });

  test('walls with equal luminance give null', () {
    final VariantGroup group = VariantGroup(
      id: 'g',
      walls: <PrismWallpaper>[
        _wall('a', <String>['#808080']),
        _wall('b', <String>['#808080']),
      ],
    );

    expect(dayNightFromVariants(group), isNull);
  });

  test('walls with null colours are skipped', () {
    final VariantGroup group = VariantGroup(
      id: 'g',
      walls: <PrismWallpaper>[
        _wall('none', null),
        _wall('white', <String>['#ffffff']),
        _wall('none-empty', <String>[]),
        _wall('black', <String>['#000000']),
      ],
    );

    final result = dayNightFromVariants(group);

    expect(result?.day.id, 'white');
    expect(result?.night.id, 'black');
  });
}
