import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:Prism/core/analytics/analytics_runtime.dart';
import 'package:Prism/core/monitoring/sentry_config.dart';
import 'package:Prism/core/state/app_state.dart' as app_state;
import 'package:Prism/core/widgets/prism/prism_button.dart';
import 'package:Prism/core/widgets/prism/prism_skeleton.dart';
import 'package:Prism/features/session/data/report_problem_service.dart';
import 'package:Prism/features/session/views/widgets/report_problem_sheet.dart';
import 'package:Prism/l10n/l10n.dart';
import 'package:Prism/logger/app_logger.dart';
import 'package:Prism/theme/toasts.dart' as toasts;
import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sentry_flutter/sentry_flutter.dart';

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

const SentryConfig _reportConfig = SentryConfig(
  dsn: 'https://public@o1.ingest.sentry.io/1',
  environment: 'staging',
  release: 'Prism@test',
  dist: 'test',
  enabled: true,
);

class _ReportTransport implements Transport {
  _ReportTransport(this.sent, {this.response});

  final List<String> sent;
  final Future<SentryId> Function()? response;

  @override
  Future<SentryId?> send(SentryEnvelope envelope) async {
    for (final SentryEnvelopeItem item in envelope.items) {
      final List<int> data = await item.dataFactory();
      final Map<String, dynamic> header = await item.header.toJson(data.length);
      if (header['type'] != 'feedback') continue;
      final Map<String, dynamic> event = jsonDecode(utf8.decode(data)) as Map<String, dynamic>;
      final Map<String, dynamic> contexts = event['contexts'] as Map<String, dynamic>;
      final Map<String, dynamic> feedback = contexts['feedback'] as Map<String, dynamic>;
      sent.add(feedback['message'] as String);
    }
    return response == null ? envelope.header.eventId : response!();
  }
}

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
    late FakeAppAnalytics events;
    late List<String> sent;
    late List<String> shared;

    setUp(() {
      events = FakeAppAnalytics();
      AnalyticsRuntime.instance = events;
      app_state.prismUser = profileUser(id: 'user-1', loggedIn: false);
      sent = <String>[];
      shared = <String>[];
    });
    tearDown(() {
      AnalyticsRuntime.reset();
      toasts.overlayResolver = null;
    });

    ReportProblemService service({
      Future<SentryId> Function()? capture,
      Future<String> Function()? readAppVersion,
      Future<String> Function()? readDevice,
      Future<void> Function()? share,
    }) => ReportProblemService(
      readRecords: () => <AppLogRecord>[_record('visible line')],
      readDevice: readDevice ?? () async => 'Pixel 8',
      readAppVersion: readAppVersion ?? () async => '3.4.0+340',
      shareFile: (text) async {
        shared.add(text);
        await share?.call();
      },
      canSend: () => true,
      readConfig: () => _reportConfig,
      feedbackTransport: _ReportTransport(sent, response: capture),
    );

    Future<void> openSheet(
      WidgetTester tester,
      ReportProblemService service, {
      ReportTrigger trigger = ReportTrigger.settings,
      Uint8List? screenshot,
      ScreenshotPicker? pick,
    }) async {
      tester.view.physicalSize = const Size(1170, 2532);
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Builder(
            builder: (context) => TextButton(
              onPressed: () => showReportProblemSheet(
                context,
                source: 'test',
                trigger: trigger,
                screenshot: screenshot,
                service: service,
                pickScreenshot: pick,
              ),
              child: const Text('open'),
            ),
          ),
        ),
      );
      toasts.overlayResolver = () => tester.state<OverlayState>(find.byType(Overlay).first);
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
    }

    PrismButton sendButton(WidgetTester tester) =>
        tester.widget<PrismButton>(find.byKey(const Key('report_problem_send')));

    Future<void> tapSend(WidgetTester tester) async {
      await tester.ensureVisible(find.byKey(const Key('report_problem_send')));
      await tester.tap(find.byKey(const Key('report_problem_send')));
    }

    testWidgets('shows a skeleton while the report builds', (tester) async {
      final version = Completer<String>();
      final reports = service(readAppVersion: () => version.future);
      tester.view.physicalSize = const Size(1170, 2532);
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Builder(
            builder: (context) => TextButton(
              onPressed: () =>
                  showReportProblemSheet(context, source: 'test', trigger: ReportTrigger.settings, service: reports),
              child: const Text('open'),
            ),
          ),
        ),
      );
      await tester.tap(find.text('open'));
      for (var i = 0; i < 10; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }

      expect(find.byType(PrismSkeleton), findsOneWidget);
      expect(find.text('Crash/freeze'), findsNothing);
      expect(sendButton(tester).onPressed, isNull);

      version.complete('3.4.0+340');
      await tester.pumpAndSettle();
      expect(find.text('Crash/freeze'), findsOneWidget);
    });

    testWidgets('Send stays off until the user picks a topic', (tester) async {
      await openSheet(tester, service());

      expect(find.text('Crash/freeze'), findsOneWidget);
      expect(find.text("Wallpaper won't set"), findsOneWidget);
      expect(sendButton(tester).onPressed, isNull);

      await tester.tap(find.text('Looks broken'));
      await tester.pump();

      expect(sendButton(tester).onPressed, isNotNull);
    });

    testWidgets('while sending, Send shows a spinner and cannot be tapped again', (tester) async {
      final pending = Completer<SentryId>();
      await openSheet(tester, service(capture: () => pending.future));

      await tester.tap(find.text('Slow'));
      await tester.enterText(find.byType(TextField), 'The screen freezes on Save');
      await tester.pump();
      await tapSend(tester);
      await tester.pump();

      expect(sendButton(tester).loading, isTrue);
      expect(sendButton(tester).onPressed, isNull);
      await tapSend(tester);
      await tester.pump();
      expect(sent, hasLength(1));

      pending.complete(SentryId.newId());
      await tester.pumpAndSettle();
    });

    testWidgets('Send and Share wait for a pending screenshot picker to finish', (tester) async {
      final picker = Completer<Uint8List?>();
      await openSheet(tester, service(), pick: () => picker.future);

      await tester.tap(find.text('Slow'));
      await tester.pump();
      await tester.ensureVisible(find.text('Add screenshot'));
      await tester.tap(find.text('Add screenshot'));
      await tester.pump();

      expect(sendButton(tester).onPressed, isNull);
      expect(tester.widget<PrismButton>(find.widgetWithText(PrismButton, 'Share as file')).onPressed, isNull);
      expect(tester.widget<PrismButton>(find.widgetWithText(PrismButton, 'Cancel')).onPressed, isNotNull);
      await tapSend(tester);
      await tester.ensureVisible(find.text('Share as file'));
      await tester.tap(find.text('Share as file'), warnIfMissed: false);
      await tester.pump();
      expect(sent, isEmpty);
      expect(shared, isEmpty);

      picker.complete(Uint8List.fromList(_png));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('report_problem_screenshot')), findsOneWidget);
      expect(sendButton(tester).onPressed, isNotNull);

      await tapSend(tester);
      await tester.pumpAndSettle();
      expect(sent, hasLength(1));
      expect(events.events.last.toWireParameters()['has_screenshot'], 1);
    });

    testWidgets('a failed screenshot picker restores Send and Share', (tester) async {
      final picker = Completer<Uint8List?>();
      await openSheet(tester, service(), pick: () => picker.future);

      await tester.tap(find.text('Slow'));
      await tester.pump();
      await tester.ensureVisible(find.text('Add screenshot'));
      await tester.tap(find.text('Add screenshot'));
      await tester.pump();

      expect(sendButton(tester).onPressed, isNull);
      picker.completeError(StateError('gallery unavailable'));
      await tester.pumpAndSettle();

      expect(sendButton(tester).onPressed, isNotNull);
      expect(tester.widget<PrismButton>(find.widgetWithText(PrismButton, 'Share as file')).onPressed, isNotNull);
    });

    testWidgets('the sent report inputs stay fixed until Send completes', (tester) async {
      final pending = Completer<SentryId>();
      await openSheet(tester, service(capture: () => pending.future), screenshot: Uint8List.fromList(_png));

      await tester.tap(find.text('Slow'));
      await tester.pump();
      await tapSend(tester);
      await tester.pump();

      await tester.ensureVisible(find.text('Remove'));
      await tester.tap(find.text('Remove'), warnIfMissed: false);
      await tester.pump();
      expect(tester.widget<TextField>(find.byType(TextField)).enabled, isFalse);
      expect(tester.testTextInput.isVisible, isFalse);
      expect(find.byKey(const Key('report_problem_screenshot')), findsOneWidget);
      expect(find.text('Slow'), findsOneWidget);

      pending.complete(SentryId.newId());
      await tester.pumpAndSettle();
      expect(events.events.last.toWireParameters()['has_screenshot'], 1);
      await tester.pump(const Duration(seconds: 5));
      await tester.pumpAndSettle();
    });

    testWidgets('failed send can retry the same note topic and screenshot', (tester) async {
      var attempts = 0;
      await openSheet(
        tester,
        service(
          capture: () async {
            attempts++;
            return attempts == 1 ? const SentryId.empty() : SentryId.newId();
          },
        ),
        screenshot: Uint8List.fromList(_png),
      );

      await tester.tap(find.text("Wallpaper won't set"));
      await tester.enterText(find.byType(TextField), 'Set button freezes');
      await tapSend(tester);
      await tester.pumpAndSettle();

      expect(find.text("Couldn't send"), findsOneWidget);
      expect(tester.widget<TextField>(find.byType(TextField)).controller?.text, 'Set button freezes');
      expect(sendButton(tester).onPressed, isNotNull);
      await tapSend(tester);
      await tester.pumpAndSettle();

      expect(sent, <String>['[wallpaper_wont_set] Set button freezes', '[wallpaper_wont_set] Set button freezes']);
      expect(events.events.last.toWireParameters(), <String, Object?>{
        'result': 'sent',
        'topic': 'wallpaper_wont_set',
        'has_screenshot': 1,
        'trigger': 'settings',
      });
      await tester.pump(const Duration(seconds: 5));
      await tester.pumpAndSettle();
    });

    testWidgets('a sent report closes the sheet and shows the reference', (tester) async {
      await openSheet(tester, service(), trigger: ReportTrigger.shake, screenshot: Uint8List.fromList(_png));

      await tester.tap(find.text("Wallpaper won't set"));
      await tester.enterText(find.byType(TextField), 'The set button spins forever');
      await tapSend(tester);
      await tester.pumpAndSettle();

      expect(sent, <String>['[wallpaper_wont_set] The set button spins forever']);
      expect(find.text('Report a problem'), findsNothing);
      expect(find.textContaining(RegExp(r'^Thanks, report sent\. Reference [A-HJKMNP-Z2-9]{6}$')), findsOneWidget);
      expect(events.events.last.eventName, 'report_problem_sent');
      expect(events.events.last.toWireParameters(), <String, Object?>{
        'result': 'sent',
        'topic': 'wallpaper_wont_set',
        'has_screenshot': 1,
        'trigger': 'shake',
      });
      await tester.pump(const Duration(seconds: 5));
      await tester.pumpAndSettle();
    });

    testWidgets("offline, the sheet stays open with Couldn't send, and Share instead shares the file", (tester) async {
      await openSheet(tester, service(capture: () async => throw const SocketException('Network is unreachable')));

      await tester.tap(find.text('Other'));
      await tester.enterText(find.byType(TextField), 'Mail me at jane@example.com');
      await tapSend(tester);
      await tester.pumpAndSettle();

      expect(find.text('Report a problem'), findsOneWidget);
      expect(find.text("Couldn't send"), findsOneWidget);
      expect(sendButton(tester).onPressed, isNotNull);

      // No scrolling: the message must be on screen right after the failed send.
      await tester.tap(find.text('Share instead'));
      await tester.pumpAndSettle();

      expect(shared, hasLength(1));
      expect(shared.single, startsWith('Topic: other\nNote: Mail me at [email removed]\n\nPrism problem report'));
      expect(shared.single, contains('visible line'));
      expect(find.text('Report a problem'), findsNothing);
    });

    testWidgets('Share as file without a topic shares the old report', (tester) async {
      await openSheet(tester, service());

      await tester.ensureVisible(find.text('Share as file'));
      await tester.tap(find.text('Share as file'));
      await tester.pumpAndSettle();

      expect(shared.single, startsWith('Prism problem report'));
      expect(find.text('Report a problem'), findsNothing);
    });

    testWidgets('share is unavailable when report building fails and the user has no other content', (tester) async {
      await openSheet(tester, service(readDevice: () async => throw StateError('device info unavailable')));

      expect(find.text("Couldn't build the report. Try again."), findsOneWidget);
      expect(tester.widget<PrismButton>(find.widgetWithText(PrismButton, 'Share as file')).onPressed, isNull);
    });

    testWidgets('share needs a note or topic when diagnostics are off and enables after a note is entered', (
      tester,
    ) async {
      await openSheet(tester, service());

      await tester.ensureVisible(find.byType(Switch));
      await tester.tap(find.byType(Switch));
      await tester.pumpAndSettle();
      expect(tester.widget<PrismButton>(find.widgetWithText(PrismButton, 'Share as file')).onPressed, isNull);

      await tester.enterText(find.byType(TextField), 'The screen freezes');
      await tester.pump();
      expect(tester.widget<PrismButton>(find.widgetWithText(PrismButton, 'Share as file')).onPressed, isNotNull);
      await tester.enterText(find.byType(TextField), '');
      await tester.pump();
      expect(tester.widget<PrismButton>(find.widgetWithText(PrismButton, 'Share as file')).onPressed, isNull);
      await tester.enterText(find.byType(TextField), 'The screen freezes');
      await tester.pump();

      await tester.ensureVisible(find.text('Share as file'));
      await tester.tap(find.text('Share as file'));
      await tester.pumpAndSettle();
      expect(shared.single, 'Note: The screen freezes\n\n');
    });

    testWidgets('a failed share after cancel does not show an error over the previous screen', (tester) async {
      final pending = Completer<void>();
      await openSheet(tester, service(share: () => pending.future));

      await tester.ensureVisible(find.text('Share as file'));
      await tester.tap(find.text('Share as file'));
      await tester.pump();
      final Switch diagnostics = tester.widget<Switch>(find.byType(Switch));
      expect(diagnostics.value, isTrue);
      await tester.ensureVisible(find.byType(Switch));
      await tester.tap(find.byType(Switch), warnIfMissed: false);
      await tester.pump();
      expect(tester.widget<Switch>(find.byType(Switch)).value, isTrue);
      await tester.ensureVisible(find.text('Cancel'));
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(find.text('Report a problem'), findsNothing);

      pending.completeError(StateError('share unavailable'));
      await tester.pumpAndSettle();
      expect(find.text("Couldn't share the report. Try again."), findsNothing);
    });

    testWidgets('turning logs off leaves them out of the shared file, and the preview shows them', (tester) async {
      await openSheet(tester, service());

      await tester.ensureVisible(find.text("Show what's included"));
      await tester.tap(find.text("Show what's included"));
      await tester.pumpAndSettle();
      expect(find.textContaining('visible line', findRichText: true), findsOneWidget);

      await tester.ensureVisible(find.text('Crash/freeze'));
      await tester.tap(find.text('Crash/freeze'));
      await tester.ensureVisible(find.byType(Switch));
      await tester.tap(find.byType(Switch));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('report_problem_preview')), findsNothing);

      await tester.ensureVisible(find.text('Share as file'));
      await tester.tap(find.text('Share as file'));
      await tester.pumpAndSettle();
      expect(shared.single, 'Topic: crash_freeze\n\n');
    });

    testWidgets('from Settings the user picks a screenshot and can remove it', (tester) async {
      await openSheet(tester, service(), pick: () async => Uint8List.fromList(_png));

      expect(find.byKey(const Key('report_problem_screenshot')), findsNothing);
      await tester.ensureVisible(find.text('Add screenshot'));
      await tester.tap(find.text('Add screenshot'));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('report_problem_screenshot')), findsOneWidget);

      await tester.tap(find.text('Remove'));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('report_problem_screenshot')), findsNothing);
    });

    testWidgets('empty screenshot thumbnail has an accessible add action', (tester) async {
      final semantics = tester.ensureSemantics();
      await openSheet(tester, service(), pick: () async => Uint8List.fromList(_png));
      final SemanticsData thumbnail = tester
          .getSemantics(find.byKey(const Key('report_problem_screenshot_thumbnail')))
          .getSemanticsData();
      expect(thumbnail.flagsCollection.isButton, isTrue);
      expect(thumbnail.label, 'Add screenshot');
      semantics.dispose();
    });

    testWidgets('screenshot preview opens in a labeled, back-dismissible Prism sheet', (tester) async {
      await openSheet(tester, service(), screenshot: Uint8List.fromList(_png));

      await tester.tap(find.byKey(const Key('report_problem_screenshot')));
      await tester.pumpAndSettle();
      expect(find.text('View screenshot'), findsOneWidget);
      expect(find.byType(InteractiveViewer), findsOneWidget);

      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(find.text('View screenshot'), findsNothing);
      expect(find.text('Report a problem'), findsOneWidget);
    });

    testWidgets('Cancel closes the sheet without sending or sharing', (tester) async {
      await openSheet(tester, service());

      await tester.ensureVisible(find.text('Cancel'));
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();

      expect(find.text('Report a problem'), findsNothing);
      expect(shared, isEmpty);
      expect(sent, isEmpty);
    });
  });
}

// A 1x1 transparent PNG.
const List<int> _png = <int>[
  0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, 0x00, 0x00, 0x00, 0x0D, 0x49, 0x48, 0x44, 0x52, //
  0x00, 0x00, 0x00, 0x01, 0x00, 0x00, 0x00, 0x01, 0x08, 0x06, 0x00, 0x00, 0x00, 0x1F, 0x15, 0xC4, //
  0x89, 0x00, 0x00, 0x00, 0x0D, 0x49, 0x44, 0x41, 0x54, 0x78, 0x9C, 0x63, 0x00, 0x01, 0x00, 0x00, //
  0x05, 0x00, 0x01, 0x0D, 0x0A, 0x2D, 0xB4, 0x00, 0x00, 0x00, 0x00, 0x49, 0x45, 0x4E, 0x44, 0xAE, //
  0x42, 0x60, 0x82, //
];
