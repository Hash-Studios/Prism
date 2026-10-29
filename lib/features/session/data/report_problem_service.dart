import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:Prism/core/debug/in_memory_log_sink.dart';
import 'package:Prism/core/monitoring/monitoring_runtime.dart';
import 'package:Prism/core/monitoring/sentry_config.dart';
import 'package:Prism/core/state/app_state.dart' as app_state;
import 'package:Prism/logger/app_logger.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:package_info_plus/package_info_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'package:sentry_flutter/sentry_flutter.dart';
import 'package:share_plus/share_plus.dart';

const String supportEmail = 'hash.studios.inc@gmail.com';

const int reportLogLimit = 300;
const int _maxLineLength = 400;
const int _maxStackLines = 6;

final RegExp _emailPattern = RegExp(r'[A-Za-z0-9._%+\-]+@[A-Za-z0-9\-]+(?:\.[A-Za-z0-9\-]+)+');
final RegExp _bearerPattern = RegExp(r'\b(Bearer|Basic)\s+[A-Za-z0-9._~+/\-]+=*', caseSensitive: false);
final RegExp _jwtPattern = RegExp(r'\beyJ[A-Za-z0-9_\-]+\.[A-Za-z0-9_\-]+\.[A-Za-z0-9_\-]*');
final RegExp _fcmTokenPattern = RegExp(r'\b[A-Za-z0-9_\-]{8,}:APA91[A-Za-z0-9_\-]+');
final RegExp _secretPairPattern = RegExp(
  r'''\b([A-Za-z_\-]*(?:token|api[_\-]?key|secret|password|authorization|signature))(["']?\s*[:=]\s*["']?)(?!\[)[^\s"'&,;}]+''',
  caseSensitive: false,
);
final RegExp _urlQueryPattern = RegExp(r'(https?://[^\s?#"]+)\?[^\s"]*');
// A long run of letters and digits with at least one of each: ids, session handles and keys.
final RegExp _longTokenPattern = RegExp(r'\b(?=[A-Za-z0-9_\-]*\d)(?=[A-Za-z0-9_\-]*[A-Za-z])[A-Za-z0-9_\-]{28,}\b');

/// Removes emails, tokens, keys and URL query strings from [input]. Run it on every line of a report.
String scrubSensitive(String input) {
  return input
      .replaceAllMapped(_urlQueryPattern, (Match m) => '${m[1]}?[query removed]')
      .replaceAll(_bearerPattern, '[token removed]')
      .replaceAll(_jwtPattern, '[token removed]')
      .replaceAll(_fcmTokenPattern, '[token removed]')
      .replaceAllMapped(_secretPairPattern, (Match m) => '${m[1]}${m[2]}[removed]')
      .replaceAll(_emailPattern, '[email removed]')
      .replaceAll(_longTokenPattern, '[id removed]');
}

String _clip(String line) => line.length <= _maxLineLength ? line : '${line.substring(0, _maxLineLength)}...';

String _formatTime(DateTime time) => time.toUtc().toIso8601String();

/// One log record as a single scrubbed block: header line, the error, and the top of the stack trace.
String _formatLogRecord(AppLogRecord record) {
  final StringBuffer out = StringBuffer()
    ..write(_formatTime(record.timestamp))
    ..write(' ')
    ..write(record.level.shortLabel)
    ..write(record.tag == null ? ' ' : ' [${record.tag}] ')
    ..write(record.message);
  if (record.error != null) out.write('\n  error: ${record.error}');
  if (record.stackTrace != null) {
    final List<String> frames = record.stackTrace
        .toString()
        .split('\n')
        .where((String l) => l.trim().isNotEmpty)
        .toList();
    for (final String frame in frames.take(_maxStackLines)) {
      out.write('\n  $frame');
    }
  }
  return out.toString().split('\n').map((String line) => _clip(scrubSensitive(line))).join('\n');
}

/// What the report says about the device and the app. It holds no account data.
@immutable
class ReportEnvironment {
  const ReportEnvironment({
    required this.appVersion,
    required this.device,
    required this.os,
    required this.theme,
    required this.signedIn,
  });

  final String appVersion;
  final String device;
  final String os;
  final String theme;
  final bool signedIn;
}

