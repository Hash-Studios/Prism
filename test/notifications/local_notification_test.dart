import 'package:Prism/notifications/local_notification.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('startup init does not ask for iOS notification permission', () {
    const settings = LocalNotification.darwinSettings;

    expect(settings.requestAlertPermission, isFalse);
    expect(settings.requestSoundPermission, isFalse);
    expect(settings.requestBadgePermission, isFalse);
  });
}
