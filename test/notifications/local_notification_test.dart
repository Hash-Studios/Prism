import 'package:Prism/notifications/local_notification.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('startup init does not ask for iOS notification permission', () {
    const settings = LocalNotification.darwinSettings;

    expect(settings.requestAlertPermission, isFalse);
    expect(settings.requestSoundPermission, isFalse);
    expect(settings.requestBadgePermission, isFalse);
  });

  group('downloadedTitle', () {
    test('starts at one wall', () {
      expect(LocalNotification.downloadedTitle(null), '1 wall downloaded.');
      expect(LocalNotification.downloadedTitle('Downloading Wallpaper'), '1 wall downloaded.');
    });

    test('counts up from the previous title', () {
      expect(LocalNotification.downloadedTitle('1 wall downloaded.'), '2 walls downloaded.');
      expect(LocalNotification.downloadedTitle('9 walls downloaded.'), '10 walls downloaded.');
      expect(LocalNotification.downloadedTitle('12 walls downloaded.'), '13 walls downloaded.');
    });
  });
}
