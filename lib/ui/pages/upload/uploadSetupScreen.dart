import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'package:Prism/analytics/analytics_service.dart';
import 'package:Prism/data/apps/appsData.dart';
import 'package:Prism/gitkey.dart';
import 'package:Prism/routes/routing_constants.dart';
import 'package:Prism/theme/jam_icons_icons.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:github/github.dart';
import 'package:hive/hive.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path/path.dart' as Path;
import 'package:Prism/routes/router.dart';
import 'package:flutter/material.dart';
import 'package:photo_view/photo_view.dart';
import 'package:Prism/data/upload/wallpaper/wallfirestore.dart' as WallStore;
import 'package:Prism/theme/toasts.dart' as toasts;
import 'package:Prism/global/globals.dart' as globals;
import 'package:Prism/logger/logger.dart';

class UploadSetupScreen extends StatefulWidget {
  final List? arguments;
  const UploadSetupScreen({this.arguments});
  @override
  _UploadSetupScreenState createState() => _UploadSetupScreenState();
}

class _UploadSetupScreenState extends State<UploadSetupScreen> {
  late bool isUploading;
  late bool isProcessing;
  late bool isSaved;
  late File image;
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
  int groupValue = 0;
  int groupWidgetValue = 0;
  bool wallpaperUploaded = false;
  bool secondWidgetAdded = false;
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

