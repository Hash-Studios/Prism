import 'package:Prism/core/debug/creator_stats_emulator.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('bootstrap defaults to disabled', () {
    expect(CreatorStatsEmulator.enabled, isFalse);
  });
  test('accepts only demo project and local emulator endpoints', () {
    for (final host in ['127.0.0.1', 'localhost', '::1', '10.0.2.2']) {
      CreatorStatsEmulator.validate(project: 'demo-prism', host: host, account: 'empty');
    }
    for (final project in ['prism-wallpapers', '', 'demo-other']) {
      expect(
        () => CreatorStatsEmulator.validate(project: project, host: 'localhost', account: 'creator'),
        throwsArgumentError,
      );
    }
    for (final host in ['example.com', '192.168.1.1', 'localhost.example.com', 'https://localhost', '0.0.0.0']) {
      expect(
        () => CreatorStatsEmulator.validate(project: 'demo-prism', host: host, account: 'creator'),
        throwsArgumentError,
      );
    }
    expect(
      () => CreatorStatsEmulator.validate(project: 'demo-prism', host: 'localhost', account: 'real'),
      throwsArgumentError,
    );
  });
}
