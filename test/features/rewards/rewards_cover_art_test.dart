import 'package:Prism/core/widgets/glint/cover_mosaic.dart';
import 'package:Prism/features/rewards/views/widgets/rewards_cover_art.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('cover assets are stable and wrap', () {
    expect(rewardsCoverAsset(0), kCoverMosaicAssets.first);
    expect(rewardsCoverAsset(kCoverMosaicAssets.length), kCoverMosaicAssets.first);
    expect(rewardsCoverAsset(1), isNot(rewardsCoverAsset(2)));
  });

  testWidgets('wash puts a low opacity cover over the child and keeps its text and taps', (tester) async {
    int taps = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: RewardsCoverWash(
          asset: rewardsCoverAsset(4),
          child: GestureDetector(
            onTap: () => taps++,
            child: const SizedBox(width: 200, height: 100, child: Text('Today')),
          ),
        ),
      ),
    );
    expect(find.text('Today'), findsOneWidget);
    expect(find.byType(Image), findsOneWidget);
    expect(tester.widget<Opacity>(find.byType(Opacity)).opacity, lessThanOrEqualTo(0.25));
    await tester.tap(find.text('Today'));
    expect(taps, 1);
  });
}
