import 'package:Prism/core/utils/url_utils.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('downloadBaseName', () {
    test('drops any image extension, not only .jpg and .png', () {
      expect(
        downloadBaseName('https://images.pexels.com/photos/1563016/pexels-photo-1563016.jpeg'),
        'pexels-photo-1563016',
      );
      expect(downloadBaseName('https://w.wallhaven.cc/full/abc/wallhaven-abc123.webp'), 'wallhaven-abc123');
      expect(downloadBaseName('https://raw.githubusercontent.com/x/prism-walls/main/walls/ZFT1.png'), 'ZFT1');
    });

    test('ignores the query string', () {
      expect(
        downloadBaseName('https://images.pexels.com/photos/1/pexels-photo-1.jpeg?auto=compress&cs=tinysrgb'),
        'pexels-photo-1',
      );
    });

    test('keeps a name that has no extension', () {
      expect(downloadBaseName('https://example.com/files/wallpaper'), 'wallpaper');
    });
  });
}
