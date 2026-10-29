import 'dart:convert';
import 'dart:typed_data';

import 'package:Prism/core/monitoring/sentry_config.dart';
import 'package:Prism/features/session/data/report_problem_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:sentry_flutter/sentry_flutter.dart';

class _RecordingTransport implements Transport {
  final List<SentryEnvelope> envelopes = <SentryEnvelope>[];

  @override
  Future<SentryId?> send(SentryEnvelope envelope) async {
    envelopes.add(envelope);
    return envelope.header.eventId;
  }
}

class _RejectingTransport implements Transport {
  @override
  Future<SentryId?> send(SentryEnvelope envelope) async => null;
}

class _EmptyTransport implements Transport {
  @override
  Future<SentryId?> send(SentryEnvelope envelope) async => const SentryId.empty();
}

class _ThrowingTransport implements Transport {
  @override
  Future<SentryId?> send(SentryEnvelope envelope) => Future<SentryId?>.error(StateError('transport failed'));
}

class _NativeFeedbackEnrichment implements EventProcessor {
  static int feedbackCalls = 0;

  @override
  Future<SentryEvent?> apply(SentryEvent event, Hint hint) async {
    if (event.type != 'feedback') return event;
    feedbackCalls++;
    event
      ..user = SentryUser(id: 'native-user', email: 'native@example.com')
      ..tags = <String, String>{...?event.tags, 'native_tag': 'private'}
      ..breadcrumbs = <Breadcrumb>[Breadcrumb(message: 'private breadcrumb')];
    event.contexts['native_context'] = <String, String>{'secret': 'must-not-leak'};
    final Map<String, dynamic> enriched = event.toJson()
      ..['extra'] = <String, String>{'native_secret': 'must-not-leak'};
    return SentryEvent.fromJson(enriched);
  }
}

class _Item {
  _Item(this.header, this.data);

  final Map<String, dynamic> header;
  final List<int> data;

  Map<String, dynamic> get json => jsonDecode(utf8.decode(data)) as Map<String, dynamic>;
}

Future<List<_Item>> _items(SentryEnvelope envelope) async {
  final List<_Item> items = <_Item>[];
  for (final SentryEnvelopeItem item in envelope.items) {
    final List<int> data = await item.dataFactory();
    items.add(_Item(await item.header.toJson(data.length), data));
  }
  return items;
}

const SentryConfig _config = SentryConfig(
  dsn: 'https://public@o1.ingest.sentry.io/1',
  environment: 'staging',
  release: 'Prism@3.14.0+353',
  dist: '353',
  enabled: true,
);

