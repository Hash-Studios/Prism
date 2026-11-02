import 'package:Prism/features/live_photo/views/open_live_photo.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('a standard wall is allowed for anyone', () {
    expect(livePhotoAllowed(premiumWall: false, premiumContentUnlocked: false), isTrue);
    expect(livePhotoAllowed(premiumWall: false, premiumContentUnlocked: true), isTrue);
  });

  test('a Pro wall is allowed only when premium content is unlocked', () {
    expect(livePhotoAllowed(premiumWall: true, premiumContentUnlocked: false), isFalse);
    expect(livePhotoAllowed(premiumWall: true, premiumContentUnlocked: true), isTrue);
  });
}
