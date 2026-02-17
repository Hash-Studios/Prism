import 'package:Prism/logger/logger.dart';
import 'package:flutter/material.dart';
import 'package:rive/rive.dart';

class SafeRiveAsset extends StatelessWidget {
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
  Widget build(BuildContext context) {
    return FutureBuilder<RiveFile>(
      future: RiveFile.asset(assetName),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          logger.w(
            'Failed to load Rive asset.',
            tag: 'Rive',
            error: snapshot.error,
            stackTrace: snapshot.stackTrace,
            fields: <String, Object?>{
              'asset': assetName,
            },
          );
          return fallback ?? const SizedBox.shrink();
        }
        final RiveFile? file = snapshot.data;
        if (file == null) {
          return fallback ?? const SizedBox.shrink();
        }
        return RiveAnimation.direct(
          file,
          fit: fit,
          animations: animations,
        );
      },
    );
  }
}
