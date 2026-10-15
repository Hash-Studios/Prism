import 'package:Prism/core/analytics/analytics_runtime.dart';
import 'package:Prism/core/state/app_state.dart' as app_state;
import 'package:Prism/features/session/data/report_problem_service.dart';
import 'package:Prism/features/session/views/widgets/report_problem_sheet.dart';
import 'package:Prism/logger/app_logger.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/fake_app_analytics.dart';
import '../../support/profile_user_fixture.dart';

AppLogRecord _record(
  String message, {
  AppLogLevel level = AppLogLevel.info,
  String? tag,
  Object? error,
  StackTrace? stackTrace,
  int sequence = 1,
}) {
  return AppLogRecord(
    sequence: sequence,
    timestamp: DateTime.utc(2026, 3, 1, 10, 30),
    level: level,
    message: message,
    tag: tag,
    error: error,
    stackTrace: stackTrace,
  );
}

const ReportEnvironment _environment = ReportEnvironment(
  appVersion: '3.4.0+340',
  device: 'Google Pixel 8',
  os: 'android 15',
  theme: 'dark',
  signedIn: true,
);

void main() {
  group('scrubSensitive', () {
    test('removes email addresses', () {
      final out = scrubSensitive('user jane.doe+prism@example.co.uk opened settings');

      expect(out, isNot(contains('jane')));
      expect(out, isNot(contains('example.co.uk')));
      expect(out, contains('[email removed]'));
    });

    test('removes bearer tokens, JWTs and FCM tokens', () {
      const jwt = 'eyJhbGciOiJSUzI1NiJ9.eyJzdWIiOiIxMjM0In0.c2lnbmF0dXJl';
      const fcm = 'dXk3Hq2aBcD:APA91bFgH1jK2lMnOpQrStUvWxYz';

      expect(scrubSensitive('Authorization: Bearer abc.def-123_456'), isNot(contains('abc.def')));
      expect(scrubSensitive('id token $jwt sent'), isNot(contains('eyJ')));
      expect(scrubSensitive('push token $fcm saved'), isNot(contains('APA91')));
    });

    test('removes values next to secret-like names and URL query strings', () {
      expect(scrubSensitive('api_key=AIzaSyD-1234567890'), 'api_key=[removed]');
      expect(scrubSensitive('{"refreshToken": "r-abc123"}'), isNot(contains('r-abc123')));
      expect(
        scrubSensitive('GET https://api.example.com/v1/walls?uid=abc123&sig=zzz failed'),
        'GET https://api.example.com/v1/walls?[query removed] failed',
      );
    });

    test('removes long id-like runs and keeps plain words, short numbers and the path', () {
      expect(scrubSensitive('user id 4f8aB2c9D1eF3g4H5i6J7k8L9m0NpQrS'), isNot(contains('4f8aB2c9')));
      expect(
        scrubSensitive('Loaded 24 wallpapers in 310 ms from prism_feed'),
        'Loaded 24 wallpapers in 310 ms from prism_feed',
      );
    });
  });

  group('buildProblemReport', () {
    test('starts with the device facts and says whether the user is signed in, without account data', () {
      final report = buildProblemReport(
        environment: _environment,
        records: <AppLogRecord>[_record('hello')],
        now: DateTime.utc(2026, 3, 1, 11),
      );

      expect(report, contains('App: 3.4.0+340'));
      expect(report, contains('Device: Google Pixel 8'));
      expect(report, contains('OS: android 15'));
      expect(report, contains('Theme: dark'));
      expect(report, contains('Signed in: yes'));
      expect(report, contains('Created: 2026-03-01T11:00:00.000Z'));
      expect(report, contains('Recent logs (1)'));
    });

    test('keeps the newest records up to the limit', () {
      final records = <AppLogRecord>[for (var i = 1; i <= 5; i++) _record('line $i', sequence: i)];

      final report = buildProblemReport(environment: _environment, records: records, now: DateTime.utc(2026), limit: 3);

      expect(report, contains('Recent logs (3)'));
      expect(report, isNot(contains('line 2')));
      expect(report, contains('line 3'));
      expect(report, contains('line 5'));
    });

    test('scrubs the message, the error and the stack, and clips the stack', () {
      final stack = StackTrace.fromString(
        <String>[for (var i = 0; i < 20; i++) '#$i frame$i (file.dart:1:1)'].join('\n'),
      );
      final report = buildProblemReport(
        environment: _environment,
        records: <AppLogRecord>[
          _record(
            'Sign in failed for jane@example.com',
            level: AppLogLevel.error,
            tag: 'Auth',
            error: 'token=abc123secret',
            stackTrace: stack,
          ),
        ],
        now: DateTime.utc(2026),
      );

      expect(report, contains('ERR [Auth] Sign in failed for [email removed]'));
      expect(report, isNot(contains('jane@')));
      expect(report, isNot(contains('abc123secret')));
      expect(report, contains('frame5'));
      expect(report, isNot(contains('frame6')));
    });

    test('says so when there are no logs', () {
      final report = buildProblemReport(environment: _environment, records: const [], now: DateTime.utc(2026));

      expect(report, contains('No logs yet in this session.'));
    });

    test('reports a guest as not signed in', () {
      final report = buildProblemReport(
        environment: const ReportEnvironment(appVersion: '1', device: 'd', os: 'o', theme: 'light', signedIn: false),
        records: const [],
        now: DateTime.utc(2026),
      );

      expect(report, contains('Signed in: no'));
    });
  });

  group('ReportProblemService', () {
    test('reads the logs, device and version, and uses the signed-in state of the user', () async {
      app_state.prismUser = profileUser(id: 'user-1');
      final service = ReportProblemService(
        readRecords: () => <AppLogRecord>[_record('from the sink')],
        readDevice: () async => 'Pixel 8',
        readAppVersion: () async => '3.4.0+340',
        clock: () => DateTime.utc(2026, 3),
      );

      final report = await service.buildReport(theme: 'light');

      expect(report, contains('Device: Pixel 8'));
      expect(report, contains('App: 3.4.0+340'));
      expect(report, contains('Theme: light'));
      expect(report, contains('Signed in: yes'));
      expect(report, contains('from the sink'));
    });
  });

  group('report sheet', () {
    setUp(() => AnalyticsRuntime.instance = FakeAppAnalytics());
    tearDown(AnalyticsRuntime.reset);

    Future<void> openSheet(WidgetTester tester, ReportProblemService service) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => TextButton(
              onPressed: () => showReportProblemSheet(context, source: 'test', service: service),
              child: const Text('open'),
            ),
          ),
        ),
      );
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
    }

    testWidgets('shows the report before sharing, and Share sends that text', (tester) async {
      app_state.prismUser = profileUser(id: 'user-1', loggedIn: false);
      final shared = <String>[];
      final service = ReportProblemService(
        readRecords: () => <AppLogRecord>[_record('visible line')],
        readDevice: () async => 'Pixel 8',
        readAppVersion: () async => '3.4.0+340',
        shareFile: (text) async => shared.add(text),
      );
      await openSheet(tester, service);

      expect(find.text('Report a problem'), findsOneWidget);
      expect(find.byKey(const Key('report_problem_preview')), findsOneWidget);
      expect(find.textContaining('visible line', findRichText: true), findsOneWidget);

      await tester.tap(find.text('Share'));
      await tester.pumpAndSettle();

      expect(shared, hasLength(1));
      expect(shared.single, contains('visible line'));
      expect(find.text('Report a problem'), findsNothing);
    });

    testWidgets('Cancel closes the sheet without sharing', (tester) async {
      final shared = <String>[];
      final service = ReportProblemService(
        readRecords: () => const [],
        readDevice: () async => 'Pixel 8',
        readAppVersion: () async => '1',
        shareFile: (text) async => shared.add(text),
      );
      await openSheet(tester, service);

      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();

      expect(find.text('Report a problem'), findsNothing);
      expect(shared, isEmpty);
    });
  });
}
