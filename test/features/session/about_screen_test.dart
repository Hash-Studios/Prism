import 'package:Prism/features/session/views/pages/about_screen.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('the feedback link is a mailto with the version and platform prefilled', () {
    final link = buildFeedbackLink(version: '3.3.0', build: '339', platform: 'android 14');
    final uri = Uri.parse(link);

    expect(uri.scheme, 'mailto');
    expect(uri.path, 'hash.studios.inc@gmail.com');
    expect(uri.queryParameters['subject'], 'Prism feedback');
    expect(uri.queryParameters['body'], contains('Prism 3.3.0+339'));
    expect(uri.queryParameters['body'], contains('android 14'));
    expect(link, isNot(contains('+android')));
  });
}
