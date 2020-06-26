import 'package:Prism/theme/jam_icons_icons.dart';
import 'package:Prism/ui/widgets/signInPopUp.dart';
import 'package:flutter/material.dart';
import 'package:Prism/theme/toasts.dart' as toasts;
import 'package:gallery_saver/gallery_saver.dart';
import 'package:Prism/main.dart' as main;
import 'package:permission_handler/permission_handler.dart';

class DownloadButton extends StatefulWidget {
  final String link;
  const DownloadButton({
    @required this.link,
    Key key,
  }) : super(key: key);

  @override
  _DownloadButtonState createState() => _DownloadButtonState();
}

class _DownloadButtonState extends State<DownloadButton> {
  bool isLoading;
  @override
  void initState() {
    isLoading = false;
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () async {
        print("Download");
        if (!main.prefs.getBool("isLoggedin")) {
          googleSignInPopUp(context, () {
            onDownload();
          });
        } else {
          onDownload();
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
          Positioned(
              top: 0,
              left: 0,
              height: 63,
              width: 63,
              child: isLoading ? CircularProgressIndicator() : Container())
        ],
      ),
    );
  }

  void onDownload() async {
    var status = await Permission.storage.status;
    if (!status.isGranted) {
      await Permission.storage.request();
    }
    setState(() {
      isLoading = true;
    });
    print(widget.link);
    toasts.startDownload();
    GallerySaver.saveImage(widget.link, albumName: "Prism").then((value) {
      toasts.completedDownload();
      setState(() {
        isLoading = false;
      });
    }).catchError((e) {
      toasts.error(e.toString());
      setState(() {
        isLoading = false;
      });
    });
  }
}
