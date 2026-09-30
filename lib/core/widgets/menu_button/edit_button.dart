import 'dart:io';

import 'package:Prism/core/router/app_router.dart';
import 'package:Prism/core/utils/safe_image_decode.dart';
import 'package:Prism/core/widgets/menu_button/circular_menu_button.dart';
import 'package:Prism/theme/jam_icons_icons.dart';
import 'package:Prism/theme/toasts.dart' as toasts;
import 'package:auto_route/auto_route.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:image/image.dart' as imagelib;
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';

class EditButton extends StatefulWidget {
  final String? url;
  const EditButton({required this.url, super.key});

  @override
  _EditButtonState createState() => _EditButtonState();
}

class _EditButtonState extends State<EditButton> {
  late bool isLoading;

  @override
  void initState() {
    isLoading = false;
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return CircularMenuButton(
      label: 'Edit',
      onTap: () {
        if (!isLoading) {
          onEdit(widget.url);
        }
      },
      isLoading: isLoading,
      child: Icon(JamIcons.pencil, color: Theme.of(context).colorScheme.secondary, size: 20),
    );
  }

  Future<void> onEdit(String? url) async {
    if (url == null) {
      toasts.error('No wallpaper URL available');
      return;
    }
    setState(() {
      isLoading = true;
    });
    toasts.codeSend('Loading Wallpaper');
    try {
      final response = await http.get(Uri.parse(url));
      final documentDirectory = await getApplicationDocumentsDirectory();
      final imagesDirectory = '${documentDirectory.path}/images';
      await Directory(imagesDirectory).create(recursive: true);
      final File fullFile = File('$imagesDirectory/pic.jpg');
      final File thumbFile = File('$imagesDirectory/picThumb.jpg');
      await fullFile.writeAsBytes(response.bodyBytes);
      final List<int> thumbBytes = await compute<Uint8List, List<int>>(_resizeImage, response.bodyBytes);
      await thumbFile.writeAsBytes(thumbBytes);
      if (!mounted) return;
      final thumbDecoded = decodeImageLenient(thumbBytes);
      final fullDecoded = decodeImageLenient(response.bodyBytes);
      if (thumbDecoded == null || fullDecoded == null) {
        toasts.error('Could not open this image for editing');
        setState(() {
          isLoading = false;
        });
        return;
      }
      setState(() {
        isLoading = false;
      });
      context.router.push(
        WallpaperFilterRoute(
          image: thumbDecoded,
          finalImage: fullDecoded,
          filename: path.basename(thumbFile.path),
          finalFilename: path.basename(fullFile.path),
        ),
      );
    } catch (_) {
      if (mounted) {
        toasts.error('Could not load wallpaper for editing');
        setState(() {
          isLoading = false;
        });
      }
    }
  }

  static List<int> _resizeImage(Uint8List bytes) {
    final imagelib.Image? decoded = decodeImageLenient(bytes);
    if (decoded == null) {
      throw const FormatException('decodeImageLenient');
    }
    return imagelib.encodeJpg(imagelib.copyResize(decoded, width: 300));
  }
}
