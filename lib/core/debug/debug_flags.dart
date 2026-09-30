import 'package:Prism/core/persistence/local_store.dart';
import 'package:Prism/core/persistence/persistence_runtime.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/scheduler.dart' as scheduler;

/// Key prefix for all debug flag persistence entries.
const String _kPrefix = 'debug.flags.';

/// Singleton [ChangeNotifier] that owns all in-app debug toggles.
/// Changes to rendering flags are applied immediately as global variables.
/// All flags are persisted to [LocalStore] so they survive hot restarts.
class DebugFlags extends ChangeNotifier {
  DebugFlags._();

  static final DebugFlags instance = DebugFlags._();

  static const List<String> _boolKeys = <String>[
    'paintSize',
    'repaintRainbow',
    'paintBaselines',
    'performanceOverlay',
    'semanticsDebugger',
    'logToasts',
    'simulateNoInternet',
  ];

  final Map<String, bool> _flags = <String, bool>{};

  bool _flag(String key) => _flags[key] ?? false;

  void _setFlag(String key, bool v) {
    if (_flag(key) == v) return;
    _flags[key] = v;
    _applyRendering();
    _persist(key, v);
    notifyListeners();
  }

  /// Rendering flags only take effect in debug/profile builds.
  void _applyRendering() {
    debugPaintSizeEnabled = _flag('paintSize');
    debugRepaintRainbowEnabled = _flag('repaintRainbow');
    debugPaintBaselinesEnabled = _flag('paintBaselines');
  }

  bool get paintSizeEnabled => _flag('paintSize');
  set paintSizeEnabled(bool v) => _setFlag('paintSize', v);

  bool get repaintRainbow => _flag('repaintRainbow');
  set repaintRainbow(bool v) => _setFlag('repaintRainbow', v);

  bool get paintBaselines => _flag('paintBaselines');
  set paintBaselines(bool v) => _setFlag('paintBaselines', v);

  bool get showPerformanceOverlay => _flag('performanceOverlay');
  set showPerformanceOverlay(bool v) => _setFlag('performanceOverlay', v);

  bool get showSemanticsDebugger => _flag('semanticsDebugger');
  set showSemanticsDebugger(bool v) => _setFlag('semanticsDebugger', v);

  bool get showLogToasts => _flag('logToasts');
  set showLogToasts(bool v) => _setFlag('logToasts', v);

  bool get simulateNoInternet => _flag('simulateNoInternet');
  set simulateNoInternet(bool v) => _setFlag('simulateNoInternet', v);

  double _animationSpeed = 1.0;
  double get animationSpeed => _animationSpeed;
  set animationSpeed(double v) {
    final double clamped = v.clamp(0.1, 10.0);
    if (_animationSpeed == clamped) return;
    _animationSpeed = clamped;
    scheduler.timeDilation = clamped;
    _persist('timeDilation', clamped);
    notifyListeners();
  }

  // ── Init ─────────────────────────────────────────────────────────────────

  /// Load persisted flag values. Call after PersistenceBootstrap.initialize().
  void loadFromStore() {
    if (!PersistenceRuntime.isInitialized) return;
    final store = PersistenceRuntime.store;

    for (final String key in _boolKeys) {
      _flags[key] = _readBool(store, key);
    }

    final rawDilation = store.get('${_kPrefix}timeDilation');
    if (rawDilation is double) {
      _animationSpeed = rawDilation.clamp(0.1, 10.0);
    } else if (rawDilation is num) {
      _animationSpeed = rawDilation.toDouble().clamp(0.1, 10.0);
    } else if (rawDilation is String) {
      _animationSpeed = (double.tryParse(rawDilation) ?? 1.0).clamp(0.1, 10.0);
    }

    // Apply loaded values to global Flutter debug variables immediately.
    _applyRendering();
    scheduler.timeDilation = _animationSpeed;
  }

  void reset() {
    for (final String key in _boolKeys) {
      _setFlag(key, false);
    }
    animationSpeed = 1.0;
  }

  // ── Helpers ───────────────────────────────────────────────────────────────

  bool _readBool(LocalStore store, String key) {
    final raw = store.get('$_kPrefix$key');
    if (raw is bool) return raw;
    if (raw is String) return raw == 'true';
    return false;
  }

  void _persist(String key, Object? value) {
    if (!PersistenceRuntime.isInitialized) return;
    PersistenceRuntime.store.set('$_kPrefix$key', value);
  }
}
