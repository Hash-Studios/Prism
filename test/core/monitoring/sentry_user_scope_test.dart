import 'package:Prism/core/monitoring/monitoring_runtime.dart';
import 'package:Prism/core/monitoring/sentry_user_scope.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/fake_error_reporter.dart';

void main() {
  group('syncSentryUserScope', () {
    late FakeErrorReporter reporter;

    setUp(() {
      reporter = FakeErrorReporter();
      MonitoringRuntime.reporter = reporter;
    });

    tearDown(() {
      MonitoringRuntime.reset();
    });

    test('sets user scope when logged in with id and email', () async {
      await syncSentryUserScope(loggedIn: true, id: 'user-1', email: 'user@example.com', username: 'tester');

      expect(reporter.cleared, isFalse);
      expect(reporter.lastUserId, 'user-1');
      expect(reporter.lastUserEmail, 'user@example.com');
      expect(reporter.lastUsername, 'tester');
    });

    test('clears user scope when logged out', () async {
      await syncSentryUserScope(loggedIn: false, id: 'user-1', email: 'user@example.com');

      expect(reporter.cleared, isTrue);
      expect(reporter.lastUserId, isNull);
      expect(reporter.lastUserEmail, isNull);
    });

    test('clears user scope when mandatory fields are missing', () async {
      await syncSentryUserScope(loggedIn: true, id: '', email: 'user@example.com');

      expect(reporter.cleared, isTrue);
      expect(reporter.lastUserId, isNull);
    });
  });
}
