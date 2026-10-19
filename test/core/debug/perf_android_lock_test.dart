import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('an existing perf harness lock stops before any adb command and remains owned', () async {
    final Directory fixture = Directory.systemTemp.createTempSync('prism_perf_lock_test');
    addTearDown(() => fixture.deleteSync(recursive: true));
    final File lock = File('${fixture.path}/device.lock')..writeAsStringSync('perf-harness another-run');
    final File calls = File('${fixture.path}/adb-calls');
    final File adb = File('${fixture.path}/adb')
      ..writeAsStringSync('#!/bin/sh\nprintf called >> "\$PRISM_PERF_TEST_CALLS"\nexit 17\n');
    final File sysctl = File('${fixture.path}/sysctl')..writeAsStringSync('#!/bin/sh\nprintf "{ 0 0 0 }\\n"\n');
    expect((await Process.run('chmod', <String>['+x', adb.path, sysctl.path])).exitCode, 0);

    final ProcessResult result = await Process.run(
      'bash',
      <String>['tool/perf/run_android.sh', 'lock-test', '${fixture.path}/never-install.apk', '1'],
      environment: <String, String>{
        'PATH': '${fixture.path}:${Platform.environment['PATH']}',
        'PRISM_PERF_LOCK': lock.path,
        'PRISM_PERF_DIR': fixture.path,
        'PRISM_PERF_TEST_CALLS': calls.path,
        'PRISM_PERF_MAX_LOAD': '100',
        'PRISM_PERF_REBOOT': '0',
      },
    );

    expect(calls.existsSync(), isFalse, reason: 'the locked device must not be installed or driven');
    expect(result.exitCode, isNot(0));
    expect(result.stdout, contains('Device lock held:'));
    expect(lock.readAsStringSync(), 'perf-harness another-run');
  });
}
