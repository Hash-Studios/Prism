import 'dart:convert';
import 'dart:typed_data';

import 'package:Prism/core/monitoring/sentry_config.dart';
import 'package:Prism/features/session/data/report_problem_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sentry_flutter/sentry_flutter.dart';

class _RecordingTransport implements Transport {
  final List<SentryEnvelope> envelopes = <SentryEnvelope>[];

  @override
  Future<SentryId?> send(SentryEnvelope envelope) async {
    envelopes.add(envelope);
    return envelope.header.eventId;
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
    await Sentry.init((SentryOptions options) {
      options.dsn = _config.dsn;
      options.transport = transport;
      options.release = _config.release;
      options.environment = _config.environment;
    });
    await Sentry.configureScope((Scope scope) => scope.setUser(SentryUser(id: 'user-1', email: 'jane@example.com')));
  });

  tearDown(Sentry.close);

  ReportProblemService service({bool online = true, bool canSend = true}) =>
      ReportProblemService(readConfig: () => _config, isOnline: () async => online, canSend: () => canSend);

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
          diagnostics: 'Prism problem report\nApp: 3.14.0+353',
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
      final Map<String, dynamic> contexts = event['contexts'] as Map<String, dynamic>;
      final Map<String, dynamic> body = contexts['feedback'] as Map<String, dynamic>;
      expect(body['message'], '[wallpaper_wont_set] Set button spins forever. Email me at [email removed]');
      expect(body['associated_event_id'], crash.toString());

      final List<_Item> attachments = items.where((_Item i) => i.header['type'] == 'attachment').toList();
      expect(attachments.map((_Item i) => i.header['filename']), <String>[
        'screenshot.png',
        'prism-problem-report.txt',
      ]);
      expect(attachments.first.data, <int>[137, 80, 78, 71]);
      expect(utf8.decode(attachments.last.data), 'Prism problem report\nApp: 3.14.0+353');
    },
  );

  test('without a screenshot or logs, tags hasScreenshot false and attaches nothing', () async {
    await service().send(const ProblemReportDraft(topic: ReportTopic.slow, trigger: ReportTrigger.settings));

    final List<_Item> items = await _items(transport.envelopes.single);
    final Map<String, dynamic> event = items.singleWhere((_Item i) => i.header['type'] == 'feedback').json;
    expect((event['tags'] as Map<String, dynamic>)['hasScreenshot'], 'false');
    expect(((event['contexts'] as Map<String, dynamic>)['feedback'] as Map<String, dynamic>)['message'], '[slow]');
    expect(items.where((_Item i) => i.header['type'] == 'attachment'), isEmpty);
  });

  test('offline or with monitoring off, throws and sends nothing', () async {
    const ProblemReportDraft draft = ProblemReportDraft(topic: ReportTopic.other, trigger: ReportTrigger.menu);

    await expectLater(
      service(online: false).send(draft),
      throwsA(isA<ReportNotSentException>().having((ReportNotSentException e) => e.reason, 'reason', 'offline')),
    );
    await expectLater(
      service(canSend: false).send(draft),
      throwsA(isA<ReportNotSentException>().having((ReportNotSentException e) => e.reason, 'reason', 'monitoring_off')),
    );
    expect(transport.envelopes, isEmpty);
  });
}
