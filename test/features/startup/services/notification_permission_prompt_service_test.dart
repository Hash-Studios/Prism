import 'package:Prism/features/startup/services/notification_permission_prompt_service.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const canAsk = NotificationPermissionPromptService.canAsk;

  test('Android asks even though it reports denied before the first ask', () {
    expect(canAsk(AuthorizationStatus.denied, TargetPlatform.android), isTrue);
  });

  test('iOS treats denied as final', () {
    expect(canAsk(AuthorizationStatus.denied, TargetPlatform.iOS), isFalse);
  });

  test('an undecided status can always be asked', () {
    expect(canAsk(AuthorizationStatus.notDetermined, TargetPlatform.iOS), isTrue);
    expect(canAsk(AuthorizationStatus.notDetermined, TargetPlatform.android), isTrue);
  });
}