  @override
  void initState() {
    super.initState();
    image = widget.arguments![0] as File;
    isUploading = false;
    isProcessing = true;
    isSaved = false;
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
        tempid = tempid! + ran.toString();
      } else {
        final ran = r.nextInt(26);
        tempid = tempid! + alp[ran].toString();
      }
    }
    setState(() {
      id = tempid;
    });
    logger.d(id);
  }

  Future processImage() async {
    imageBytes = await image.readAsBytes();
    await uploadFile();
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
                imageURL = value.content!.downloadUrl;
              }));
      logger.d('File Uploaded');
      setState(() {
        isUploading = false;
      });
    } catch (e) {
      logger.d(e.toString());
      Navigator.pop(context);
      navStack.removeLast();
      logger.d(navStack.toString());
      toasts.error("Some uploading issue, please try again.");
    }
  }

  Future<bool> onWillPop() async {
    if (navStack.length > 1) navStack.removeLast();
    logger.d(navStack.toString());
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
                      setState(() {
                        isSaved = true;
                      });
                      WallStore.createDraftSetup(
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
                      );
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
                        logger.d(navStack.toString());
                        Navigator.pop(context);
                        analytics.logEvent(
                            name: 'upload_setup',
                            parameters: {'id': id, 'link': imageURL});
                        WallStore.createSetup(
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
                        Navigator.pushNamed(context, reviewRoute);
                      }
                    }
                  : null,
              child: Text(
                "Post",
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
                      child: Image.network(
                          globals.prismUser.profilePhoto.toString())),
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
                        labelText: "* Write setup Name...",
                        hintText: "* Write setup Name...",
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
                            suffixIcon: IconButton(
                              onPressed: () {
                                bool fetched = false;
                                bool loading = true;
                                List icons = [];
                                List allIcons = [];
                                showModalBottomSheet(
                                  context: context,
                                  isScrollControlled: true,
                                  enableDrag: true,
                                  backgroundColor: Colors.transparent,
                                  shape: const RoundedRectangleBorder(
                                    borderRadius: BorderRadius.only(
                                      topLeft: Radius.circular(24),
                                      topRight: Radius.circular(24),
                                    ),
                                  ),
                                  builder: (context) => GestureDetector(
                                    onTap: () => Navigator.of(context).pop(),
                                    child: Container(
                                        color: const Color.fromRGBO(
                                            0, 0, 0, 0.001),
                                        child: GestureDetector(
                                            onTap: () {},
                                            child: DraggableScrollableSheet(
                                              initialChildSize: 0.8,
                                              minChildSize: 0.4,
                                              builder: (context, controller) =>
                                                  StatefulBuilder(
                                                builder: (BuildContext context,
                                                    StateSetter setState) {
                                                  if (!fetched) {
                                                    final Box box =
                                                        Hive.box('appsCache');
                                                    setState(() {
                                                      fetched = true;
                                                      icons = (box.get('icons',
                                                                  defaultValue: {})
                                                              as Map)
                                                          .values
                                                          .toList();
                                                      allIcons = (box.get(
                                                                  'icons',
                                                                  defaultValue: {})
                                                              as Map)
                                                          .values
                                                          .toList();
                                                      if (icons.isNotEmpty) {
                                                        loading = false;
                                                      }
                                                    });
                                                    getIcons().then(
                                                        (value) => setState(() {
                                                              icons = value;
                                                              allIcons = value;
                                                              loading = false;
                                                            }));
                                                  }
                                                  return Container(
                                                    decoration: BoxDecoration(
                                                      color: Theme.of(context)
                                                          .primaryColor,
                                                      borderRadius:
                                                          const BorderRadius
                                                              .only(
                                                        topLeft:
                                                            Radius.circular(24),
                                                        topRight:
                                                            Radius.circular(24),
                                                      ),
                                                    ),
                                                    child: Column(
                                                        mainAxisSize:
                                                            MainAxisSize.min,
                                                        crossAxisAlignment:
                                                            CrossAxisAlignment
                                                                .start,
                                                        children: [
                                                          Center(
                                                            child: Container(
                                                              margin:
                                                                  const EdgeInsets
                                                                          .all(
                                                                      16.0),
                                                              width: 32,
                                                              height: 6,
                                                              decoration:
                                                                  BoxDecoration(
                                                                color: Theme.of(
                                                                        context)
                                                                    .textTheme
                                                                    .bodyText1!
                                                                    .color!
                                                                    .withOpacity(
                                                                        0.1),
                                                                borderRadius:
                                                                    BorderRadius
                                                                        .circular(
                                                                            5000),
                                                              ),
                                                            ),
                                                          ),
                                                          if (loading)
                                                            const Padding(
                                                              padding:
                                                                  EdgeInsets
                                                                      .all(
                                                                          16.0),
                                                              child: Center(
                                                                child:
                                                                    CircularProgressIndicator(),
                                                              ),
                                                            )
                                                          else
                                                            Column(
                                                              mainAxisSize:
                                                                  MainAxisSize
                                                                      .min,
                                                              children: [
                                                                Padding(
                                                                  padding:
                                                                      const EdgeInsets
                                                                              .all(
                                                                          16.0),
                                                                  child:
                                                                      TextField(
                                                                    onSubmitted:
                                                                        (query) {
                                                                      query = query
                                                                          .toLowerCase();
                                                                      icons =
                                                                          allIcons;
                                                                      if (query !=
                                                                          '') {
                                                                        icons = icons
                                                                            .where((e) =>
                                                                                (e as Map)["name"].toString().trim().toLowerCase().contains(query))
                                                                            .toList();
                                                                      }
                                                                      setState(
                                                                          () =>
                                                                              {});
                                                                    },
                                                                    onChanged:
                                                                        (query) {
                                                                      query = query
                                                                          .toLowerCase();
                                                                      icons =
                                                                          allIcons;
                                                                      if (query !=
                                                                          '') {
                                                                        icons = icons
                                                                            .where((e) =>
                                                                                (e as Map)["name"].toString().trim().toLowerCase().contains(query))
                                                                            .toList();
                                                                      }
                                                                      setState(
                                                                          () =>
                                                                              {});
                                                                    },
                                                                    style: Theme.of(
                                                                            context)
                                                                        .textTheme
                                                                        .bodyText1!
                                                                        .copyWith(
                                                                            fontSize:
                                                                                16),
                                                                    decoration:
                                                                        InputDecoration(
                                                                      prefixIcon:
                                                                          const Icon(
                                                                              Icons.search),
                                                                      hintText:
                                                                          "Search Icons",
                                                                      hintStyle: Theme.of(
                                                                              context)
                                                                          .textTheme
                                                                          .bodyText1!
                                                                          .copyWith(
                                                                            fontSize:
                                                                                16,
                                                                            color:
                                                                                Theme.of(context).textTheme.bodyText1!.color!.withOpacity(0.6),
                                                                          ),
                                                                    ),
                                                                  ),
                                                                ),
                                                                SizedBox(
                                                                  height: MediaQuery.of(context)
                                                                              .size
                                                                              .height *
                                                                          1 -
                                                                      119,
                                                                  child: ListView
                                                                      .separated(
                                                                    separatorBuilder:
                                                                        (context,
                                                                                index) =>
                                                                            const Divider(
                                                                      height: 2,
                                                                    ),
                                                                    shrinkWrap:
                                                                        true,
                                                                    controller:
                                                                        controller,
                                                                    itemCount:
                                                                        icons.length +
                                                                            1,
                                                                    itemBuilder: (context,
                                                                            index) =>
                                                                        (index ==
                                                                                icons.length)
                                                                            ? const ListTile(
                                                                                title: SizedBox(
                                                                                  height: 60,
                                                                                ),
                                                                              )
                                                                            : ListTile(
                                                                                onTap: () {
                                                                                  iconName.text = (icons[index] as Map)["name"].toString().trim();
                                                                                  iconURL.text = (icons[index] as Map)["link"].toString().trim();
                                                                                  Navigator.pop(context);
                                                                                },
                                                                                leading: ClipRRect(
                                                                                  borderRadius: BorderRadius.circular(8),
                                                                                  child: CachedNetworkImage(
                                                                                    imageUrl: (icons[index] as Map)["icon"].toString(),
                                                                                    width: 38,
                                                                                    height: 38,
                                                                                    fit: BoxFit.cover,
                                                                                  ),
                                                                                ),
                                                                                title: Text(
                                                                                  (icons[index] as Map)["name"].toString().trim(),
                                                                                  style: TextStyle(
                                                                                    color: Theme.of(context).accentColor,
                                                                                    fontSize: 16,
                                                                                    fontFamily: "Proxima Nova",
                                                                                    fontWeight: FontWeight.normal,
                                                                                  ),
                                                                                ),
                                                                                subtitle: Text(
                                                                                  (icons[index] as Map)["id"].toString().trim(),
                                                                                  style: TextStyle(
                                                                                    color: Theme.of(context).accentColor.withOpacity(0.5),
                                                                                    fontSize: 12,
                                                                                    fontFamily: "Proxima Nova",
                                                                                    fontWeight: FontWeight.normal,
                                                                                  ),
                                                                                ),
                                                                              ),
                                                                  ),
                                                                )
                                                              ],
                                                            ),
                                                        ]),
                                                  );
                                                },
                                              ),
                                            ))),
                                  ),
                                );
                              },
                              icon: Icon(
                                JamIcons.search,
                                color: Theme.of(context).accentColor,
                              ),
                            ),
                          ),
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
                          onPressed: wallpaperUploaded == true
                              ? null
                              : () async {
                                  final pickedFile = await ImagePicker()
                                      .getImage(source: ImageSource.gallery);
                                  if (pickedFile != null) {
                                    Future.delayed(const Duration())
                                        .then((value) async {
                                      final argumentsFromWall =
                                          await Navigator.pushNamed(
                                              context, uploadWallRoute,
                                              arguments: [
                                            File(pickedFile.path),
                                            true
                                          ]);
                                      if (argumentsFromWall != null) {
                                        final List argsC =
                                            argumentsFromWall as List;
                                        if (argsC.length == 2) {
                                          setState(() {
                                            wallpaperUploadLink =
                                                argsC[0].toString();
                                            wallpaperId = argsC[1].toString();
                                            wallpaperUploaded = true;
                                          });
                                        }
                                      }
                                    });
                                  }
                                },
                          label: Text(
                            wallpaperUploaded == true ? "Uploaded" : "Upload",
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
              "If you are using a wallpaper from Prism, just click link and paste the share link of wallpaper there.",
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
