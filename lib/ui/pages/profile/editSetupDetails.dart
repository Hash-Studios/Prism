import 'dart:convert';
import 'dart:io';
import 'package:Prism/analytics/analytics_service.dart';
import 'package:Prism/gitkey.dart';
import 'package:Prism/routes/routing_constants.dart';
import 'package:Prism/theme/jam_icons_icons.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:github/github.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path/path.dart' as Path;
import 'package:Prism/routes/router.dart';
import 'package:flutter/material.dart';
import 'package:Prism/data/upload/wallpaper/wallfirestore.dart' as WallStore;
import 'package:Prism/theme/toasts.dart' as toasts;
import 'package:Prism/main.dart' as main;
import 'package:Prism/global/globals.dart' as globals;

class EditSetupReviewScreen extends StatefulWidget {
  final List? arguments;
  const EditSetupReviewScreen({this.arguments});
  @override
  _EditSetupReviewScreenState createState() => _EditSetupReviewScreenState();
}

class _EditSetupReviewScreenState extends State<EditSetupReviewScreen> {
  late bool isUploading;
  late bool isProcessing;
  late File image;
  late DocumentSnapshot setupDoc;
  String? imageURL;
  TextEditingController setupName = TextEditingController();
  TextEditingController setupDesc = TextEditingController();
  TextEditingController iconName = TextEditingController();
  TextEditingController iconURL = TextEditingController();
  TextEditingController widgetName1 = TextEditingController();
  TextEditingController widgetURL1 = TextEditingController();
  String? id;
  String? tempid;
  TextEditingController wallpaperUrl = TextEditingController();
  String? wallpaperUploadLink;
  String wallpaperId = "";
  TextEditingController wallpaperAppName = TextEditingController();
  TextEditingController wallpaperAppWallName = TextEditingController();
  TextEditingController wallpaperAppLink = TextEditingController();
  TextEditingController widgetName2 = TextEditingController();
  TextEditingController widgetURL2 = TextEditingController();
  String? wallpaperProvider;
  String? wallpaperThumb;
  bool? review;
  late List<int> imageBytes;
  List<Widget> tags = [];
  FocusNode? textFocusNode;
  int? groupValue;
  int? groupWidgetValue;
  bool wallpaperUploaded = false;
  bool secondWidgetAdded = false;

  @override
  void initState() {
    super.initState();
    setupDoc = widget.arguments![0] as DocumentSnapshot;
    imageURL = setupDoc.data["image"].toString();
    groupWidgetValue = 0;
    setupName = TextEditingController(text: setupDoc.data["name"].toString());
    id = setupDoc.data["id"].toString();
    setupDesc = TextEditingController(text: setupDoc.data["desc"].toString());
    iconName = TextEditingController(text: setupDoc.data["icon"].toString());
    iconURL = TextEditingController(text: setupDoc.data["icon_url"].toString());
    widgetName1 =
        TextEditingController(text: setupDoc.data["widget"].toString());
    widgetURL1 =
        TextEditingController(text: setupDoc.data["widget_url"].toString());
    if ("${setupDoc.data["wallpaper_url"]}"[0] != "[") {
      if ("${setupDoc.data["wall_id"]}" != "" &&
          "${setupDoc.data["wall_id"]}" != null) {
        wallpaperUploaded = true;
        wallpaperUploadLink = setupDoc.data["wallpaper_url"].toString();
        wallpaperId = setupDoc.data["wall_id"].toString();
        groupValue = 1;
      } else {
        wallpaperUrl = TextEditingController(
            text: setupDoc.data["wallpaper_url"].toString());
        groupValue = 0;
      }
    } else {
      wallpaperAppName = TextEditingController(
          text: setupDoc.data["wallpaper_url"][0].toString());
      wallpaperAppWallName = TextEditingController(
          text: setupDoc.data["wallpaper_url"][2].toString());
      wallpaperAppLink = TextEditingController(
          text: setupDoc.data["wallpaper_url"][1].toString());
      groupValue = 2;
    }
    widgetName2 =
        TextEditingController(text: setupDoc.data["widget2"].toString());
    widgetURL2 =
        TextEditingController(text: setupDoc.data["widget_url2"].toString());
    isUploading = false;
    isProcessing = false;
    wallpaperProvider = setupDoc.data["wallpaper_provider"].toString();
    wallpaperThumb = setupDoc.data["wallpaper_thumb"].toString();
    review = setupDoc.data["review"] as bool?;
    secondWidgetAdded = "${setupDoc.data["widget2"]}" != "" &&
        "${setupDoc.data["widget2"]}" != null;
  }

