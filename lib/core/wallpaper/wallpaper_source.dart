typedef JsonMap = Map<String, Object?>;

enum WallpaperSource { prism, wallhaven, pexels, wallOfTheDay, downloaded, unknown }

extension WallpaperSourceX on WallpaperSource {
  static WallpaperSource fromWire(Object? v) {
    final String s = (v is String ? v : v?.toString() ?? '').toLowerCase().trim();
    switch (s) {
      case 'prism':
        return WallpaperSource.prism;
      case 'wallhaven':
        return WallpaperSource.wallhaven;
      case 'pexels':
        return WallpaperSource.pexels;
      case 'wall_of_the_day':
      case 'walloftheday':
        return WallpaperSource.wallOfTheDay;
      case 'downloaded':
      case 'downloads':
        return WallpaperSource.downloaded;
      default:
        return WallpaperSource.unknown;
    }
  }

  String get wireValue {
    switch (this) {
      case WallpaperSource.prism:
        return 'prism';
      case WallpaperSource.wallhaven:
        return 'wallhaven';
      case WallpaperSource.pexels:
        return 'pexels';
      case WallpaperSource.wallOfTheDay:
        return 'wall_of_the_day';
      case WallpaperSource.downloaded:
        return 'downloaded';
      case WallpaperSource.unknown:
        return 'unknown';
    }
  }

  String get legacyProviderString {
    switch (this) {
      case WallpaperSource.prism:
        return 'Prism';
      case WallpaperSource.wallhaven:
        return 'WallHaven';
      case WallpaperSource.pexels:
        return 'Pexels';
      case WallpaperSource.wallOfTheDay:
        return 'WallOfTheDay';
      case WallpaperSource.downloaded:
        return 'Downloads';
      case WallpaperSource.unknown:
        return 'Unknown';
    }
  }
}
