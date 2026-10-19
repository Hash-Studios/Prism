import 'dart:io';

import 'package:Prism/core/widgets/prism/prism_button.dart';
import 'package:Prism/theme/app_tokens.dart';
import 'package:auto_route/auto_route.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:photo_view/photo_view.dart';

/// Opens the full wallpaper over the current page. Pinch to zoom. The close button is in the top corner.
Future<void> showReviewPhotoPreview(BuildContext context, {required String url, required String thumbUrl}) {
  return Navigator.of(context).push<void>(
    MaterialPageRoute<void>(
      fullscreenDialog: true,
      builder: (_) => ReviewPhotoPreview(url: url, thumbUrl: thumbUrl),
    ),
  );
}

@RoutePage(name: 'ReviewPhotoPreviewRoute')
class ReviewPhotoPreview extends StatelessWidget {
  const ReviewPhotoPreview({super.key, required this.url, required this.thumbUrl, this.file = false});

  final String url;
  final String thumbUrl;
  final bool file;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: <Widget>[
          PhotoView(
            backgroundDecoration: const BoxDecoration(color: Colors.black),
            imageProvider: file ? FileImage(File(url)) : CachedNetworkImageProvider(url) as ImageProvider,
            minScale: PhotoViewComputedScale.contained,
            maxScale: PhotoViewComputedScale.covered * 3,
            loadingBuilder: (context, event) => Center(
              child: file
                  ? Image.file(File(thumbUrl), fit: BoxFit.contain)
                  : CachedNetworkImage(
                      imageUrl: thumbUrl,
                      fit: BoxFit.contain,
                      errorWidget: (_, _, _) => const SizedBox.shrink(),
                    ),
            ),
            errorBuilder: (context, error, stackTrace) => Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  const Icon(Icons.broken_image_rounded, size: 40, color: Colors.white70),
                  const SizedBox(height: PrismSpace.sm),
                  Text(
                    "Couldn't load the full image.",
                    style: PrismTextStyles.body(context).copyWith(color: Colors.white),
                  ),
                ],
              ),
            ),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(PrismSpace.sm),
              child: Align(
                alignment: AlignmentDirectional.topStart,
                child: PrismIconButton(
                  icon: Icons.close_rounded,
                  tooltip: 'Close',
                  onImage: true,
                  onPressed: () => Navigator.of(context).maybePop(),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
