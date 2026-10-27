import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:Prism/core/motion/prism_motion.dart';
import 'package:Prism/l10n/l10n.dart';
import 'package:Prism/logger/logger.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Phone pitch and roll in radians, from CoreMotion on iOS and the rotation-vector sensor on Android.
/// The stream errors with code `NO_SENSOR` when the phone has no such sensor.
Stream<Object?> phoneTilt() => const EventChannel('prism/tilt').receiveBroadcastStream();

enum SpatialTiltMode { sensor, drag }

/// Tilt in radians that moves the image by the full shift.
const double _maxTiltAngle = 0.35;

/// Largest shift as a share of the visible image.
const double _strength = 0.025;

/// Width the depth map is decoded at. The shader only needs a soft map.
const int _mapDecodeWidth = 128;

/// The wall drawn with a parallax from its depth map. The near parts move against the far parts as the phone tilts.
/// With reduce motion on, or with no tilt sensor, a drag tilts the image instead. [child] is drawn on top and still
/// gets taps.
class SpatialTiltView extends StatefulWidget {
  const SpatialTiltView({
    super.key,
    required this.image,
    required this.mapUrl,
    this.tint,
    this.child,
    this.onMode,
    this.tiltSource = phoneTilt,
    this.mapProvider,
  });

  final ImageProvider image;
  final String mapUrl;
  final Color? tint;
  final Widget? child;

  /// Called once when the view knows whether the sensor or a drag tilts the image.
  final ValueChanged<SpatialTiltMode>? onMode;
  final Stream<Object?> Function() tiltSource;

  /// Overrides the network depth map. For tests.
  final ImageProvider? mapProvider;

  @override
  State<SpatialTiltView> createState() => _SpatialTiltViewState();
}

class _SpatialTiltViewState extends State<SpatialTiltView> with SingleTickerProviderStateMixin {
  static Future<ui.FragmentProgram>? _program;

  final ValueNotifier<Offset> _tilt = ValueNotifier<Offset>(Offset.zero);
  late final AnimationController _settle = AnimationController(vsync: this)..addListener(_onSettle);
  late final AppLifecycleListener _lifecycle;
  Offset _settleFrom = Offset.zero;
  ui.FragmentShader? _shader;
  ui.Image? _image;
  ui.Image? _map;
  final List<ImageStream> _streams = <ImageStream>[];
  final List<ImageStreamListener> _listeners = <ImageStreamListener>[];
  StreamSubscription<Object?>? _sensor;
  Offset? _baseline;
  bool _noSensor = false;
  bool _reduceMotion = false;
  bool _foreground = true;
  SpatialTiltMode? _reportedMode;

  SpatialTiltMode get _mode => _reduceMotion || _noSensor ? SpatialTiltMode.drag : SpatialTiltMode.sensor;

  @override
  void initState() {
    super.initState();
    _lifecycle = AppLifecycleListener(onStateChange: _onLifecycle);
    unawaited(_loadShader());
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _reduceMotion = context.reduceMotion;
    final ImageConfiguration config = createLocalImageConfiguration(context);
    if (_streams.isEmpty) {
      final double width = MediaQuery.sizeOf(context).width * MediaQuery.devicePixelRatioOf(context);
      _resolve(ResizeImage(widget.image, width: width.round(), policy: ResizeImagePolicy.fit), config, (img) {
        _image = img;
      });
      _resolve(
        widget.mapProvider ?? ResizeImage(NetworkImage(widget.mapUrl), width: _mapDecodeWidth),
        config,
        (img) => _map = img,
      );
    }
    _syncSensor();
  }

  Future<void> _loadShader() async {
    try {
      final ui.FragmentProgram program = await (_program ??= ui.FragmentProgram.fromAsset('shaders/spatial_tilt.frag'));
      if (mounted) setState(() => _shader = program.fragmentShader());
    } catch (error, stackTrace) {
      _program = null;
      logger.w('spatial_tilt shader unavailable', error: error, stackTrace: stackTrace);
    }
  }

  void _resolve(ImageProvider provider, ImageConfiguration config, void Function(ui.Image) onImage) {
    final ImageStream stream = provider.resolve(config);
    final ImageStreamListener listener = ImageStreamListener((info, _) {
      if (!mounted) return info.dispose();
      setState(() => onImage(info.image.clone()));
      info.dispose();
    }, onError: (error, stackTrace) => logger.w('SpatialTiltView: image failed', error: error, stackTrace: stackTrace));
    stream.addListener(listener);
    _streams.add(stream);
    _listeners.add(listener);
  }

  void _onLifecycle(AppLifecycleState state) {
    _foreground = state == AppLifecycleState.resumed;
    _syncSensor();
  }

  /// Listens to the sensor only while it drives the tilt and the app is in front.
  void _syncSensor() {
    final bool listen = _mode == SpatialTiltMode.sensor && _foreground;
    if (listen && _sensor == null) {
      _baseline = null;
      _sensor = widget.tiltSource().listen(_onSensor, onError: _onSensorError);
    } else if (!listen && _sensor != null) {
      unawaited(_sensor!.cancel());
      _sensor = null;
    }
    if (_mode == SpatialTiltMode.drag || _noSensor) _report(SpatialTiltMode.drag);
  }

