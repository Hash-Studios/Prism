import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

// Source contracts only. Flutter tests cannot compile or run the native sensor handlers.
void main() {
  final String android = File('android/app/src/main/kotlin/com/hash/prism/PrismTiltStream.kt').readAsStringSync();
  final String ios = File('ios/Runner/PrismTiltStream.swift').readAsStringSync();

  test('Android source contract: replacement listen clears the old sink before checking availability', () {
    final String listen = _body(android, 'override fun onListen(');

    _expectOrder(listen, <String>['onCancel(null)', 'getDefaultSensor(', 'sink = events', 'registerListener(']);
    final String unavailable = _body(listen, 'if (sensor == null)');
    _expectOrder(unavailable, <String>['events.error("NO_SENSOR"', 'return']);
  });

  test('Android source contract: failed registration clears the sink and emits a stream error', () {
    final String listen = _body(android, 'override fun onListen(');
    final String failure = _body(
      listen,
      'if (sensors?.registerListener(this, sensor, SensorManager.SENSOR_DELAY_GAME) != true)',
    );

    _expectOrder(failure, <String>['onCancel(null)', 'events.error("SENSOR_FAILED"']);
    final String cancel = _body(android, 'override fun onCancel(');
    _expectOrder(cancel, <String>['sink = null', 'unregisterListener(this)']);
  });

  test('Android source contract: engine cleanup cancels before detaching the channel', () {
    final String activity = File('android/app/src/main/kotlin/com/hash/prism/MainActivity.kt').readAsStringSync();
    final String cleanup = _body(activity, 'override fun cleanUpFlutterEngine(');

    _expectOrder(cleanup, <String>[
      'tiltStream?.onCancel(null)',
      'tiltStream = null',
      'tiltChannel?.setStreamHandler(null)',
      'tiltChannel = null',
    ]);
  });

  test('iOS source contract: unavailable sensor emits an event error instead of a failed listen reply', () {
    final String listen = _body(ios, 'func onListen(');
    final String unavailable = _body(listen, 'guard motion.isDeviceMotionAvailable else');

    _expectOrder(listen, <String>['onCancel(withArguments: nil)', 'guard motion.isDeviceMotionAvailable']);
    _expectOrder(unavailable, <String>['events(FlutterError(code: "NO_SENSOR"', 'return nil']);
    expect(unavailable, isNot(contains('return FlutterError')));
  });

  test('iOS source contract: cancelled and replaced callbacks are gated before delivery', () {
    final String listen = _body(ios, 'func onListen(');
    final String callback = _body(listen, 'motion.startDeviceMotionUpdates(to: .main)');

    _expectOrder(listen, <String>['let generation = self.generation', 'motion.startDeviceMotionUpdates(']);
    _expectOrder(callback, <String>[
      'guard let self, generation == self.generation else { return }',
      'if let error',
      'events([attitude.pitch, attitude.roll])',
    ]);
    final String cancel = _body(ios, 'func onCancel(');
    _expectOrder(cancel, <String>['generation += 1', 'motion.stopDeviceMotionUpdates()', 'return nil']);
  });

  test('iOS source contract: CoreMotion errors stop updates before reporting sensor failure', () {
    final String listen = _body(ios, 'func onListen(');
    final String callback = _body(listen, 'motion.startDeviceMotionUpdates(to: .main)');
    final String failure = _body(callback, 'if let error');

    _expectOrder(failure, <String>[
      'onCancel(withArguments: nil)',
      'events(FlutterError(code: "SENSOR_FAILED"',
      'return',
    ]);
  });
}

String _body(String source, String declaration) {
  final int declarationStart = source.indexOf(declaration);
  expect(declarationStart, isNonNegative, reason: 'Missing declaration: $declaration');
  final int start = source.indexOf('{', declarationStart);
  expect(start, isNonNegative, reason: 'Missing body: $declaration');
  int depth = 1;
  for (int i = start + 1; i < source.length; i++) {
    if (source[i] == '{') depth++;
    if (source[i] == '}') depth--;
    if (depth == 0) return source.substring(start + 1, i);
  }
  fail('Unclosed body: $declaration');
}

void _expectOrder(String source, List<String> fragments) {
  int previous = -1;
  for (final String fragment in fragments) {
    final int next = source.indexOf(fragment);
    expect(next, greaterThan(previous), reason: 'Expected in path order: ${fragments.join(' -> ')}');
    previous = next;
  }
}