  final Map<int, Widget> logoWidgets = <int, Widget>{
    0: Padding(
      padding: const EdgeInsets.all(4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        mainAxisSize: MainAxisSize.min,
        children: const [
          Icon(JamIcons.link),
          Text("Link"),
        ],
      ),
    ),
    1: Padding(
      padding: const EdgeInsets.all(4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        mainAxisSize: MainAxisSize.min,
        children: const [
          Icon(JamIcons.upload),
          Text("Upload"),
        ],
      ),
    ),
    2: Padding(
      padding: const EdgeInsets.all(4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        mainAxisSize: MainAxisSize.min,
        children: const [
          Icon(JamIcons.android),
          Text("App"),
        ],
      ),
    )
  };
  final Map<int, Widget> widgetsIcons = <int, Widget>{
    0: Padding(
      padding: const EdgeInsets.all(4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        mainAxisSize: MainAxisSize.min,
        children: const [
          Icon(JamIcons.google_play),
          Text("Widgets"),
        ],
      ),
    ),
    1: Padding(
      padding: const EdgeInsets.all(4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        mainAxisSize: MainAxisSize.min,
        children: const [
          Icon(JamIcons.google_play_circle),
          Text("* Icons"),
        ],
      ),
    )
  };

  Future pickImage() async {
    final picker = ImagePicker();
    final pickedFile = await picker.getImage(source: ImageSource.gallery);
    if (pickedFile != null) {
      setState(() {
        image = File(pickedFile.path);
      });
    }
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
            "Edit Setup",
            style: TextStyle(color: Theme.of(context).accentColor),
          ),
          actions: [
            TextButton(
              onPressed: !isProcessing && !isUploading
                  ? () async {
                      if (setupName.text == "" ||
                          setupName.text == null ||
                          setupDesc.text == "" ||
                          setupDesc.text == null ||
                          (wallpaperUploaded == false &&
                              (wallpaperUrl.text == "" ||
                                  wallpaperUrl.text == null) &&
                              ((wallpaperAppLink.text == "" ||
                                      wallpaperAppLink.text == null) ||
                                  (wallpaperAppName.text == "" ||
                                      wallpaperAppName.text == null))) ||
                          iconName.text == "" ||
                          iconName.text == null ||
                          iconURL.text == "" ||
                          iconURL.text == null) {
                        toasts.error("Please fill all required fields!");
                      } else {
                        navStack.removeLast();
                        debugPrint(navStack.toString());
                        Navigator.pop(context);
                        analytics.logEvent(
                            name: 'edit_setup',
                            parameters: {'id': id, 'link': imageURL});
                        WallStore.updateSetup(
                          setupDoc.documentID,
                          id,
                          imageURL,
                          wallpaperProvider,
                          wallpaperThumb,
                          wallpaperUploaded == true
                              ? wallpaperUploadLink
                              : wallpaperAppName.text != "" &&
                                      wallpaperAppName.text != null &&
                                      wallpaperAppLink.text != "" &&
                                      wallpaperAppLink.text != null
                                  ? [
                                      wallpaperAppName.text,
                                      wallpaperAppLink.text,
                                      wallpaperAppWallName.text
                                    ]
                                  : wallpaperUrl.text,
                          iconName.text,
                          iconURL.text,
                          widgetName1.text,
                          widgetURL1.text,
                          widgetName2.text,
                          widgetURL2.text,
                          setupName.text,
                          setupDesc.text,
                          wallpaperId,
                          review,
                        );
                      }
                    }
                  : null,
              child: Text(
                "Save",
                style: TextStyle(
                  color: !isProcessing && !isUploading
                      ? Theme.of(context).errorColor == Colors.black
                          ? Colors.white
                          : Theme.of(context).errorColor
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
                  backgroundColor: Theme.of(context).errorColor,
                  radius: 20,
                  child: ClipOval(
                      child: Image.network(globals.prismUser.profilePhoto)),
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
                        labelText: "* Write a Name...",
                        hintText: "* Write a Name...",
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
                        labelText: "* Write a description... (50 chars only)",
                        hintText: "* Write a description... (50 chars only)",
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
                onTap: () async {
                  await pickImage();
                },
                child: Stack(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(20.0),
                      height: 200,
                      width: 120,
                      child: CachedNetworkImage(
                          imageUrl: imageURL!, fit: BoxFit.contain),
                    ),
                    if (isUploading || isProcessing)
                      Container(
                        padding: const EdgeInsets.all(20.0),
                        height: 200,
                        width: 120,
                        child: Center(
                          child: CircularProgressIndicator(
                            valueColor: AlwaysStoppedAnimation<Color>(
                                Theme.of(context).errorColor),
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
          ExpansionTile(
            title: Text(
              "Add widgets, icon packs",
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.normal,
                color: Theme.of(context).accentColor,
              ),
            ),
            children: [
              Padding(
                padding: const EdgeInsets.all(8.0),
                child: CupertinoSegmentedControl(
                    children: widgetsIcons,
                    groupValue: groupWidgetValue,
                    borderColor: Theme.of(context).accentColor,
                    pressedColor: Theme.of(context).hintColor,
                    unselectedColor: Theme.of(context).primaryColor,
                    selectedColor: Theme.of(context).accentColor,
                    padding: EdgeInsets.zero,
                    onValueChanged: (int val) {
                      setState(() {
                        groupWidgetValue = val;
                      });
                    }),
              ),
              if (groupWidgetValue == 0)
                Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
                      child: Container(
                        decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(500),
                            color: Theme.of(context).hintColor),
                        child: TextField(
                          cursorColor: Theme.of(context).errorColor,
                          style: Theme.of(context)
                              .textTheme
                              .headline5!
                              .copyWith(color: Theme.of(context).accentColor),
                          controller: widgetName1,
                          focusNode: textFocusNode,
                          decoration: InputDecoration(
                            contentPadding:
                                const EdgeInsets.only(left: 30, top: 15),
                            border: InputBorder.none,
                            disabledBorder: InputBorder.none,
                            enabledBorder: InputBorder.none,
                            focusedBorder: InputBorder.none,
                            hintText: "Write widget app name...",
                            hintStyle: Theme.of(context)
                                .textTheme
                                .headline5!
                                .copyWith(color: Theme.of(context).accentColor),
                            suffixIcon: Icon(
                              JamIcons.android,
                              color: Theme.of(context).accentColor,
                            ),
                          ),
                          onSubmitted: (tex) {
                            // setState(() {
                            //   defaultText = tex;
                            // });
                          },
                        ),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
                      child: Container(
                        decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(500),
                            color: Theme.of(context).hintColor),
                        child: TextField(
                          cursorColor: Theme.of(context).errorColor,
                          style: Theme.of(context)
                              .textTheme
                              .headline5!
                              .copyWith(color: Theme.of(context).accentColor),
                          controller: widgetURL1,
                          focusNode: textFocusNode,
                          decoration: InputDecoration(
                            contentPadding:
                                const EdgeInsets.only(left: 30, top: 15),
                            border: InputBorder.none,
                            disabledBorder: InputBorder.none,
                            enabledBorder: InputBorder.none,
                            focusedBorder: InputBorder.none,
                            hintText: "Write widget app link...",
                            hintStyle: Theme.of(context)
                                .textTheme
                                .headline5!
                                .copyWith(color: Theme.of(context).accentColor),
                            suffixIcon: Icon(
                              JamIcons.google_play,
                              color: Theme.of(context).accentColor,
                            ),
                          ),
                          onSubmitted: (tex) {
                            // setState(() {
                            //   defaultText = tex;
                            // });
                          },
                        ),
                      ),
                    ),
                    if (secondWidgetAdded == true)
                      Padding(
                        padding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
                        child: Container(
                          decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(500),
                              color: Theme.of(context).hintColor),
                          child: TextField(
                            cursorColor: Theme.of(context).errorColor,
                            style: Theme.of(context)
                                .textTheme
                                .headline5!
                                .copyWith(color: Theme.of(context).accentColor),
                            controller: widgetName2,
                            focusNode: textFocusNode,
                            decoration: InputDecoration(
                              contentPadding:
                                  const EdgeInsets.only(left: 30, top: 15),
                              border: InputBorder.none,
                              disabledBorder: InputBorder.none,
                              enabledBorder: InputBorder.none,
                              focusedBorder: InputBorder.none,
                              hintText: "Write 2nd widget app name...",
                              hintStyle: Theme.of(context)
                                  .textTheme
                                  .headline5!
                                  .copyWith(
                                      color: Theme.of(context).accentColor),
                              suffixIcon: Icon(
                                JamIcons.android,
                                color: Theme.of(context).accentColor,
                              ),
                            ),
                            onSubmitted: (tex) {
                              // setState(() {
                              //   defaultText = tex;
                              // });
                            },
                          ),
                        ),
                      )
                    else
                      TextButton(
                          onPressed: () {
                            setState(() {
                              secondWidgetAdded = true;
                            });
                          },
                          child: Text("Add more widget",
                              style: Theme.of(context).textTheme.bodyText2)),
                    if (secondWidgetAdded == true)
                      Padding(
                        padding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
                        child: Container(
                          decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(500),
                              color: Theme.of(context).hintColor),
                          child: TextField(
                            cursorColor: Theme.of(context).errorColor,
                            style: Theme.of(context)
                                .textTheme
                                .headline5!
                                .copyWith(color: Theme.of(context).accentColor),
                            controller: widgetURL2,
                            focusNode: textFocusNode,
                            decoration: InputDecoration(
                              contentPadding:
                                  const EdgeInsets.only(left: 30, top: 15),
                              border: InputBorder.none,
                              disabledBorder: InputBorder.none,
                              enabledBorder: InputBorder.none,
                              focusedBorder: InputBorder.none,
                              hintText: "Write 2nd widget app link...",
                              hintStyle: Theme.of(context)
                                  .textTheme
                                  .headline5!
                                  .copyWith(
                                      color: Theme.of(context).accentColor),
                              suffixIcon: Icon(
                                JamIcons.google_play,
                                color: Theme.of(context).accentColor,
                              ),
                            ),
                            onSubmitted: (tex) {
                              // setState(() {
                              //   defaultText = tex;
                              // });
                            },
                          ),
                        ),
                      )
                    else
                      Container()
                  ],
                )
              else
                Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
                      child: Container(
                        decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(500),
                            color: Theme.of(context).hintColor),
                        child: TextField(
                          cursorColor: Theme.of(context).errorColor,
                          style: Theme.of(context)
                              .textTheme
                              .headline5!
                              .copyWith(color: Theme.of(context).accentColor),
                          controller: iconName,
                          focusNode: textFocusNode,
                          decoration: InputDecoration(
                            contentPadding:
                                const EdgeInsets.only(left: 30, top: 15),
                            border: InputBorder.none,
                            disabledBorder: InputBorder.none,
                            enabledBorder: InputBorder.none,
                            focusedBorder: InputBorder.none,
                            hintText: "Write icon pack name...",
                            hintStyle: Theme.of(context)
                                .textTheme
                                .headline5!
                                .copyWith(color: Theme.of(context).accentColor),
                            suffixIcon: Icon(
                              JamIcons.android,
                              color: Theme.of(context).accentColor,
                            ),
                          ),
                          onSubmitted: (tex) {
                            // setState(() {
                            //   defaultText = tex;
                            // });
                          },
                        ),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
                      child: Container(
                        decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(500),
                            color: Theme.of(context).hintColor),
                        child: TextField(
                          cursorColor: Theme.of(context).errorColor,
                          style: Theme.of(context)
                              .textTheme
                              .headline5!
                              .copyWith(color: Theme.of(context).accentColor),
                          controller: iconURL,
                          focusNode: textFocusNode,
                          decoration: InputDecoration(
                            contentPadding:
                                const EdgeInsets.only(left: 30, top: 15),
                            border: InputBorder.none,
                            disabledBorder: InputBorder.none,
                            enabledBorder: InputBorder.none,
                            focusedBorder: InputBorder.none,
                            hintText: "Write icon app link...",
                            hintStyle: Theme.of(context)
                                .textTheme
                                .headline5!
                                .copyWith(color: Theme.of(context).accentColor),
                            suffixIcon: Icon(
                              JamIcons.google_play_circle,
                              color: Theme.of(context).accentColor,
                            ),
                          ),
                          onSubmitted: (tex) {
                            // setState(() {
                            //   defaultText = tex;
                            // });
                          },
                        ),
                      ),
                    ),
                  ],
                ),
            ],
          ),
          const Divider(
            height: 1,
          ),
          ExpansionTile(
            title: Text(
              "* Add wallpaper",
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.normal,
                color: Theme.of(context).accentColor,
              ),
            ),
            children: [
              Padding(
                padding: const EdgeInsets.all(8.0),
                child: CupertinoSegmentedControl(
                    children: logoWidgets,
                    groupValue: groupValue,
                    borderColor: Theme.of(context).accentColor,
                    pressedColor: Theme.of(context).hintColor,
                    unselectedColor: Theme.of(context).primaryColor,
                    selectedColor: Theme.of(context).accentColor,
                    padding: EdgeInsets.zero,
                    onValueChanged: (int val) {
                      setState(() {
                        groupValue = val;
                      });
                    }),
              ),
              if (groupValue == 0)
                Padding(
                  padding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
                  child: Container(
                    decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(500),
                        color: Theme.of(context).hintColor),
                    child: TextField(
                      cursorColor: Theme.of(context).errorColor,
                      style: Theme.of(context)
                          .textTheme
                          .headline5!
                          .copyWith(color: Theme.of(context).accentColor),
                      controller: wallpaperUrl,
                      focusNode: textFocusNode,
                      decoration: InputDecoration(
                        contentPadding:
                            const EdgeInsets.only(left: 30, top: 15),
                        border: InputBorder.none,
                        disabledBorder: InputBorder.none,
                        enabledBorder: InputBorder.none,
                        focusedBorder: InputBorder.none,
                        hintText: "Write wallpaper link...",
                        hintStyle: Theme.of(context)
                            .textTheme
                            .headline5!
                            .copyWith(color: Theme.of(context).accentColor),
                        suffixIcon: Icon(
                          JamIcons.picture,
                          color: Theme.of(context).accentColor,
                        ),
                      ),
                      onSubmitted: (tex) {
                        // setState(() {
                        //   defaultText = tex;
                        // });
                      },
                    ),
                  ),
                )
              else
                groupValue == 1
                    ? Padding(
                        padding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
                        child: FloatingActionButton.extended(
                          backgroundColor: wallpaperUploaded == true
                              ? Theme.of(context).hintColor
                              : Theme.of(context).errorColor,
                          onPressed: () async {
                            final pickedFile = await ImagePicker()
                                .getImage(source: ImageSource.gallery);
                            if (pickedFile != null) {
                              Future.delayed(const Duration())
                                  .then((value) async {
                                final argumentsFromWall =
                                    await Navigator.pushNamed(
                                        context, uploadWallRoute, arguments: [
                                  File(pickedFile.path),
                                  true
                                ]);
                                if (argumentsFromWall != null) {
                                  final List argsC = argumentsFromWall as List;
                                  if (argsC.length == 2) {
                                    setState(() {
                                      wallpaperUploadLink = argsC[0].toString();
                                      wallpaperId = argsC[1].toString();
                                      wallpaperUploaded = true;
                                    });
                                  }
                                }
                              });
                            }
                          },
                          label: Text(
                            wallpaperUploaded == true
                                ? "Change Wall"
                                : "Upload",
                            style: TextStyle(
                                color: Theme.of(context).accentColor,
                                fontWeight: FontWeight.normal),
                          ),
                          icon: Icon(
                            JamIcons.upload,
                            color: Theme.of(context).accentColor,
                          ),
                        ),
                      )
                    : Column(
                        children: [
                          Padding(
                            padding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
                            child: Container(
                              decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(500),
                                  color: Theme.of(context).hintColor),
                              child: TextField(
                                cursorColor: Theme.of(context).errorColor,
                                style: Theme.of(context)
                                    .textTheme
                                    .headline5!
                                    .copyWith(
                                        color: Theme.of(context).accentColor),
                                controller: wallpaperAppName,
                                focusNode: textFocusNode,
                                decoration: InputDecoration(
                                  contentPadding:
                                      const EdgeInsets.only(left: 30, top: 15),
                                  border: InputBorder.none,
                                  disabledBorder: InputBorder.none,
                                  enabledBorder: InputBorder.none,
                                  focusedBorder: InputBorder.none,
                                  hintText: "Write wallpaper app name...",
                                  hintStyle: Theme.of(context)
                                      .textTheme
                                      .headline5!
                                      .copyWith(
                                          color: Theme.of(context).accentColor),
                                  suffixIcon: Icon(
                                    JamIcons.android,
                                    color: Theme.of(context).accentColor,
                                  ),
                                ),
                                onSubmitted: (tex) {
                                  // setState(() {
                                  //   defaultText = tex;
                                  // });
                                },
                              ),
                            ),
                          ),
                          Padding(
                            padding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
                            child: Container(
                              decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(500),
                                  color: Theme.of(context).hintColor),
                              child: TextField(
                                cursorColor: Theme.of(context).errorColor,
                                style: Theme.of(context)
                                    .textTheme
                                    .headline5!
                                    .copyWith(
                                        color: Theme.of(context).accentColor),
                                controller: wallpaperAppLink,
                                focusNode: textFocusNode,
                                decoration: InputDecoration(
                                  contentPadding:
                                      const EdgeInsets.only(left: 30, top: 15),
                                  border: InputBorder.none,
                                  disabledBorder: InputBorder.none,
                                  enabledBorder: InputBorder.none,
                                  focusedBorder: InputBorder.none,
                                  hintText: "Write app link...",
                                  hintStyle: Theme.of(context)
                                      .textTheme
                                      .headline5!
                                      .copyWith(
                                          color: Theme.of(context).accentColor),
                                  suffixIcon: Icon(
                                    JamIcons.google_play,
                                    color: Theme.of(context).accentColor,
                                  ),
                                ),
                                onSubmitted: (tex) {
                                  // setState(() {
                                  //   defaultText = tex;
                                  // });
                                },
                              ),
                            ),
                          ),
                          Padding(
                            padding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
                            child: Container(
                              decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(500),
                                  color: Theme.of(context).hintColor),
                              child: TextField(
                                cursorColor: Theme.of(context).errorColor,
                                style: Theme.of(context)
                                    .textTheme
                                    .headline5!
                                    .copyWith(
                                        color: Theme.of(context).accentColor),
                                controller: wallpaperAppWallName,
                                focusNode: textFocusNode,
                                decoration: InputDecoration(
                                  contentPadding:
                                      const EdgeInsets.only(left: 30, top: 15),
                                  border: InputBorder.none,
                                  disabledBorder: InputBorder.none,
                                  enabledBorder: InputBorder.none,
                                  focusedBorder: InputBorder.none,
                                  hintText: "Write wallpaper name",
                                  hintStyle: Theme.of(context)
                                      .textTheme
                                      .headline5!
                                      .copyWith(
                                          color: Theme.of(context).accentColor),
                                  suffixIcon: Icon(
                                    JamIcons.picture,
                                    color: Theme.of(context).accentColor,
                                  ),
                                ),
                                onSubmitted: (tex) {
                                  // setState(() {
                                  //   defaultText = tex;
                                  // });
                                },
                              ),
                            ),
                          ),
                        ],
                      ),
            ],
          ),
          const Divider(
            height: 1,
          ),
          ListTile(
            title: Text(
              "Fields marked with * are required.",
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w100,
                color: Theme.of(context).accentColor.withOpacity(0.7),
              ),
            ),
          ),
          const Divider(
            height: 1,
          ),
          ListTile(
            title: Text(
              globals.prismUser.premium == true
                  ? "Note - We have a strong review policy, and submitting irrelevant images & info will lead to ban. Your setup will be visible in the setups section."
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
