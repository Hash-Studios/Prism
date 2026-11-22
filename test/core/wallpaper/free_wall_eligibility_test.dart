import 'package:Prism/core/wallpaper/free_wall_eligibility.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const Map<String, dynamic> freeApprovedWall = <String, dynamic>{
    'review': true,
    'originalProtected': true,
    'collections': <String>['general'],
  };

  test('excludes valid creator prices using the server integer and range rules', () {
    for (final Object price in <Object>[10, 20, 1000, 20.0]) {
      expect(isFreeListableWallDoc(<String, dynamic>{...freeApprovedWall, 'creatorPrice': price}), isFalse);
    }
  });

  test('treats invalid creator prices as free, like the server', () {
    for (final Object price in <Object>[9, 1001, 20.5, '40']) {
      expect(isFreeListableWallDoc(<String, dynamic>{...freeApprovedWall, 'creatorPrice': price}), isTrue);
    }
  });
}
