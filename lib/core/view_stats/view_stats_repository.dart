import 'package:Prism/core/utils/result.dart';

/// What a person did with a wallpaper. The wire value is the `action` of the `recordWallpaperAction` callable.
enum WallpaperAction {
  download,
  set,
  share;

  String get wireValue => name;
}

class WallpaperActionReceipt {
  const WallpaperActionReceipt({this.counted = false, this.coins = 0, this.receiptId});

  final bool counted;
  final int coins;
  final String? receiptId;

  factory WallpaperActionReceipt.fromResponse(Object? response, String requestId) {
    if (response is! Map) return const WallpaperActionReceipt();
    final counted = response['counted'] == true;
    final awards = response['questAwards'];
    final coins = response['questCoins'];
    if (response['questReceiptComplete'] != true ||
        response['questReceiptId'] != requestId ||
        awards is! List ||
        coins is! int ||
        coins <= 0) {
      return WallpaperActionReceipt(counted: counted);
    }
    var total = 0;
    final ids = <String>{};
    for (final award in awards) {
      if (award is! Map ||
          award['id'] is! String ||
          !ids.add(award['id'] as String) ||
          award['coins'] is! int ||
          (award['coins'] as int) < 0) {
        return WallpaperActionReceipt(counted: counted);
      }
      total += award['coins'] as int;
    }
    if (total != coins) return WallpaperActionReceipt(counted: counted);
    return WallpaperActionReceipt(counted: counted, coins: coins, receiptId: requestId);
  }
}

/// Times the wall was set (null when unknown) and how many people tipped it (0 when none).
typedef WallpaperCounts = ({int? sets, int tippers});

/// Prism wallpaper view counters (Firestore-backed via Cloud Functions).
abstract class ViewStatsRepository {
  /// Increments the view count and returns the new total as a string for UI display.
  Future<Result<String>> recordWallpaperView(String wallId);

  /// Counts one [action] on the wall. An older backend without the callable counts as success, so the UI never breaks.
  Future<Result<WallpaperActionReceipt>> recordWallpaperAction(String wallId, WallpaperAction action);

  /// The set and tipper counts from `wallpaper_stats`. Null when the wall has no stats doc yet.
  Future<Result<WallpaperCounts?>> fetchWallpaperCounts(String wallId);
}
