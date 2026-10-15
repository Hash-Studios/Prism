import 'dart:io';

import 'package:Prism/core/debug/in_memory_log_sink.dart';
import 'package:Prism/core/state/app_state.dart' as app_state;
import 'package:Prism/logger/app_logger.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:path_provider/path_provider.dart';
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

typedef DeviceLabelReader = Future<String> Function();
typedef AppVersionReader = Future<String> Function();
typedef ReportFileSharer = Future<void> Function(String text);

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

Future<void> _shareReportFile(String text) async {
  final Directory dir = await getTemporaryDirectory();
  final File file = File('${dir.path}/prism-problem-report.txt');
  await file.writeAsString(text, flush: true);
  await SharePlus.instance.share(
    ShareParams(
      files: <XFile>[XFile(file.path, mimeType: 'text/plain')],
      subject: 'Prism problem report',
      text: 'Please describe what went wrong. The report file has the details.',
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
  }) : _readRecords = readRecords ?? (() => InMemoryLogSink.instance.records),
       _readDevice = readDevice ?? _platformDeviceLabel,
       _readAppVersion = readAppVersion ?? _platformAppVersion,
       _shareFile = shareFile ?? _shareReportFile,
       _clock = clock ?? DateTime.now;

  static final ReportProblemService instance = ReportProblemService();

  final List<AppLogRecord> Function() _readRecords;
  final DeviceLabelReader _readDevice;
  final AppVersionReader _readAppVersion;
  final ReportFileSharer _shareFile;
  final DateTime Function() _clock;

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

  Future<void> share(String report) => _shareFile(report);
}
