import 'dart:io';

import 'package:Prism/core/offline/offline_asset_store.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

class AiDecodedImage extends StatefulWidget {
  const AiDecodedImage({
    super.key,
    required this.url,
    required this.logicalWidth,
    required this.logicalHeight,
    this.filterQuality = FilterQuality.medium,
  });

  final String url;
  final double logicalWidth;
  final double logicalHeight;
  final FilterQuality filterQuality;

  @override
  State<AiDecodedImage> createState() => _AiDecodedImageState();
}

class _AiDecodedImageState extends State<AiDecodedImage> {
  late Future<File?> _localFile = _lookup(widget.url);

  Future<File?> _lookup(String url) async {
    try {
      return await OfflineAssetStore.instance.lookup(url);
    } on Object {
      return null;
    }
  }

  @override
  void didUpdateWidget(covariant AiDecodedImage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.url != widget.url) _localFile = _lookup(widget.url);
  }

  @override
  Widget build(BuildContext context) {
    final ColorScheme cs = Theme.of(context).colorScheme;
    final double dpr = MediaQuery.devicePixelRatioOf(context);
    final int width = (widget.logicalWidth * dpr).round().clamp(32, 4096);
    final int height = (widget.logicalHeight * dpr).round().clamp(32, 4096);
    return FutureBuilder<File?>(
      future: _localFile,
      builder: (context, snapshot) {
        final File? file = snapshot.data;
        if (file != null) {
          return Image.file(
            file,
            fit: BoxFit.cover,
            cacheWidth: width,
            cacheHeight: height,
            filterQuality: widget.filterQuality,
            errorBuilder: (_, _, _) => _error(cs),
          );
        }
        return CachedNetworkImage(
          imageUrl: widget.url,
          fit: BoxFit.cover,
          memCacheWidth: width,
          memCacheHeight: height,
          filterQuality: widget.filterQuality,
          fadeInDuration: Duration.zero,
          fadeOutDuration: Duration.zero,
          errorWidget: (_, _, _) => _error(cs),
        );
      },
    );
  }

  Widget _error(ColorScheme scheme) => ColoredBox(
    color: scheme.surfaceContainerHighest,
    child: Center(child: Icon(Icons.broken_image_rounded, color: scheme.onSurface.withValues(alpha: 0.3))),
  );
}
