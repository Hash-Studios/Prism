import 'package:Prism/core/updates/store_update_policy.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('a build below the minimum gets a suggested update', () {
    expect(storeUpdateFor(currentBuild: '352', minBuild: 353, blocking: false), StoreUpdate.suggested);
  });

  test('a build below the minimum gets a required update when blocking', () {
    expect(storeUpdateFor(currentBuild: '352', minBuild: 353, blocking: true), StoreUpdate.required);
  });

  test('a build at the minimum needs no update', () {
    expect(storeUpdateFor(currentBuild: '353', minBuild: 353, blocking: true), StoreUpdate.none);
  });

  test('a build above the minimum needs no update', () {
    expect(storeUpdateFor(currentBuild: '400', minBuild: 353, blocking: false), StoreUpdate.none);
  });

  test('no minimum build means no update', () {
    expect(storeUpdateFor(currentBuild: '352', minBuild: 0, blocking: true), StoreUpdate.none);
  });

  test('an empty build number needs no update', () {
    expect(storeUpdateFor(currentBuild: '', minBuild: 353, blocking: true), StoreUpdate.none);
  });

  test('a build number that is not a number needs no update', () {
    expect(storeUpdateFor(currentBuild: 'abc', minBuild: 353, blocking: true), StoreUpdate.none);
  });
}