void main() {
  late _RecordingTransport transport;

  setUp(() async {
    transport = _RecordingTransport();
    _NativeFeedbackEnrichment.feedbackCalls = 0;
    await Sentry.init((SentryOptions options) {
      options.dsn = _config.dsn;
      options.transport = transport;
      options.release = _config.release;
      options.environment = _config.environment;
      options.addEventProcessor(_NativeFeedbackEnrichment());
    });
    await Sentry.configureScope((Scope scope) async {
      await scope.setUser(SentryUser(id: 'user-1', email: 'jane@example.com'));
      await scope.setTag('ambient', 'private');
      await scope.setContexts('ambient', <String, String>{'secret': 'must-not-leak'});
      scope.addAttachment(SentryAttachment.fromIntList(utf8.encode('global private attachment'), 'private.txt'));
    });
  });

  tearDown(Sentry.close);

  ReportProblemService service({bool canSend = true, Transport? feedbackTransport}) => ReportProblemService(
    readConfig: () => _config,
    canSend: () => canSend,
    feedbackTransport: feedbackTransport ?? transport,
  );

  test(
    'sends feedback tagged with release, environment, topic, trigger and screenshot, linked to the last error',
    () async {
      final SentryId crash = await Sentry.captureMessage('boom');
      transport.envelopes.clear();

      final String reference = await service().send(
        ProblemReportDraft(
          topic: ReportTopic.wallpaperWontSet,
          trigger: ReportTrigger.shake,
          note: 'Set button spins forever. Email me at jane@example.com',
          screenshot: Uint8List.fromList(<int>[137, 80, 78, 71]),
          diagnostics: 'Prism problem report\nContact: jane@example.com',
        ),
      );

      expect(reference, matches(RegExp(r'^[A-HJKMNP-Z2-9]{6}$')));
      expect(transport.envelopes, hasLength(1));
      final List<_Item> items = await _items(transport.envelopes.single);
      final _Item feedback = items.singleWhere((_Item i) => i.header['type'] == 'feedback');
      final Map<String, dynamic> event = feedback.json;
      expect(event['tags'], <String, dynamic>{
        'release': 'Prism@3.14.0+353',
        'environment': 'staging',
        'topic': 'wallpaper_wont_set',
        'trigger': 'shake',
        'hasScreenshot': 'true',
        'reference': reference,
      });
      expect(event['release'], 'Prism@3.14.0+353');
      expect(event['environment'], 'staging');
      expect(event['user'], isNull);
      expect(event['extra'], isNull);
      expect(event['breadcrumbs'], isNull);
      expect((event['tags'] as Map<String, dynamic>).containsKey('native_tag'), isFalse);
      expect((event['tags'] as Map<String, dynamic>).containsKey('ambient'), isFalse);
      final Map<String, dynamic> contexts = event['contexts'] as Map<String, dynamic>;
      expect(contexts.keys, <String>['feedback']);
      final Map<String, dynamic> body = contexts['feedback'] as Map<String, dynamic>;
      expect(body['message'], '[wallpaper_wont_set] Set button spins forever. Email me at [email removed]');
      expect(body['associated_event_id'], crash.toString());
      expect(transport.envelopes.single.header.traceContext, isNull);
      expect(_NativeFeedbackEnrichment.feedbackCalls, 0);

      final List<_Item> attachments = items.where((_Item i) => i.header['type'] == 'attachment').toList();
      expect(attachments.map((_Item i) => i.header['filename']), <String>[
        'screenshot.png',
        'prism-problem-report.txt',
      ]);
      expect(attachments.first.data, <int>[137, 80, 78, 71]);
      expect(utf8.decode(attachments.last.data), 'Prism problem report\nContact: [email removed]');
      expect(attachments.any((_Item item) => item.header['filename'] == 'private.txt'), isFalse);
    },
  );

  test('without a screenshot or logs, tags hasScreenshot false and attaches nothing', () async {
    await service().send(const ProblemReportDraft(topic: ReportTopic.slow, trigger: ReportTrigger.settings));

    final List<_Item> items = await _items(transport.envelopes.single);
    final Map<String, dynamic> event = items.singleWhere((_Item i) => i.header['type'] == 'feedback').json;
    expect((event['tags'] as Map<String, dynamic>)['hasScreenshot'], 'false');
    final Map<String, dynamic> feedback =
        (event['contexts'] as Map<String, dynamic>)['feedback'] as Map<String, dynamic>;
    expect(feedback['message'], '[slow]');
    expect(feedback.containsKey('associated_event_id'), isFalse);
    expect(items.where((_Item i) => i.header['type'] == 'attachment'), isEmpty);
  });

  test('with monitoring off, throws and sends nothing', () async {
    const ProblemReportDraft draft = ProblemReportDraft(topic: ReportTopic.other, trigger: ReportTrigger.menu);

    await expectLater(
      service(canSend: false).send(draft),
      throwsA(isA<ReportNotSentException>().having((ReportNotSentException e) => e.reason, 'reason', 'monitoring_off')),
    );
    expect(transport.envelopes, isEmpty);
  });

  test('a transport rejection or error is reported as unsent', () async {
    for (final Transport failedTransport in <Transport>[
      _RejectingTransport(),
      _EmptyTransport(),
      _ThrowingTransport(),
    ]) {
      await expectLater(
        service(
          feedbackTransport: failedTransport,
        ).send(const ProblemReportDraft(topic: ReportTopic.other, trigger: ReportTrigger.menu)),
        throwsA(isA<ReportNotSentException>().having((ReportNotSentException e) => e.reason, 'reason', 'rejected')),
      );
    }
  });

  test('a rejected HTTP response is reported as unsent', () async {
    final MockClient httpClient = MockClient((http.Request request) async => http.Response('', 429));
    final ReportProblemService reports = ReportProblemService(
      readConfig: () => _config,
      canSend: () => true,
      feedbackHttpClient: httpClient,
    );

    await expectLater(
      reports.send(const ProblemReportDraft(topic: ReportTopic.other, trigger: ReportTrigger.menu)),
      throwsA(isA<ReportNotSentException>().having((ReportNotSentException e) => e.reason, 'reason', 'rejected')),
    );
  });

  test('missing reporting configuration fails before creating a client', () async {
    final ReportProblemService unconfigured = ReportProblemService(
      readConfig: () => null,
      canSend: () => true,
      feedbackTransport: transport,
    );

    await expectLater(
      unconfigured.send(const ProblemReportDraft(topic: ReportTopic.other, trigger: ReportTrigger.menu)),
      throwsA(
        isA<ReportNotSentException>().having((ReportNotSentException e) => e.reason, 'reason', 'configuration_missing'),
      ),
    );
    expect(transport.envelopes, isEmpty);
  });

  test('blank release or environment cannot produce feedback tags', () async {
    for (final SentryConfig config in <SentryConfig>[
      const SentryConfig(
        dsn: 'https://public@o1.ingest.sentry.io/1',
        environment: 'staging',
        release: '',
        dist: '353',
        enabled: true,
      ),
      const SentryConfig(
        dsn: 'https://public@o1.ingest.sentry.io/1',
        environment: '',
        release: 'Prism@3.14.0+353',
        dist: '353',
        enabled: true,
      ),
    ]) {
      final ReportProblemService unconfigured = ReportProblemService(
        readConfig: () => config,
        canSend: () => true,
        feedbackTransport: transport,
      );

      await expectLater(
        unconfigured.send(const ProblemReportDraft(topic: ReportTopic.other, trigger: ReportTrigger.menu)),
        throwsA(
          isA<ReportNotSentException>().having(
            (ReportNotSentException e) => e.reason,
            'reason',
            'configuration_missing',
          ),
        ),
      );
    }
    expect(transport.envelopes, isEmpty);
  });

  test('share boundary scrubs caller-provided report text', () async {
    String? shared;
    final ReportProblemService reports = ReportProblemService(shareFile: (String report) async => shared = report);

    await reports.share('Contact jane@example.com\napi_key=secret-123', subject: 'subject', shareText: 'share');

    expect(shared, 'Contact [email removed]\napi_key=[removed]');
  });
}
