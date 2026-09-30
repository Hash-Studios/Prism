import 'package:Prism/core/debug/debug_flags.dart';
import 'package:Prism/core/persistence/persistence_runtime.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/scheduler.dart' as scheduler;
import 'package:flutter_test/flutter_test.dart';

import '../../support/in_memory_local_store.dart';

void main() {
  late InMemoryLocalStore store;

  setUp(() {
    store = InMemoryLocalStore();
    PersistenceRuntime.store = store;
    DebugFlags.instance.reset();
  });

  tearDown(() {
    DebugFlags.instance.reset();
  });

  test('setting a flag persists it, notifies once and applies rendering globals', () {
    int notifications = 0;
    void listener() => notifications++;
    DebugFlags.instance.addListener(listener);
    addTearDown(() => DebugFlags.instance.removeListener(listener));

    DebugFlags.instance.paintSizeEnabled = true;
    DebugFlags.instance.paintSizeEnabled = true;

    expect(DebugFlags.instance.paintSizeEnabled, isTrue);
    expect(debugPaintSizeEnabled, isTrue);
    expect(store.data['debug.flags.paintSize'], true);
    expect(notifications, 1);
  });

  test('loadFromStore restores flags and animation speed', () {
    store.data['debug.flags.logToasts'] = 'true';
    store.data['debug.flags.repaintRainbow'] = true;
    store.data['debug.flags.timeDilation'] = 2;

    DebugFlags.instance.loadFromStore();

    expect(DebugFlags.instance.showLogToasts, isTrue);
    expect(DebugFlags.instance.repaintRainbow, isTrue);
    expect(debugRepaintRainbowEnabled, isTrue);
    expect(DebugFlags.instance.showPerformanceOverlay, isFalse);
    expect(DebugFlags.instance.animationSpeed, 2.0);
    expect(scheduler.timeDilation, 2.0);
  });

  test('reset clears every flag and the animation speed', () {
    DebugFlags.instance.simulateNoInternet = true;
    DebugFlags.instance.paintBaselines = true;
    DebugFlags.instance.animationSpeed = 5;

    DebugFlags.instance.reset();

    expect(DebugFlags.instance.simulateNoInternet, isFalse);
    expect(DebugFlags.instance.paintBaselines, isFalse);
    expect(debugPaintBaselinesEnabled, isFalse);
    expect(DebugFlags.instance.animationSpeed, 1.0);
  });
}
