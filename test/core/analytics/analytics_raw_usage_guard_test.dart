import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

Future<ProcessResult> _runGuard({required Directory workspaceDir, String? libFileContents}) {
  final Directory toolDir = Directory('${workspaceDir.path}/tool')..createSync(recursive: true);
  final Directory libDir = Directory('${workspaceDir.path}/lib')..createSync(recursive: true);
  final Directory testDir = Directory('${workspaceDir.path}/test')..createSync(recursive: true);
  testDir.createSync(recursive: true);

  final String guardScript = File('tool/analytics_raw_usage_guard.sh').readAsStringSync();
  final File scriptFile = File('${toolDir.path}/analytics_raw_usage_guard.sh')..writeAsStringSync(guardScript);

  File('${libDir.path}/placeholder.dart').writeAsStringSync('// placeholder\n');
  if (libFileContents != null) {
    File('${libDir.path}/violating_usage.dart').writeAsStringSync(libFileContents);
  }

  return Process.run('bash', <String>[scriptFile.path], workingDirectory: workspaceDir.path);
}

void main() {
  test('analytics guard fails on forbidden wrapper usage', () async {
    final Directory tempDir = await Directory.systemTemp.createTemp('analytics_guard_fail_');
    addTearDown(() async {
      if (await tempDir.exists()) {
        await tempDir.delete(recursive: true);
      }
    });

    final ProcessResult result = await _runGuard(
      workspaceDir: tempDir,
      libFileContents: '''
import 'package:Prism/analytics/analytics_service.dart';

Future<void> testUsage() async {
  await analytics.logShare(contentType: 'x', itemId: 'y', method: 'z');
}
''',
    );

    final String output = '${result.stdout}\n${result.stderr}';
    expect(result.exitCode, isNot(0));
    expect(output, contains('Forbidden analytics.logShare usage detected outside analytics internals'));
  });

  test('analytics guard fails on direct mixpanel client usage', () async {
    final Directory tempDir = await Directory.systemTemp.createTemp('analytics_guard_mixpanel_fail_');
    addTearDown(() async {
      if (await tempDir.exists()) {
        await tempDir.delete(recursive: true);
      }
    });

    final ProcessResult result = await _runGuard(
      workspaceDir: tempDir,
      libFileContents: '''
import 'package:mixpanel_flutter/mixpanel_flutter.dart';

void badUsage(Mixpanel mixpanel) {
  mixpanel.track('raw_event');
}
''',
    );

    final String output = '${result.stdout}\n${result.stderr}';
    expect(result.exitCode, isNot(0));
    expect(output, contains('Forbidden direct mixpanel_flutter import detected outside analytics internals'));
  });

  test('analytics guard passes with no forbidden usages', () async {
    final Directory tempDir = await Directory.systemTemp.createTemp('analytics_guard_pass_');
    addTearDown(() async {
      if (await tempDir.exists()) {
        await tempDir.delete(recursive: true);
      }
    });

    final ProcessResult result = await _runGuard(
      workspaceDir: tempDir,
      libFileContents: '''
Future<void> cleanUsage() async {
  return;
}
''',
    );

    expect(result.exitCode, 0);
    expect('${result.stdout}', contains('analytics_raw_usage_guard passed'));
  });
}
