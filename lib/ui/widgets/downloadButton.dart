import 'package:Prism/theme/jam_icons_icons.dart';
import 'package:flutter/material.dart';
import 'package:Prism/theme/toasts.dart' as toasts;
import 'package:gallery_saver/gallery_saver.dart';

class DownloadButton extends StatelessWidget {
  final String link;
  const DownloadButton({
    @required this.link,
    Key key,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        print("Download");
        onDownload();
      },
      child: Container(
        decoration: BoxDecoration(
          color: Theme.of(context).primaryColor,
          boxShadow: [
            BoxShadow(
                color: Colors.black.withOpacity(.25),
                blurRadius: 4,
                offset: Offset(0, 4))
          ],
          borderRadius: BorderRadius.circular(500),
        ),
        padding: EdgeInsets.all(17),
        child: Icon(
          JamIcons.download,
          color: Theme.of(context).accentColor,
          size: 30,
        ),
      ),
    );
  }

  void onDownload() async {
    toasts.startDownload();
    GallerySaver.saveImage(link, albumName: "Prism").then((value) {
      toasts.completedDownload();
    }).catchError((e) {
      toasts.error(e.toString());
    });
  }
}
