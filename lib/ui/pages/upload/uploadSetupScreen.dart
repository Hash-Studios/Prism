import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'package:Prism/analytics/analytics_service.dart';
import 'package:Prism/gitkey.dart';
import 'package:Prism/routes/routing_constants.dart';
import 'package:Prism/theme/jam_icons_icons.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:github/github.dart';
import 'package:path/path.dart' as Path;
import 'package:Prism/routes/router.dart';
import 'package:flutter/material.dart';
import 'package:photo_view/photo_view.dart';
import 'package:Prism/data/upload/wallpaper/wallfirestore.dart' as WallStore;
import 'package:Prism/theme/toasts.dart' as toasts;
import 'package:Prism/main.dart' as main;
import 'package:Prism/theme/config.dart' as config;

class UploadSetupScreen extends StatefulWidget {
  final List arguments;
  const UploadSetupScreen({this.arguments});
  @override
  _UploadSetupScreenState createState() => _UploadSetupScreenState();
}

class _UploadSetupScreenState extends State<UploadSetupScreen> {
  bool isUploading;
  bool isProcessing;
  File image;
  final ScrollController _scrollController = ScrollController();
  String imageURL;
  TextEditingController setupName = TextEditingController();
  TextEditingController setupDesc = TextEditingController();
  TextEditingController iconName = TextEditingController();
  TextEditingController iconURL = TextEditingController();
  TextEditingController widgetName = TextEditingController();
  TextEditingController widgetURL = TextEditingController();
  String id;
  String tempid;
  TextEditingController wallpaperUrl = TextEditingController();
  String wallpaperProvider;
  String wallpaperThumb;
  bool review;
  List<int> imageBytes;
  @override
  void initState() {
    super.initState();
    image = widget.arguments[0] as File;
    isUploading = false;
    isProcessing = true;
    randomId();
    wallpaperProvider = "Prism";
    wallpaperThumb = "";
    review = false;
    processImage();
  }