  void _report(SpatialTiltMode mode) {
    if (_reportedMode != null) return;
    _reportedMode = mode;
    widget.onMode?.call(mode);
  }

  void _onSensor(Object? event) {
    if (event is! List || event.length < 2) return;
    final Offset angles = Offset((event[1] as num).toDouble(), (event[0] as num).toDouble());
    final Offset base = _baseline ??= angles;
    double wrap(double a) => math.atan2(math.sin(a), math.cos(a));
    final Offset delta = Offset(wrap(angles.dx - base.dx), wrap(angles.dy - base.dy));
    // The rest pose drifts toward how the user holds the phone now.
    _baseline = base + delta * 0.01;
    final Offset target = Offset(
      (delta.dx / _maxTiltAngle).clamp(-1.0, 1.0),
      (delta.dy / _maxTiltAngle).clamp(-1.0, 1.0),
    );
    _tilt.value += (target - _tilt.value) * 0.25;
    _report(SpatialTiltMode.sensor);
  }

  void _onSensorError(Object error) {
    logger.i('SpatialTiltView: no tilt sensor, using drag', error: error);
    unawaited(_sensor?.cancel());
    _sensor = null;
    if (mounted) setState(() => _noSensor = true);
    _report(SpatialTiltMode.drag);
  }

  void _onDrag(DragUpdateDetails details, Size size) {
    _settle.stop();
    final Offset next = _tilt.value + Offset(details.delta.dx / (size.width / 2), details.delta.dy / (size.height / 4));
    _tilt.value = Offset(next.dx.clamp(-1.0, 1.0), next.dy.clamp(-1.0, 1.0));
  }

  void _onDragEnd(DragEndDetails _) {
    _settleFrom = _tilt.value;
    _settle.duration = context.motion(PrismDurations.slow);
    if (_settle.duration == Duration.zero) {
      _tilt.value = Offset.zero;
      return;
    }
    unawaited(_settle.forward(from: 0));
  }

  void _onSettle() => _tilt.value = Offset.lerp(_settleFrom, Offset.zero, PrismCurves.enter.transform(_settle.value))!;

  @override
  void dispose() {
    unawaited(_sensor?.cancel());
    _sensor = null;
    _lifecycle.dispose();
    _settle.dispose();
    for (int i = 0; i < _streams.length; i++) {
      _streams[i].removeListener(_listeners[i]);
    }
    _image?.dispose();
    _map?.dispose();
    _shader?.dispose();
    _tilt.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ui.FragmentShader? shader = _shader;
    final ui.Image? image = _image;
    final ui.Image? map = _map;
    Widget picture = shader == null || image == null || map == null
        ? Image(image: widget.image, fit: BoxFit.cover)
        : CustomPaint(painter: _SpatialPainter(shader, image, map, _tilt));
    if (widget.tint != null) {
      picture = ColorFiltered(colorFilter: ColorFilter.mode(widget.tint!, BlendMode.hue), child: picture);
    }
    final bool drag = _mode == SpatialTiltMode.drag;
    return LayoutBuilder(
      builder: (context, constraints) {
        final Size size = constraints.biggest;
        return GestureDetector(
          onPanUpdate: drag ? (details) => _onDrag(details, size) : null,
          onPanEnd: drag ? _onDragEnd : null,
          child: Stack(
            fit: StackFit.expand,
            children: <Widget>[
              SizedBox.expand(child: picture),
              ?widget.child,
              if (drag)
                Align(
                  alignment: const Alignment(0, 0.55),
                  child: IgnorePointer(child: _DragHint(label: context.l10n.wallpaperSpatialDragHint)),
                ),
            ],
          ),
        );
      },
    );
  }
}

class _DragHint extends StatelessWidget {
  const _DragHint({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    return DecoratedBox(
      decoration: BoxDecoration(color: scheme.scrim.withValues(alpha: 0.5), borderRadius: BorderRadius.circular(999)),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            const Icon(Icons.swipe_rounded, size: 18, color: Colors.white),
            const SizedBox(width: 8),
            Text(label, style: Theme.of(context).textTheme.labelLarge?.copyWith(color: Colors.white)),
          ],
        ),
      ),
    );
  }
}

class _SpatialPainter extends CustomPainter {
  _SpatialPainter(this.shader, this.image, this.map, this.tilt) : super(repaint: tilt);

  final ui.FragmentShader shader;
  final ui.Image image;
  final ui.Image map;
  final ValueNotifier<Offset> tilt;

  @override
  void paint(Canvas canvas, Size size) {
    shader
      ..setFloat(0, size.width)
      ..setFloat(1, size.height)
      ..setFloat(2, image.width.toDouble())
      ..setFloat(3, image.height.toDouble())
      ..setFloat(4, tilt.value.dx)
      ..setFloat(5, tilt.value.dy)
      ..setFloat(6, _strength)
      ..setImageSampler(0, image, filterQuality: FilterQuality.low)
      ..setImageSampler(1, map, filterQuality: FilterQuality.low);
    canvas.drawRect(Offset.zero & size, Paint()..shader = shader);
  }

  @override
  bool shouldRepaint(_SpatialPainter old) => old.shader != shader || old.image != image || old.map != map;
}
