import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

class FullScreenImageView extends StatelessWidget {
  const FullScreenImageView({super.key, required this.imageUrl});

  final String imageUrl;

  static Future<void> show(BuildContext context, String imageUrl) {
    return Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => FullScreenImageView(imageUrl: imageUrl)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: InteractiveViewer(
        maxScale: 5,
        child: Center(
          child: CachedNetworkImage(
            imageUrl: imageUrl,
            fit: BoxFit.contain,
            placeholder: (_, _) => const Center(child: CircularProgressIndicator()),
            errorWidget: (_, _, _) => const Center(child: Icon(Icons.broken_image, color: Colors.white, size: 48)),
          ),
        ),
      ),
    );
  }
}
