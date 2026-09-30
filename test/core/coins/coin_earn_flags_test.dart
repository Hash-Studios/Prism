import 'package:Prism/core/coins/coins_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('missing coinState gives no flags', () {
    expect(CoinEarnFlags.fromCoinState(<String, dynamic>{}), CoinEarnFlags.empty);
  });

  test('each flag is read on its own', () {
    final CoinEarnFlags flags = CoinEarnFlags.fromCoinState(<String, dynamic>{'firstWallpaperUploadRewarded': true});
    expect(flags.firstUploadRewarded, isTrue);
    expect(flags.profileCompletionRewarded, isFalse);
    expect(
      CoinEarnFlags.fromCoinState(<String, dynamic>{'profileCompletionRewarded': true}).profileCompletionRewarded,
      isTrue,
    );
  });

  test('non-bool values do not count as rewarded', () {
    final CoinEarnFlags flags = CoinEarnFlags.fromCoinState(<String, dynamic>{
      'firstWallpaperUploadRewarded': 'true',
      'profileCompletionRewarded': 1,
    });
    expect(flags, CoinEarnFlags.empty);
  });
}
