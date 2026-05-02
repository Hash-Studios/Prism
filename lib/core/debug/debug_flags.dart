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

  // ── Rendering (debug/profile builds only) ────────────────────────────────

  bool _paintSizeEnabled = false;
  bool get paintSizeEnabled => _paintSizeEnabled;
  set paintSizeEnabled(bool v) {
    if (_paintSizeEnabled == v) return;
    _paintSizeEnabled = v;
    debugPaintSizeEnabled = v;
    _persist('paintSize', v);
    notifyListeners();
  }

  bool _repaintRainbow = false;
  bool get repaintRainbow => _repaintRainbow;
  set repaintRainbow(bool v) {
    if (_repaintRainbow == v) return;
    _repaintRainbow = v;
    debugRepaintRainbowEnabled = v;
    _persist('repaintRainbow', v);
    notifyListeners();
  }

  bool _paintBaselines = false;
  bool get paintBaselines => _paintBaselines;
  set paintBaselines(bool v) {
    if (_paintBaselines == v) return;
    _paintBaselines = v;
    debugPaintBaselinesEnabled = v;
    _persist('paintBaselines', v);
    notifyListeners();
  }

  // ── Animation speed ──────────────────────────────────────────────────────

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

  // ── MaterialApp overlays ─────────────────────────────────────────────────

  bool _showPerformanceOverlay = false;
  bool get showPerformanceOverlay => _showPerformanceOverlay;
  set showPerformanceOverlay(bool v) {
    if (_showPerformanceOverlay == v) return;
    _showPerformanceOverlay = v;
    _persist('performanceOverlay', v);
    notifyListeners();
  }

  bool _showSemanticsDebugger = false;
  bool get showSemanticsDebugger => _showSemanticsDebugger;
  set showSemanticsDebugger(bool v) {
    if (_showSemanticsDebugger == v) return;
    _showSemanticsDebugger = v;
    _persist('semanticsDebugger', v);
    notifyListeners();
  }

  // ── UX helpers ───────────────────────────────────────────────────────────

  bool _showLogToasts = false;
  bool get showLogToasts => _showLogToasts;
  set showLogToasts(bool v) {
    if (_showLogToasts == v) return;
    _showLogToasts = v;
    _persist('logToasts', v);
    notifyListeners();
  }

  bool _simulateNoInternet = false;
  bool get simulateNoInternet => _simulateNoInternet;
  set simulateNoInternet(bool v) {
    if (_simulateNoInternet == v) return;
    _simulateNoInternet = v;
    _persist('simulateNoInternet', v);
    notifyListeners();
  }

  // ── Init ─────────────────────────────────────────────────────────────────

  /// Load persisted flag values. Call after PersistenceBootstrap.initialize().
  void loadFromStore() {
    if (!PersistenceRuntime.isInitialized) return;
    final store = PersistenceRuntime.store;

    _paintSizeEnabled = _readBool(store, 'paintSize');
    _repaintRainbow = _readBool(store, 'repaintRainbow');
    _paintBaselines = _readBool(store, 'paintBaselines');
    _showPerformanceOverlay = _readBool(store, 'performanceOverlay');
    _showSemanticsDebugger = _readBool(store, 'semanticsDebugger');
    _showLogToasts = _readBool(store, 'logToasts');
    _simulateNoInternet = _readBool(store, 'simulateNoInternet');

    final rawDilation = store.get('${_kPrefix}timeDilation');
    if (rawDilation is double) {
      _animationSpeed = rawDilation.clamp(0.1, 10.0);
    } else if (rawDilation is num) {
      _animationSpeed = rawDilation.toDouble().clamp(0.1, 10.0);
    } else if (rawDilation is String) {
      _animationSpeed = (double.tryParse(rawDilation) ?? 1.0).clamp(0.1, 10.0);
    }

    // Apply loaded values to global Flutter debug variables immediately.
    debugPaintSizeEnabled = _paintSizeEnabled;
    debugRepaintRainbowEnabled = _repaintRainbow;
    debugPaintBaselinesEnabled = _paintBaselines;
    scheduler.timeDilation = _animationSpeed;
  }

  void reset() {
    paintSizeEnabled = false;
    repaintRainbow = false;
    paintBaselines = false;
    animationSpeed = 1.0;
    showPerformanceOverlay = false;
    showSemanticsDebugger = false;
    showLogToasts = false;
    simulateNoInternet = false;
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
