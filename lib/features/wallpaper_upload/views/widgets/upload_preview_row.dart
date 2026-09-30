import 'dart:io';

import 'package:Prism/core/widgets/prism/prism_skeleton.dart';
import 'package:Prism/theme/app_tokens.dart';
import 'package:flutter/material.dart';

/// The picked image in a phone-shaped frame, with its resolution and size next to it.
class UploadPreviewRow extends StatelessWidget {
  const UploadPreviewRow({
    super.key,
    required this.image,
    required this.resolution,
    required this.size,
    this.loading = false,
  });

  final File image;

  /// "1080x2160", or null while the image is still being read.
  final String? resolution;

  /// "0.25MB", or null while the image is still being read.
  final String? size;

  /// Shows placeholders for the facts while the image is being read.
  final bool loading;

  static const double _previewWidth = 120;

  @override
  Widget build(BuildContext context) {
    final ColorScheme cs = Theme.of(context).colorScheme;
    final BorderRadius radius = BorderRadius.circular(PrismRadius.md);
    final double dpr = MediaQuery.devicePixelRatioOf(context);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        SizedBox(
          width: _previewWidth,
          child: AspectRatio(
            aspectRatio: 1 / 2,
            child: DecoratedBox(
              position: DecorationPosition.foreground,
              decoration: BoxDecoration(
                borderRadius: radius,
                border: Border.all(color: cs.onSurface.withValues(alpha: 0.08)),
              ),
              child: ClipRRect(
                borderRadius: radius,
                child: Image.file(
                  image,
                  fit: BoxFit.cover,
                  cacheWidth: (_previewWidth * dpr).round(),
                  errorBuilder: (_, _, _) => ColoredBox(
                    color: cs.surfaceContainerHighest,
                    child: Center(child: Icon(Icons.broken_image_rounded, color: cs.onSurface.withValues(alpha: 0.3))),
                  ),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(width: PrismSpace.lg),
        Expanded(
          child: resolution == null
              ? (loading ? const _FactsSkeleton() : const SizedBox.shrink())
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    _Fact(label: 'Resolution', value: formatResolution(resolution!)),
                    if (size != null) ...<Widget>[
                      const SizedBox(height: PrismSpace.md),
                      _Fact(label: 'Size', value: formatFileSize(size!)),
                    ],
                  ],
                ),
        ),
      ],
    );
  }
}

/// "1080x2160" becomes "1080 x 2160". Anything else is shown as is.
String formatResolution(String value) => value.replaceFirstMapped(RegExp(r'^(\d+)x(\d+)$'), (m) => '${m[1]} x ${m[2]}');

/// "0.25MB" becomes "0.25 MB". Anything else is shown as is.
String formatFileSize(String value) =>
    value.replaceFirstMapped(RegExp(r'^([\d.]+)\s*([KMG]B)$'), (m) => '${m[1]} ${m[2]}');

class _Fact extends StatelessWidget {
  const _Fact({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(label, style: PrismTextStyles.caption(context)),
        const SizedBox(height: PrismSpace.xxs),
        Text(value, style: PrismTextStyles.cardTitle(context)),
      ],
    );
  }
}

class _FactsSkeleton extends StatelessWidget {
  const _FactsSkeleton();

  @override
  Widget build(BuildContext context) {
    return const PrismSkeleton(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          PrismBone(width: 64, height: 11),
          SizedBox(height: PrismSpace.xs),
          PrismBone(width: 120, height: 16),
          SizedBox(height: PrismSpace.md),
          PrismBone(width: 40, height: 11),
          SizedBox(height: PrismSpace.xs),
          PrismBone(width: 80, height: 16),
        ],
      ),
    );
  }
}
