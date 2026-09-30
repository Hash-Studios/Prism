import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

class SetupOverlay extends StatelessWidget {
  final String link;
  const SetupOverlay({required this.link});

  @override
  Widget build(BuildContext context) {
    return Material(
      child: Stack(
        children: <Widget>[
          CachedNetworkImage(
            imageUrl: link,
            imageBuilder: (context, imageProvider) => Container(
              decoration: BoxDecoration(
                image: DecorationImage(image: imageProvider, fit: BoxFit.cover),
              ),
            ),
          ),
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () => Navigator.pop(context),
            child: const SizedBox.expand(),
          ),
        ],
      ),
    );
  }
}
