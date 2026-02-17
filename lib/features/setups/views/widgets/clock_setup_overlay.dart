import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

class SetupOverlay extends StatefulWidget {
  final String? link;
  const SetupOverlay({
    required this.link,
  });
  @override
  _SetupOverlayState createState() => _SetupOverlayState();
}

class _SetupOverlayState extends State<SetupOverlay> {
  @override
  Widget build(BuildContext context) {
    return Material(
      child: Stack(
        children: <Widget>[
          CachedNetworkImage(
            imageUrl: widget.link!,
            imageBuilder: (context, imageProvider) => Container(
              decoration: BoxDecoration(
                image: DecorationImage(
                  image: imageProvider,
                  fit: BoxFit.cover,
                ),
              ),
            ),
          ),
          GestureDetector(
            onTap: () => {Navigator.pop(context)},
            child: SizedBox(
              height: MediaQuery.of(context).size.height,
              width: MediaQuery.of(context).size.width,
              child: const Text(""),
            ),
          )
        ],
      ),
    );
  }
}
