import 'package:Prism/notifications/topic_subscription.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('followersTopicFromEmail', () {
    test('returns null when email local part is empty', () {
      expect(followersTopicFromEmail('   @example.com'), isNull);
      expect(followersTopicFromEmail('   '), isNull);
    });

    test('removes characters that are invalid for FCM topics', () {
      expect(followersTopicFromEmail('john+alerts.test@example.com'), 'johnalerts.test');
      expect(followersTopicFromEmail(' name with space+tag@example.com '), 'namewithspacetag');
    });

    test('returns null when sanitization removes all characters', () {
      expect(followersTopicFromEmail('++@example.com'), isNull);
    });

    test('keeps supported FCM topic characters in local part', () {
      expect(followersTopicFromEmail('Az-_.~%09@example.com'), 'Az-_.~%09');
    });
  });
}
