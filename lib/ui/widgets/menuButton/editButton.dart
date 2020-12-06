import 'dart:io';

import 'package:Prism/routes/routing_constants.dart';
import 'package:Prism/theme/jam_icons_icons.dart';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:image/image.dart' as imagelib;
import 'package:http/http.dart' as http;
import 'package:path/path.dart' as path;
import 'package:flutter/foundation.dart';
import 'package:Prism/theme/toasts.dart' as toasts;

class EditButton extends StatefulWidget {
  final String url;
  const EditButton({
    @required this.url,
    Key key,
  }) : super(key: key);

  @override
  _EditButtonState createState() => _EditButtonState();
}

class _EditButtonState extends State<EditButton> {
  bool isLoading;
  String imageData;
  String imageThumbData;

  @override
  void initState() {
    isLoading = false;
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        if (!isLoading) {
          onEdit(widget.url);
        }
      },
      child: Stack(
        children: [
          Container(
            decoration: BoxDecoration(
              color: Theme.of(context).primaryColor,
              boxShadow: [
                BoxShadow(
                    color: Colors.black.withOpacity(.25),
                    blurRadius: 4,
                    offset: const Offset(0, 4))
              ],
              borderRadius: BorderRadius.circular(500),
            ),
            padding: const EdgeInsets.all(17),
            child: Icon(
              JamIcons.pencil,
              color: Theme.of(context).accentColor,
              size: 20,
            ),
          ),
          Positioned(
              top: 0,
              left: 0,
              height: 53,
              width: 53,
              child:
                  isLoading ? const CircularProgressIndicator() : Container())
        ],
      ),
    );
  }

  Future<void> onEdit(String url) async {
    setState(() {
      isLoading = true;
    });
    toasts.codeSend("Loading Wallpaper");
    final response = await http.get(url);
    final documentDirectory = await getApplicationDocumentsDirectory();
    final firstPath = "${documentDirectory.path}/images";
    final filePathAndName = "${documentDirectory.path}/images/pic.jpg";
    final filePathAndNameThumb =
        "${documentDirectory.path}/images/picThumb.jpg";
    await Directory(firstPath).create(recursive: true);
    final File file2 = File(filePathAndName);
    file2.writeAsBytesSync(response.bodyBytes);
    final File file3 = File(filePathAndNameThumb);
    final List<int> imageBytesThumb =
        await compute<File, List<int>>(_resizeImage, file2);
    file3.writeAsBytesSync(imageBytesThumb);
    setState(() {
      imageData = filePathAndName;
      imageThumbData = filePathAndNameThumb;
      isLoading = false;
    });
    Navigator.pushNamed(context, wallpaperFilterRoute, arguments: [
      imagelib.decodeImage(File(imageThumbData).readAsBytesSync()),
      imagelib.decodeImage(File(imageData).readAsBytesSync()),
      path.basename(File(imageThumbData).path),
      path.basename(File(imageData).path),
    ]);
  }

  static Future<List<int>> _resizeImage(File file) async {
    final bytes = await file.readAsBytes();
    final imagelib.Image image = imagelib.decodeImage(bytes);
    final imagelib.Image resized = imagelib.copyResize(image, width: 300);
    final List<int> resizedBytes = imagelib.encodeJpg(resized);
    return resizedBytes;
  }
}
