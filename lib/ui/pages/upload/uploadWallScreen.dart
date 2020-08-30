import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'package:Prism/analytics/analytics_service.dart';
import 'package:Prism/theme/jam_icons_icons.dart';
import 'package:flare_flutter/flare_actor.dart';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as Path;
import 'package:Prism/routes/router.dart';
import 'package:flutter/material.dart';
import 'package:github/github.dart';
import 'package:image/image.dart' as Img;
import 'package:Prism/gitkey.dart';
import 'package:photo_view/photo_view.dart';
import 'package:Prism/data/upload/wallpaper/wallfirestore.dart' as WallStore;
import 'package:Prism/theme/toasts.dart' as toasts;
import 'package:Prism/main.dart' as main;

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
  String wallpaperSha;
  String thumbSha;
  String wallpaperPath;
  String thumbPath;
  bool review;
  List<int> imageBytes;
  List<int> imageBytesThumb;
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

  static Future<List<int>> _resizeImage(File file) async {
    final bytes = await file.readAsBytes();
    final Img.Image image = Img.decodeImage(bytes);
    final Img.Image resized = Img.copyResize(image, width: 250);
    final List<int> resizedBytes = Img.encodeJpg(resized);

    return resizedBytes;
  }

  Future processImage() async {
    var imgList = image.readAsBytesSync();
    var decodedImage = await decodeImageFromList(imgList);

    print(decodedImage.width);
    print(decodedImage.height);

    var res =
        decodedImage.width.toString() + "x" + decodedImage.height.toString();

    setState(() {
      wallpaperResolution = res;
    });

    image.length().then((value) =>
        {wallpaperSize = (value / 1024 / 1024).toStringAsFixed(2) + "MB"});

    imageBytes = await image.readAsBytes();
    imageBytesThumb = await compute<File, List<int>>(_resizeImage, image);

    uploadFile();
    // print(image.toString());
  }

  Future deleteFile() async {
    var github = GitHub(auth: Authentication.withToken(token));
    await github.repositories.deleteFile(RepositorySlug(gitUserName, repoName),
        wallpaperPath, wallpaperPath, wallpaperSha, "master");
    await github.repositories.deleteFile(RepositorySlug(gitUserName, repoName),
        thumbPath, thumbPath, thumbSha, "master");
    print("Files deleted");
  }

  Future uploadFile() async {
    setState(() {
      isUploading = true;
      isProcessing = false;
    });
    try {
      String base64Image = base64Encode(imageBytes);
      String base64ImageThumb = base64Encode(imageBytesThumb);
      var github = GitHub(auth: Authentication.withToken(token));
      await github.repositories
          .createFile(
              RepositorySlug(gitUserName, repoName),
              CreateFile(
                  message: "${Path.basename(image.path)}",
                  content: base64Image,
                  path: '${Path.basename(image.path)}'))
          .then((value) => setState(() {
                wallpaperUrl = value.content.downloadUrl;
                wallpaperPath = value.content.path;
                wallpaperSha = value.content.sha;
              }));
      await github.repositories
          .createFile(
              RepositorySlug(gitUserName, repoName),
              CreateFile(
                  message: "thumb_${Path.basename(image.path)}",
                  content: base64ImageThumb,
                  path: 'thumb_${Path.basename(image.path)}'))
          .then((value) => setState(() {
                wallpaperThumb = value.content.downloadUrl;
                thumbPath = value.content.path;
                thumbSha = value.content.sha;
              }));
      print('File Uploaded');
      setState(() {
        isUploading = false;
      });
    } catch (e) {
      print(e.toString());
      Navigator.pop(context);
      navStack.removeLast();
      print(navStack);
      toasts.error("Some uploading issue, please try again.");
    }
  }

  Future<bool> onWillPop() async {
    if (navStack.length > 1) navStack.removeLast();
    print(navStack);
    deleteFile();
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
            "Upload Wallpaper",
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
                        isUploading
                            ? "assets/animations/Upload.flr"
                            : "assets/animations/Process.flr",
                        animation: isUploading ? "upload" : "process",
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
                padding: const EdgeInsets.fromLTRB(0, 0, 0, 16),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.start,
                  children: <Widget>[
                    Container(
                      width: MediaQuery.of(context).size.width * 0.2,
                      child: Center(
                        child: Icon(
                          JamIcons.info,
                          color: Theme.of(context).accentColor.withOpacity(0.6),
                        ),
                      ),
                    ),
                    Container(
                      width: MediaQuery.of(context).size.width * 0.6,
                      child: Padding(
                        padding: const EdgeInsets.all(8.0),
                        child: Center(
                          child: main.prefs.get('premium') == true
                              ? "Note - We have a strong review policy, and submitting irrelevant images will lead to ban. Your photo will be visible in the profile/community section."
                              : Text(
                                  "Note - We have a strong review policy, and submitting irrelevant images will lead to ban. We take about 24 hours to review the submissions, and after a successful review, your photo will be visible in the profile/community section.",
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    fontSize: 10,
                                    color: Theme.of(context)
                                        .accentColor
                                        .withOpacity(0.6),
                                  ),
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
            onPressed: !isProcessing && !isUploading
                ? () async {
                    navStack.removeLast();
                    print(navStack);
                    Navigator.pop(context);
                    analytics.logEvent(
                        name: 'upload_wallpaper',
                        parameters: {'id': id, 'link': wallpaperUrl});
                    await WallStore.createRecord(
                        id,
                        wallpaperProvider,
                        wallpaperThumb,
                        wallpaperUrl,
                        wallpaperResolution,
                        wallpaperSize,
                        wallpaperCategory,
                        wallpaperDesc,
                        review);
                  }
                : null),
      ),
    );
  }
}