/// Builds the text of the report. Pure: pass the records and the clock in.
String buildProblemReport({
  required ReportEnvironment environment,
  required List<AppLogRecord> records,
  required DateTime now,
  int limit = reportLogLimit,
}) {
  final List<AppLogRecord> recent = records.length > limit ? records.sublist(records.length - limit) : records;
  final StringBuffer out = StringBuffer()
    ..writeln('Prism problem report')
    ..writeln('Created: ${_formatTime(now)}')
    ..writeln('App: ${environment.appVersion}')
    ..writeln('Device: ${environment.device}')
    ..writeln('OS: ${environment.os}')
    ..writeln('Theme: ${environment.theme}')
    ..writeln('Signed in: ${environment.signedIn ? 'yes' : 'no'}')
    ..writeln()
    ..writeln('Recent logs (${recent.length})');
  if (recent.isEmpty) {
    out.writeln('No logs yet in this session.');
  }
  for (final AppLogRecord record in recent) {
    out.writeln(_formatLogRecord(record));
  }
  return out.toString();
}

/// What the problem is about. [wire] is the value in Sentry tags and analytics.
enum ReportTopic {
  crashFreeze('crash_freeze'),
  wallpaperWontSet('wallpaper_wont_set'),
  looksBroken('looks_broken'),
  slow('slow'),
  other('other');

  const ReportTopic(this.wire);

  final String wire;
}

/// How the user opened the report.
enum ReportTrigger { settings, shake, menu }

/// One report as the user sends it. [diagnostics] is null when the user turned device info and logs off.
@immutable
class ProblemReportDraft {
  const ProblemReportDraft({
    required this.topic,
    required this.trigger,
    this.note = '',
    this.screenshot,
    this.diagnostics,
  });

  final ReportTopic topic;
  final ReportTrigger trigger;
  final String note;
  final Uint8List? screenshot;
  final String? diagnostics;
}

/// The report did not reach Sentry: no connection, monitoring is off in this build, or Sentry dropped it.
class ReportNotSentException implements Exception {
  const ReportNotSentException(this.reason);

  final String reason;

  @override
  String toString() => 'ReportNotSentException: $reason';
}

// No 0/O or 1/I/L: users read the reference back to support.
const String _referenceAlphabet = 'ABCDEFGHJKMNPQRSTUVWXYZ23456789';

String _newReference(Random random) => String.fromCharCodes(
  List<int>.generate(6, (_) => _referenceAlphabet.codeUnitAt(random.nextInt(_referenceAlphabet.length))),
);

// A stalled network ends in "Couldn't send" instead of a spinner that never stops.
const Duration _sendTimeout = Duration(seconds: 30);

typedef DeviceLabelReader = Future<String> Function();
typedef AppVersionReader = Future<String> Function();
typedef ReportFileSharer = Future<void> Function(String text);

SentryClient _createFeedbackClient(
  SentryConfig config,
  Map<String, String> tags,
  Transport? transport,
  http.Client? httpClient,
) {
  final SentryOptions options = SentryOptions(dsn: config.dsn)
    ..environment = config.environment
    ..release = config.release
    ..dist = config.dist
    ..sendDefaultPii = false
    ..beforeSendFeedback = (SentryEvent event, Hint hint) {
      event.tags = Map<String, String>.of(tags);
      return event;
    };
  if (transport != null) options.transport = transport;
  if (httpClient != null) options.httpClient = httpClient;
  return SentryClient(options);
}

Future<String> _platformDeviceLabel() async {
  try {
    final DeviceInfoPlugin plugin = DeviceInfoPlugin();
    if (Platform.isAndroid) {
      final AndroidDeviceInfo info = await plugin.androidInfo;
      return '${info.manufacturer} ${info.model}';
    }
    if (Platform.isIOS) {
      final IosDeviceInfo info = await plugin.iosInfo;
      return info.utsname.machine;
    }
  } catch (_) {
    // The report still works without a device name.
  }
  return 'unknown';
}

Future<String> _platformAppVersion() async {
  try {
    final PackageInfo info = await PackageInfo.fromPlatform();
    return '${info.version}+${info.buildNumber}';
  } catch (_) {
    return '${app_state.currentAppVersion}+${app_state.currentAppVersionCode}';
  }
}

Future<void> _shareReportFile(String text, {required String subject, required String shareText}) async {
  final Directory dir = await getTemporaryDirectory();
  final File file = File('${dir.path}/prism-problem-report.txt');
  await file.writeAsString(text, flush: true);
  await SharePlus.instance.share(
    ShareParams(
      files: <XFile>[XFile(file.path, mimeType: 'text/plain')],
      subject: subject,
      text: shareText,
    ),
  );
}

