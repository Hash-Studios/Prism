import 'dart:async';
import 'dart:math';
import 'dart:ui' as ui;

import 'package:Prism/core/widgets/prism_sheet.dart';
import 'package:Prism/features/session/data/report_problem_service.dart';
import 'package:Prism/features/session/data/shake_to_report.dart';
import 'package:Prism/features/session/views/widgets/report_problem_sheet.dart';
import 'package:Prism/logger/logger.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';
import 'package:sensors_plus/sensors_plus.dart';

typedef AccelerometerStream = Stream<UserAccelerometerEvent> Function();

Stream<UserAccelerometerEvent> _deviceAccelerometer() =>
    userAccelerometerEventStream(samplingPeriod: SensorInterval.gameInterval);

/// Opens the report sheet with a screenshot of the app when the user shakes the phone. It listens only while the
/// setting is on and the app is in the foreground, and ignores shakes while any Prism sheet is open.
class ShakeToReportListener extends StatefulWidget {
  const ShakeToReportListener({
    super.key,
    required this.navigatorKey,
    required this.child,
    this.accelerometer = _deviceAccelerometer,
  });

  final GlobalKey<NavigatorState> navigatorKey;
  final Widget child;
  final AccelerometerStream accelerometer;

  @override
  State<ShakeToReportListener> createState() => _ShakeToReportListenerState();
}

class _ShakeToReportListenerState extends State<ShakeToReportListener> with WidgetsBindingObserver {
  final GlobalKey _boundary = GlobalKey();
  final ShakeDetector _detector = ShakeDetector();
  StreamSubscription<UserAccelerometerEvent>? _subscription;
  bool _opening = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    ShakeToReport.enabled.addListener(_sync);
    _sync();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    ShakeToReport.enabled.removeListener(_sync);
    unawaited(_subscription?.cancel());
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) => _sync();

  void _sync() {
    final AppLifecycleState? lifecycle = WidgetsBinding.instance.lifecycleState;
    final bool listen = ShakeToReport.enabled.value && (lifecycle == null || lifecycle == AppLifecycleState.resumed);
    if (listen == (_subscription != null)) return;
    if (!listen) {
      unawaited(_subscription?.cancel());
      _subscription = null;
      return;
    }
    _subscription = widget.accelerometer().listen(
      (UserAccelerometerEvent e) {
        if (_detector.add(e.x, e.y, e.z, e.timestamp)) unawaited(_onShake());
      },
      onError: (Object error) {
        logger.w('Accelerometer stream failed; shake to report is off for this session.', error: error);
        _subscription = null;
      },
      cancelOnError: true,
    );
  }

  Future<void> _onShake() async {
    if (_opening || openPrismSheetCount > 0) return;
    final BuildContext? navigatorContext = widget.navigatorKey.currentContext;
    if (navigatorContext == null) return;
    _opening = true;
    try {
      final Uint8List? screenshot = await _capture();
      if (!navigatorContext.mounted) return;
      await showReportProblemSheet(
        navigatorContext,
        source: 'shake',
        trigger: ReportTrigger.shake,
        screenshot: screenshot,
      );
    } finally {
      _opening = false;
    }
  }

  Future<Uint8List?> _capture() async {
    try {
      final RenderObject? render = _boundary.currentContext?.findRenderObject();
      if (render is! RenderRepaintBoundary) return null;
      final double ratio = min(View.of(context).devicePixelRatio, 2);
      final ui.Image image = await render.toImage(pixelRatio: ratio);
      final ByteData? data = await image.toByteData(format: ui.ImageByteFormat.png);
      image.dispose();
      return data?.buffer.asUint8List();
    } catch (error, stackTrace) {
      logger.w('Could not capture the screen for the report.', error: error, stackTrace: stackTrace);
      return null;
    }
  }

  @override
  Widget build(BuildContext context) => RepaintBoundary(key: _boundary, child: widget.child);
}
