import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';
import 'package:Prism/analytics/analytics_service.dart';
import 'package:Prism/theme/jam_icons_icons.dart';
import 'package:flare_flutter/flare_actor.dart';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as Path;
import 'package:Prism/routes/router.dart';
import 'package:flutter/material.dart';
import 'package:github/github.dart';
import 'package:Prism/gitkey.dart';
import 'package:photo_view/photo_view.dart';
import 'package:Prism/data/upload/wallpaper/wallfirestore.dart' as WallStore;
import 'package:Prism/theme/toasts.dart' as toasts;
import 'package:Prism/main.dart' as main;
import 'package:Prism/theme/config.dart' as config;
import 'package:flutter_image_compress/flutter_image_compress.dart';

class UploadWallScreen extends StatefulWidget {
  final List arguments;
  const UploadWallScreen({this.arguments});
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
    image = widget.arguments[0] as File;
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
    final alp = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ'.split("");
    final r = Random();
    final choice = r.nextInt(4);
    for (var i = 0; i < 4; i++) {
      if (choice == i) {
        final ran = r.nextInt(10);
        tempid = tempid + ran.toString();
      } else {
        final ran = r.nextInt(26);
        tempid = tempid + alp[ran].toString();
      }
    }
    setState(() {
      id = tempid;
    });
    debugPrint(id);
  }

  Future<Uint8List> compressFile(File file) async {
    final result = await FlutterImageCompress.compressWithFile(
      file.absolute.path,
      minWidth: 400,
      quality: 85,
    );
    debugPrint(file.lengthSync().toString());
    debugPrint(result.length.toString());
    return result;
  }

  Future processImage() async {
    final imgList = image.readAsBytesSync();
    final decodedImage = await decodeImageFromList(imgList);

    debugPrint(decodedImage.width.toString());
    debugPrint(decodedImage.height.toString());

    final res = "${decodedImage.width}x${decodedImage.height}";

    setState(() {
      wallpaperResolution = res;
    });

    image.length().then((value) =>
        {wallpaperSize = "${(value / 1024 / 1024).toStringAsFixed(2)}MB"});

    imageBytes = await image.readAsBytes();
    imageBytesThumb = await compressFile(image);

    uploadFile();
  }

  Future deleteFile() async {
    final github = GitHub(auth: Authentication.withToken(token));
    await github.repositories.deleteFile(RepositorySlug(gitUserName, repoName),
        wallpaperPath, wallpaperPath, wallpaperSha, "master");
    await github.repositories.deleteFile(RepositorySlug(gitUserName, repoName),
        thumbPath, thumbPath, thumbSha, "master");
    debugPrint("Files deleted");
  }

  Future uploadFile() async {
    setState(() {
      isUploading = true;
      isProcessing = false;
    });
    try {
      final String base64Image = base64Encode(imageBytes);
      final String base64ImageThumb = base64Encode(imageBytesThumb);
      final github = GitHub(auth: Authentication.withToken(token));
      await github.repositories
          .createFile(
              RepositorySlug(gitUserName, repoName),
              CreateFile(
                  message: Path.basename(image.path),
                  content: base64Image,
                  path: Path.basename(image.path)))
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
      debugPrint('File Uploaded');
      setState(() {
        isUploading = false;
      });
    } catch (e) {
      debugPrint(e.toString());
      Navigator.pop(context);
      navStack.removeLast();
      debugPrint(navStack.toString());
      toasts.error("Some uploading issue, please try again.");
    }
  }

  Future<bool> onWillPop() async {
    if (navStack.length > 1) navStack.removeLast();
    debugPrint(navStack.toString());
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
        body: Column(
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
            if (isProcessing || isUploading)
              Container(
                width: MediaQuery.of(context).size.width / 2.4,
                height: MediaQuery.of(context).size.width / 2.4,
                child: FlareActor(
                  isUploading
                      ? "assets/animations/Upload.flr"
                      : "assets/animations/Process.flr",
                  animation: isUploading ? "upload" : "process",
                ),
              )
            else
              Container(),
            if (isUploading)
              Padding(
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
            else
              Container(),
            if (isProcessing)
              Padding(
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
            else
              Container(),
            if (isProcessing || isUploading)
              Container(
                  width: MediaQuery.of(context).size.width / 2,
                  child: ClipRRect(
                      borderRadius: BorderRadius.circular(500),
                      child: LinearProgressIndicator(
                        backgroundColor: Theme.of(context).hintColor,
                        valueColor: AlwaysStoppedAnimation<Color>(
                            config.Colors().mainAccentColor(1)),
                      )))
            else
              Container(),
            const Spacer(),
            Padding(
              padding: const EdgeInsets.fromLTRB(0, 0, 0, 16),
              child: Row(
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
                        child: Text(
                          main.prefs.get('premium') == true
                              ? "Note - We have a strong review policy, and submitting irrelevant images will lead to ban. Your photo will be visible in the profile/community section."
                              : "Note - We have a strong review policy, and submitting irrelevant images will lead to ban. We take about 24 hours to review the submissions, and after a successful review, your photo will be visible in the profile/community section.",
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 10,
                            color:
                                Theme.of(context).accentColor.withOpacity(0.6),
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
        floatingActionButton: FloatingActionButton(
          backgroundColor: !isProcessing && !isUploading
              ? config.Colors().mainAccentColor(1)
              : Theme.of(context).hintColor,
          disabledElevation: 0,
          onPressed: !isProcessing && !isUploading
              ? () async {
                  navStack.removeLast();
                  debugPrint(navStack.toString());
                  Navigator.pop(context, [wallpaperUrl, id]);
                  analytics.logEvent(
                      name: 'upload_wallpaper',
                      parameters: {'id': id, 'link': wallpaperUrl});
                  WallStore.createRecord(
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
              : null,
          child: const Icon(
            JamIcons.check,
            size: 40,
            color: Colors.white,
          ),
        ),
      ),
    );
  }
}
