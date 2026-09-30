import 'package:Prism/core/coins/coins_service.dart';
import 'package:Prism/core/wallpaper/wallpaper_core.dart';
import 'package:Prism/core/wallpaper/wallpaper_source.dart';
import 'package:Prism/core/wallpaper/wallpaper_variants.dart';
import 'package:Prism/features/streak/streak_unlock.dart';
import 'package:flutter_test/flutter_test.dart';

PrismWallpaper _wallpaper({int? days, int? cost}) => PrismWallpaper(
  core: const WallpaperCore(id: 'w', source: WallpaperSource.prism, fullUrl: '', thumbnailUrl: ''),
  requiredStreakDays: days,
  streakShopCoinCost: cost,
);

StreakStatus _streak({required bool active, int day = 0}) => StreakStatus(
  streakDay: day % 7,
  count: day,
  active: active,
  claimedToday: false,
  reminderEnabled: true,
  timezoneOffsetMinutes: 0,
  lastClaimDate: '',
);

void main() {
  test('a wallpaper with no requirement is open', () {
    expect(_wallpaper().isUnlockedFor(StreakStatus.empty, 0), isTrue);
  });

  test('a long enough active streak opens a streak wallpaper', () {
    final wallpaper = _wallpaper(days: 5, cost: 500);
    expect(wallpaper.isUnlockedFor(_streak(active: true, day: 5), 0), isTrue);
    expect(wallpaper.isUnlockedFor(_streak(active: true, day: 4), 0), isFalse);
  });

  test('the uncapped count is compared, not the 7-day cycle day', () {
    expect(_wallpaper(days: 30, cost: 500).isUnlockedFor(_streak(active: true, day: 30), 0), isTrue);
    expect(_wallpaper(days: 30, cost: 500).isUnlockedFor(_streak(active: true, day: 29), 0), isFalse);
  });

  test('a streak that lapsed does not count', () {
    expect(_wallpaper(days: 5, cost: 500).isUnlockedFor(_streak(active: false, day: 6), 0), isFalse);
  });

  test('enough coins open it without a streak', () {
    final wallpaper = _wallpaper(days: 5, cost: 100);
    expect(wallpaper.isUnlockedFor(StreakStatus.empty, 100), isTrue);
    expect(wallpaper.isUnlockedFor(StreakStatus.empty, 99), isFalse);
  });

  test('a missing streak requirement counts as met even when the coin price is not', () {
    expect(_wallpaper(cost: 100).isUnlockedFor(StreakStatus.empty, 0), isTrue);
  });
}
