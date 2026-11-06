import 'package:Prism/core/widgets/glint/cover_mosaic.dart';
import 'package:Prism/features/rewards/views/widgets/rewards_cover_art.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('cover assets are stable and wrap', () {
    expect(rewardsCoverAsset(0), kCoverMosaicAssets.first);
    expect(rewardsCoverAsset(kCoverMosaicAssets.length), kCoverMosaicAssets.first);
    expect(rewardsCoverAsset(1), isNot(rewardsCoverAsset(2)));
  });
}