  void randomId() {
    tempid = "";
    final alp = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ'.split("");
    final r = Random();
    final choice = r.nextInt(6);
    for (var i = 0; i < 6; i++) {
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

  Future processImage() async {
    imageBytes = await image.readAsBytes();
    uploadFile();
  }

  Future uploadFile() async {
    setState(() {
      isUploading = true;
      isProcessing = false;
    });
    try {
      final String base64Image = base64Encode(imageBytes);
      final github = GitHub(auth: Authentication.withToken(token));
      await github.repositories
          .createFile(
              RepositorySlug(gitUserName, repoName2),
              CreateFile(
                  message: Path.basename(image.path),
                  content: base64Image,
                  path: Path.basename(image.path)))
          .then((value) => setState(() {
                imageURL = value.content.downloadUrl;
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
            "Upload Setup",
            style: TextStyle(color: Theme.of(context).accentColor),
          ),
          actions: [
            TextButton(
              onPressed: !isProcessing && !isUploading
                  ? () async {
                      if (setupName.text == "" ||
                          setupDesc.text == "" ||
                          wallpaperUrl.text == "" ||
                          iconName.text == "" ||
                          iconURL.text == "") {
                        toasts.error("Please fill all required fields!");
                      } else {
                        navStack.removeLast();
                        debugPrint(navStack.toString());
                        Navigator.pop(context);
                        analytics.logEvent(
                            name: 'upload_setup',
                            parameters: {'id': id, 'link': imageURL});
                        WallStore.createSetup(
                            id,
                            imageURL,
                            wallpaperProvider,
                            wallpaperThumb,
                            wallpaperUrl.text,
                            iconName.text,
                            iconURL.text,
                            widgetName.text,
                            widgetURL.text,
                            setupName.text,
                            setupDesc.text,
                            review);
                      }
                    }
                  : null,
              child: Text(
                "Post",
                style: TextStyle(
                  color: !isProcessing && !isUploading
                      ? config.Colors().accentColor(1)
                      : Theme.of(context).hintColor,
                  fontWeight: FontWeight.normal,
                ),
              ),
            ),
          ],
        ),
        body: ListView(children: [
          Row(
            children: [
              Padding(
                padding: const EdgeInsets.all(20.0),
                child: CircleAvatar(
                  backgroundColor: config.Colors().mainAccentColor(1),
                  radius: 20,
                  child: main.prefs.get("googleimage") == null
                      ? Container()
                      : ClipOval(
                          child: Image.network(
                              main.prefs.get("googleimage").toString())),
                ),
              ),
              const Spacer(),
              SizedBox(
                width: MediaQuery.of(context).size.width * 0.4,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const SizedBox(height: 20),
                    TextField(
                      controller: setupName,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.normal,
                        color: Theme.of(context).accentColor,
                      ),
                      decoration: InputDecoration(
                        labelText: "Write a Name...",
                        hintText: "Write a Name...",
                        hintStyle: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.normal,
                          color: Theme.of(context).accentColor,
                        ),
                        labelStyle: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.normal,
                          color: Theme.of(context).accentColor,
                        ),
                        floatingLabelBehavior: FloatingLabelBehavior.never,
                        border: InputBorder.none,
                      ),
                    ),
                    TextField(
                      maxLines: 2,
                      controller: setupDesc,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.normal,
                        color: Theme.of(context).accentColor,
                      ),
                      decoration: InputDecoration(
                        labelText: "Write a description...",
                        hintText: "Write a description...",
                        hintStyle: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.normal,
                          color: Theme.of(context).accentColor,
                        ),
                        labelStyle: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.normal,
                          color: Theme.of(context).accentColor,
                        ),
                        floatingLabelBehavior: FloatingLabelBehavior.never,
                        border: InputBorder.none,
                      ),
                    ),
                  ],
                ),
              ),
              const Spacer(flex: 10),
              GestureDetector(
                onTap: () {
                  Navigator.push(
                      context,
                      CupertinoPageRoute(
                          builder: (context) => PhotoView(
                                onTapUp: (context, details, controller) {
                                  Navigator.pop(context);
                                },
                                imageProvider: FileImage(image),
                              ),
                          fullscreenDialog: true));
                },
                child: Stack(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(20.0),
                      height: 200,
                      width: 120,
                      child: Image.file(image, fit: BoxFit.contain),
                    ),
                    if (isUploading || isProcessing)
                      Container(
                        padding: const EdgeInsets.all(20.0),
                        height: 200,
                        width: 120,
                        child: Center(
                          child: CircularProgressIndicator(
                            valueColor: AlwaysStoppedAnimation<Color>(
                                config.Colors().mainAccentColor(1)),
                          ),
                        ),
                      )
                    else
                      Container(),
                  ],
                ),
              )
            ],
          ),
          const Divider(
            height: 1,
          ),
          ListTile(
            title: Text(
              "Tag widgets, icon packs",
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.normal,
                color: Theme.of(context).accentColor,
              ),
            ),
            onTap: () {
              Navigator.pushNamed(context, setupTagRoute, arguments: [
                image,
                MediaQuery.of(context).size.height * 0.7,
              ]);
            },
          ),
          const Divider(
            height: 1,
          ),
          ListTile(
            title: Text(
              "Add wallpaper",
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.normal,
                color: Theme.of(context).accentColor,
              ),
            ),
            onTap: () {},
          ),
          const Divider(
            height: 1,
          ),
          ListTile(
            title: Text(
              main.prefs.get('premium') == true
                  ? "Note - We have a strong review policy, and submitting irrelevant images & info will lead to ban. Your photo will be visible in the profile/community section."
                  : "Note - We have a strong review policy, and submitting irrelevant images & info will lead to ban. We take about 24 hours to review the submissions, and after a successful review, your setup will be visible in the setups section.",
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w100,
                color: Theme.of(context).accentColor.withOpacity(0.7),
              ),
            ),
          )
        ]),
      ),
    );
  }
}
