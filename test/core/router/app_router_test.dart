import 'package:Prism/core/router/app_router.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('a share link the parser rejects opens not-found, not an empty wallpaper screen', () {
    final matches = AppRouter().matcher.match('/share');

    expect(matches?.last.name, NotFoundRoute.name);
  });
}