/// Collects the report from the in-memory logs and shares it as a text file.
class ReportProblemService {
  ReportProblemService({
    List<AppLogRecord> Function()? readRecords,
    DeviceLabelReader? readDevice,
    AppVersionReader? readAppVersion,
    ReportFileSharer? shareFile,
    DateTime Function()? clock,
    bool Function()? canSend,
    SentryConfig? Function()? readConfig,
    Random? random,
    Transport? feedbackTransport,
    http.Client? feedbackHttpClient,
  }) : _readRecords = readRecords ?? (() => InMemoryLogSink.instance.records),
       _readDevice = readDevice ?? _platformDeviceLabel,
       _readAppVersion = readAppVersion ?? _platformAppVersion,
       _shareFile = shareFile,
       _clock = clock ?? DateTime.now,
       _canSend = canSend ?? (() => MonitoringRuntime.reporter.isEnabled),
       _readConfig = readConfig ?? (() => MonitoringRuntime.config),
       _random = random ?? Random.secure(),
       _feedbackTransport = feedbackTransport,
       _feedbackHttpClient = feedbackHttpClient;

  static final ReportProblemService instance = ReportProblemService();

  final List<AppLogRecord> Function() _readRecords;
  final DeviceLabelReader _readDevice;
  final AppVersionReader _readAppVersion;
  final ReportFileSharer? _shareFile;
  final DateTime Function() _clock;
  final bool Function() _canSend;
  final SentryConfig? Function() _readConfig;
  final Random _random;
  final Transport? _feedbackTransport;
  final http.Client? _feedbackHttpClient;

  /// The report text, with [theme] set to what the user sees, such as `dark`.
  Future<String> buildReport({required String theme}) async {
    final List<String> parts = await Future.wait(<Future<String>>[_readDevice(), _readAppVersion()]);
    return buildProblemReport(
      environment: ReportEnvironment(
        appVersion: parts[1],
        device: parts[0],
        os: '${Platform.operatingSystem} ${Platform.operatingSystemVersion}',
        theme: theme,
        signedIn: app_state.prismUser.loggedIn,
      ),
      records: _readRecords(),
      now: _clock(),
    );
  }

  Future<void> share(String report, {required String subject, required String shareText}) {
    final String safeReport = scrubSensitive(report);
    return _shareFile?.call(safeReport) ?? _shareReportFile(safeReport, subject: subject, shareText: shareText);
  }

  /// Sends [draft] as Sentry user feedback and returns the 6-character reference the user can quote to support.
  /// Throws [ReportNotSentException] when the report cannot reach Sentry, so the user can share the file instead.
  Future<String> send(ProblemReportDraft draft) async {
    if (!_canSend()) throw const ReportNotSentException('monitoring_off');
    final SentryConfig? config = _readConfig();
    if (config == null ||
        !config.enabled ||
        config.dsn.trim().isEmpty ||
        config.release.trim().isEmpty ||
        config.environment.trim().isEmpty) {
      throw const ReportNotSentException('configuration_missing');
    }
    final String reference = _newReference(_random);
    final String note = scrubSensitive(draft.note.trim());
    final SentryId lastEventId = Sentry.lastEventId;
    final SentryFeedback feedback = SentryFeedback(
      message: note.isEmpty ? '[${draft.topic.wire}]' : '[${draft.topic.wire}] $note',
      associatedEventId: lastEventId == const SentryId.empty() ? null : lastEventId,
    );
    final Map<String, String> tags = <String, String>{
      'release': config.release,
      'environment': config.environment,
      'topic': draft.topic.wire,
      'trigger': draft.trigger.name,
      'hasScreenshot': '${draft.screenshot != null}',
      'reference': reference,
    };
    final SentryClient client = _createFeedbackClient(config, tags, _feedbackTransport, _feedbackHttpClient);
    final Hint hint = Hint();
    _addDraftAttachments(hint, draft);
    final SentryId id;
    try {
      // No scope: feedback must not inherit the app's native identity, contexts, breadcrumbs, or replay state.
      id = await client.captureFeedback(feedback, hint: hint).timeout(_sendTimeout);
    } catch (_) {
      throw const ReportNotSentException('rejected');
    } finally {
      await client.close();
    }
    if (id == const SentryId.empty()) throw const ReportNotSentException('rejected');
    return reference;
  }
}

void _addDraftAttachments(Hint hint, ProblemReportDraft draft) {
  final Uint8List? screenshot = draft.screenshot;
  if (screenshot != null) {
    hint.attachments.add(SentryAttachment.fromUint8List(screenshot, 'screenshot.png', contentType: 'image/png'));
  }
  final String? diagnostics = draft.diagnostics;
  if (diagnostics != null) {
    hint.attachments.add(
      SentryAttachment.fromIntList(
        utf8.encode(scrubSensitive(diagnostics)),
        'prism-problem-report.txt',
        contentType: 'text/plain',
      ),
    );
  }
}
