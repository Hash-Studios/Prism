import 'package:Prism/core/monitoring/error_reporter.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sentry_flutter/sentry_flutter.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test('Sentry reports scoped context and breadcrumbs without leaking the previous user or tag', () async {
    final events = <SentryEvent>[];
    await Sentry.init((options) {
      options.dsn = 'https://public@example.test/1';
      options.beforeSend = (event, hint) {
        events.add(event);
        return null;
      };
    });
    addTearDown(Sentry.close);
    const reporter = SentryErrorReporter();
    await reporter.setUser(id: 'u1', email: 'person@example.test', username: 'Creator');
    await reporter.addBreadcrumb(
      message: 'Download requested',
      category: 'wallpaper',
      severity: ErrorSeverity.debug,
      data: <String, Object?>{'attempt': 2},
    );
    final error = StateError('download failed');
    await reporter.captureException(
      error,
      message: '  Original unavailable  ',
      tag: '  download  ',
      severity: ErrorSeverity.warning,
      extras: <String, Object?>{'wallId': 'w1'},
    );
    await reporter.clearUser();
    await reporter.captureMessage('After sign out', severity: ErrorSeverity.info);
    await reporter.captureMessage(
      'Fatal problem',
      severity: ErrorSeverity.fatal,
      tag: 'fatal',
      extras: <String, Object?>{'retryable': false},
    );

    expect(events, hasLength(3));
    final first = events.first;
    expect(first.throwable, same(error));
    expect(first.level, SentryLevel.warning);
    expect(first.user?.id, 'u1');
    expect(first.user?.email, 'person@example.test');
    expect(first.user?.username, 'Creator');
    expect(first.tags?['tag'], 'download');
    expect(first.contexts['logger'], <String, Object?>{'wallId': 'w1', 'message': 'Original unavailable'});
    expect(first.breadcrumbs?.single.message, 'Download requested');
    expect(first.breadcrumbs?.single.category, 'wallpaper');
    expect(first.breadcrumbs?.single.level, SentryLevel.debug);
    expect(first.breadcrumbs?.single.data, <String, Object?>{'attempt': 2});
    expect(events[1].user, isNull);
    expect(events[1].tags?['tag'], isNull);
    expect(events[1].contexts['logger'], isNull);
    expect(events[1].level, SentryLevel.info);
    expect(events[2].level, SentryLevel.fatal);
    expect(events[2].contexts['logger'], <String, Object?>{'retryable': false});
  });
}
