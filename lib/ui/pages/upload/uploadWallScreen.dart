import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'package:Prism/theme/jam_icons_icons.dart';
import 'package:flare_flutter/flare_actor.dart';
import 'package:path/path.dart' as Path;
import 'package:Prism/routes/router.dart';
import 'package:flutter/material.dart';
import 'package:github/github.dart';
import 'package:image/image.dart' as Img;
import 'package:Prism/gitkey.dart';
import 'package:photo_view/photo_view.dart';

class UploadWallScreen extends StatefulWidget {
  final List arguments;
  UploadWallScreen({this.arguments});
  @override
  _UploadWallScreenState createState() => _UploadWallScreenState();
}

class _UploadWallScreenState extends State<UploadWallScreen> {
  bool isUploading;
  bool isProcessing;
  File image;
  String id;
  String tempid;
  String wallpaperUrl;
  String wallpaperResolution;
  String wallpaperProvider;
  String wallpaperSize;
  String wallpaperDesc;
  String wallpaperCategory;
  String wallpaperThumb;
  bool review;
  @override
  void initState() {
    super.initState();
    image = widget.arguments[0];
    isUploading = false;
    isProcessing = true;
    randomId();
    wallpaperProvider = "Prism";
    wallpaperDesc = "Community";
    wallpaperCategory = "General";
    review = false;
    processImage();
  }

  void randomId() {
    tempid = "";
    var alp = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ'.split("");
    var r = new Random();
    var choice = r.nextInt(4);
    for (var i = 0; i < 4; i++) {
      if (choice == i) {
        var ran = r.nextInt(10);
        tempid = tempid + ran.toString();
      } else {
        var ran = r.nextInt(26);
        tempid = tempid + alp[ran].toString();
      }
    }
    setState(() {
      id = tempid;
    });
    print(id);
  }

  Future processImage() async {
    Future.delayed(Duration(milliseconds: 1000)).then((value) async {
      var decodedImage = await decodeImageFromList(image.readAsBytesSync());
      print(decodedImage.width);
      print(decodedImage.height);
      var res =
          decodedImage.width.toString() + "x" + decodedImage.height.toString();
      setState(() {
        wallpaperResolution = res;
      });
      image.length().then((value) =>
          {wallpaperSize = (value / 1024 / 1024).toStringAsFixed(2) + "MB"});
      uploadFile();
      print(image.toString());
    });
  }

  Future uploadFile() async {
    setState(() {
      isUploading = true;
      isProcessing = false;
    });
    List<int> imageBytes = await image.readAsBytes();
    Img.Image thumbnail =
        Img.copyResize(Img.decodeImage(imageBytes), width: 250, height: 500);
    List<int> imageBytesThumb = Img.encodePng(thumbnail);
    String base64Image = base64Encode(imageBytes);
    String base64ImageThumb = base64Encode(imageBytesThumb);
    var github = GitHub(auth: Authentication.basic(username, password));
    await github.repositories
        .createFile(
            RepositorySlug('codenameakshay2', 'prism-walls-test'),
            CreateFile(
                message: "${Path.basename(image.path)}",
                content: base64Image,
                path: '${Path.basename(image.path)}'))
        .then((value) => setState(() {
              wallpaperUrl = value.content.downloadUrl;
              isUploading = false;
            }));
    await github.repositories
        .createFile(
            RepositorySlug('codenameakshay2', 'prism-walls-test'),
            CreateFile(
                message: "thumb_${Path.basename(image.path)}",
                content: base64ImageThumb,
                path: 'thumb_${Path.basename(image.path)}'))
        .then((value) => setState(() {
              wallpaperThumb = value.content.downloadUrl;
            }));
    print('File Uploaded');
  }

  Future<bool> onWillPop() async {
    navStack.removeLast();
    print(navStack);
    return true;
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: onWillPop,
      child: Scaffold(
        backgroundColor: Theme.of(context).primaryColor,
        appBar: AppBar(
          title: Text(
            "Submit",
            style: TextStyle(color: Theme.of(context).accentColor),
          ),
        ),
        body: Container(
          child: Column(
            children: <Widget>[
              ClipRRect(
                child: Container(
                  color: Theme.of(context).hintColor,
                  width: MediaQuery.of(context).size.width,
                  height: MediaQuery.of(context).size.width,
                  child: PhotoView(
                    imageProvider: FileImage(image),
                    backgroundDecoration: BoxDecoration(
                      color: Theme.of(context).hintColor,
                    ),
                  ),
                ),
              ),
              isProcessing || isUploading
                  ? Container(
                      width: MediaQuery.of(context).size.width / 2.4,
                      height: MediaQuery.of(context).size.width / 2.4,
                      child: FlareActor(
                        "assets/animations/Upload.flr",
                        animation: "upload",
                        isPaused: false,
                        fit: BoxFit.contain,
                        alignment: Alignment.center,
                      ),
                    )
                  : Container(),
              isUploading
                  ? Padding(
                      padding: const EdgeInsets.only(bottom: 12.0),
                      child: Text(
                        "Uploading...",
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 16,
                          color: Theme.of(context).accentColor,
                        ),
                      ),
                    )
                  : Container(),
              isProcessing
                  ? Padding(
                      padding: const EdgeInsets.only(bottom: 12.0),
                      child: Text(
                        "Processing...",
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 16,
                          color: Theme.of(context).accentColor,
                        ),
                      ),
                    )
                  : Container(),
              isProcessing || isUploading
                  ? Container(
                      width: MediaQuery.of(context).size.width / 2,
                      child: ClipRRect(
                          borderRadius: BorderRadius.circular(500),
                          child: LinearProgressIndicator(
                            backgroundColor: Theme.of(context).hintColor,
                            valueColor: AlwaysStoppedAnimation<Color>(
                                Color(0xFFE57697)),
                          )))
                  : Container(),
              Spacer(),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 0, 16),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.start,
                  children: <Widget>[
                    Icon(
                      JamIcons.info,
                      color: Theme.of(context).accentColor.withOpacity(0.6),
                    ),
                    Container(
                      width: MediaQuery.of(context).size.width * 0.7,
                      child: Padding(
                        padding: const EdgeInsets.all(8.0),
                        child: Text(
                          "Note - We have a strong review policy, and submitting irrelevant images will lead to ban. We take about 24 hours to review the submissions, and after a successful review, your photo will be visible in the profile section.",
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 10,
                            color:
                                Theme.of(context).accentColor.withOpacity(0.6),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              )
            ],
          ),
        ),
        floatingActionButton: FloatingActionButton(
            backgroundColor: !isProcessing && !isUploading
                ? Color(0xFFE57697)
                : Theme.of(context).hintColor,
            disabledElevation: 0,
            child: Icon(
              JamIcons.check,
              size: 40,
              color: Colors.white,
            ),
            onPressed: !isProcessing && !isUploading ? () {} : null),
      ),
    );
  }
}
