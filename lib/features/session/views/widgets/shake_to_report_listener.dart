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
typedef ScreenshotCapture = Future<Uint8List?> Function();

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
    this.captureScreenshot,
  });

  final GlobalKey<NavigatorState> navigatorKey;
  final Widget child;
  final AccelerometerStream accelerometer;
  @visibleForTesting
  final ScreenshotCapture? captureScreenshot;

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
    _stop();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) => _sync();

  bool get _shouldListen {
    final AppLifecycleState? lifecycle = WidgetsBinding.instance.lifecycleState;
    return ShakeToReport.enabled.value && (lifecycle == null || lifecycle == AppLifecycleState.resumed);
  }

  void _stop() {
    _detector.reset();
    unawaited(_subscription?.cancel());
    _subscription = null;
  }

  void _sync() {
    if (!_shouldListen) return _stop();
    if (_subscription != null) return;
    try {
      _subscription = widget.accelerometer().listen(
        (UserAccelerometerEvent e) {
          if (_detector.add(e.x, e.y, e.z, e.timestamp)) unawaited(_onShake());
        },
        onError: (Object error) {
          logger.w('Accelerometer stream failed; shake to report waits for the next resume or toggle.', error: error);
          _stop();
        },
        onDone: () => _subscription = null,
        cancelOnError: true,
      );
    } catch (error, stackTrace) {
      logger.w('Could not start the accelerometer stream.', error: error, stackTrace: stackTrace);
    }
  }

  Future<void> _onShake() async {
    if (_opening || openPrismSheetCount > 0) return;
    final BuildContext? navigatorContext = widget.navigatorKey.currentContext;
    if (navigatorContext == null) return;
    _opening = true;
    try {
      final Uint8List? screenshot = await (widget.captureScreenshot?.call() ?? _capture());
      // The capture takes a frame or two. The user may have backgrounded the app or opened a sheet meanwhile.
      if (!mounted || !_shouldListen || openPrismSheetCount > 0 || !navigatorContext.mounted) return;
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
      return await encodeAndDisposeScreenshotImage(image);
    } catch (error, stackTrace) {
      logger.w('Could not capture the screen for the report.', error: error, stackTrace: stackTrace);
      return null;
    }
  }

  @override
  Widget build(BuildContext context) => RepaintBoundary(key: _boundary, child: widget.child);
}

@visibleForTesting
Future<Uint8List?> encodeAndDisposeScreenshotImage(
  ui.Image image, {
  Future<ByteData?> Function(ui.Image image, ui.ImageByteFormat format)? encode,
}) async {
  try {
    final ByteData? data =
        await (encode ?? (ui.Image image, ui.ImageByteFormat format) => image.toByteData(format: format))(
          image,
          ui.ImageByteFormat.png,
        );
    return data?.buffer.asUint8List();
  } finally {
    image.dispose();
  }
}
