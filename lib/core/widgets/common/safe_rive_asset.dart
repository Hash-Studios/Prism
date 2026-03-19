import 'package:Prism/logger/logger.dart';
import 'package:flutter/material.dart';
import 'package:rive/rive.dart' as rive;

class SafeRiveAsset extends StatefulWidget {
  const SafeRiveAsset({
    super.key,
    required this.assetName,
    required this.animations,
    this.fit = BoxFit.contain,
    this.fallback,
  });

  final String assetName;
  final List<String> animations;
  final BoxFit fit;
  final Widget? fallback;

  @override
  State<SafeRiveAsset> createState() => _SafeRiveAssetState();
}

class _SafeRiveAssetState extends State<SafeRiveAsset> {
  rive.File? _file;
  Object? _error;
  StackTrace? _stackTrace;
  List<String> _attemptedAssets = const <String>[];

  @override
  void initState() {
    super.initState();
    _loadFile();
  }

  @override
  void didUpdateWidget(covariant SafeRiveAsset oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.assetName != widget.assetName) {
      _disposeFile();
      _loadFile();
    }
  }

  Future<void> _loadFile() async {
    final attemptedAssets = <String>[
      widget.assetName,
      if (widget.assetName.endsWith('.riv')) '${widget.assetName.substring(0, widget.assetName.length - 4)}.flr',
    ];

    Object? lastError;
    StackTrace? lastStackTrace;

    for (final assetPath in attemptedAssets.toSet()) {
      try {
        final file = await rive.File.asset(assetPath, riveFactory: rive.Factory.rive);

        if (!mounted) {
          file?.dispose();
          return;
        }

        if (file == null) {
          throw Exception('Failed to decode Rive file.');
        }

        setState(() {
          _file = file;
          _error = null;
          _stackTrace = null;
          _attemptedAssets = attemptedAssets;
        });
        return;
      } catch (error, stackTrace) {
        lastError = error;
        lastStackTrace = stackTrace;
      }
    }

    try {
      throw lastError ?? Exception('Failed to load Rive asset.');
    } catch (error, stackTrace) {
      if (!mounted) {
        return;
      }
      setState(() {
        _file = null;
        _error = error;
        _stackTrace = lastStackTrace ?? stackTrace;
        _attemptedAssets = attemptedAssets;
      });
    }
  }

  void _disposeFile() {
    _file?.dispose();
    _file = null;
  }

  @override
  void dispose() {
    _disposeFile();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final error = _error;
    if (error != null) {
      logger.w(
        'Failed to load Rive asset.',
        tag: 'Rive',
        error: error,
        stackTrace: _stackTrace,
        fields: <String, Object?>{'asset': widget.assetName, 'attempted_assets': _attemptedAssets.join(', ')},
      );
      return widget.fallback ?? const SizedBox.shrink();
    }

    final file = _file;
    if (file == null) {
      return widget.fallback ?? const SizedBox.shrink();
    }

    return rive.RiveFileWidget(
      file: file,
      painter: _MultiAnimationPainter(widget.animations, fit: _toRiveFit(widget.fit)),
    );
  }
}

base class _MultiAnimationPainter extends rive.BasicArtboardPainter {
  _MultiAnimationPainter(this.animationNames, {required super.fit});

  final List<String> animationNames;
  List<rive.Animation> _animations = const <rive.Animation>[];

  @override
  void artboardChanged(rive.Artboard artboard) {
    super.artboardChanged(artboard);
    _animations = animationNames.map(artboard.animationNamed).whereType<rive.Animation>().toList();
  }

  @override
  bool advance(double elapsedSeconds) {
    var advanced = false;
    for (final animation in _animations) {
      advanced = animation.advanceAndApply(elapsedSeconds) || advanced;
    }
    return advanced || super.advance(elapsedSeconds);
  }
}

rive.Fit _toRiveFit(BoxFit fit) {
  switch (fit) {
    case BoxFit.fill:
      return rive.Fit.fill;
    case BoxFit.contain:
      return rive.Fit.contain;
    case BoxFit.cover:
      return rive.Fit.cover;
    case BoxFit.fitWidth:
      return rive.Fit.fitWidth;
    case BoxFit.fitHeight:
      return rive.Fit.fitHeight;
    case BoxFit.none:
      return rive.Fit.none;
    case BoxFit.scaleDown:
      return rive.Fit.scaleDown;
  }
}
