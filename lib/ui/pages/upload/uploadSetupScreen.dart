import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'package:Prism/analytics/analytics_service.dart';
import 'package:Prism/theme/jam_icons_icons.dart';
import 'package:firebase_storage/firebase_storage.dart';
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

class UploadSetupScreen extends StatefulWidget {
  final List arguments;
  UploadSetupScreen({this.arguments});
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
    image = widget.arguments[0];
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
    var alp = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ'.split("");
    var r = new Random();
    var choice = r.nextInt(6);
    for (var i = 0; i < 6; i++) {
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
    imageBytes = await image.readAsBytes();
    uploadFile();
  }

  Future uploadFile() async {
    setState(() {
      isUploading = true;
      isProcessing = false;
    });
    try {
      StorageReference storageReference =
          FirebaseStorage.instance.ref().child('${Path.basename(image.path)}');
      StorageUploadTask uploadTask = storageReference.putFile(image);
      await uploadTask.onComplete;
      print('File Uploaded');
      storageReference.getDownloadURL().then((fileURL) {
        setState(() {
          imageURL = fileURL;
          isUploading = false;
        });
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
    // deleteFile();
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
        ),
        body: SingleChildScrollView(
          physics: ScrollPhysics(),
          child: Container(
            height: MediaQuery.of(context).size.height * 0.9,
            child: Column(
              children: <Widget>[
                ClipRRect(
                  child: Container(
                    color: Theme.of(context).hintColor,
                    width: MediaQuery.of(context).size.width,
                    height: MediaQuery.of(context).size.width / 1.5,
                    child: PhotoView(
                      imageProvider: FileImage(image),
                      backgroundDecoration: BoxDecoration(
                        color: Theme.of(context).hintColor,
                      ),
                    ),
                  ),
                ),
                Container(
                  height: MediaQuery.of(context).size.height -
                      MediaQuery.of(context).size.width / 0.8,
                  child: Scrollbar(
                    controller: _scrollController,
                    isAlwaysShown: true,
                    child: ListView(
                      controller: _scrollController,
                      children: <Widget>[
                        InputTextField(
                            myController: setupName,
                            text: "Setup Name*",
                            icon: JamIcons.picture,
                            initialText: null),
                        InputTextField(
                            myController: setupDesc,
                            text: "Setup Description*",
                            icon: JamIcons.color,
                            initialText: null),
                        InputTextField(
                            myController: wallpaperUrl,
                            text: "Wallpaper URL*",
                            icon: JamIcons.instant_picture,
                            initialText: null),
                        InputTextField(
                            myController: iconName,
                            text: "Icon Pack Name*",
                            icon: JamIcons.google_play_circle,
                            initialText: null),
                        InputTextField(
                            myController: iconURL,
                            text: "Icon Pack Play Store URL*",
                            icon: JamIcons.link,
                            initialText: null),
                        InputTextField(
                            myController: widgetName,
                            text: "Widget Name",
                            icon: JamIcons.google_play,
                            initialText: null),
                        InputTextField(
                            myController: widgetURL,
                            text: "Widget Play Store URL",
                            icon: JamIcons.link,
                            initialText: null),
                      ],
                    ),
                  ),
                ),
                isUploading
                    ? Padding(
                        padding: const EdgeInsets.only(top: 8, bottom: 12.0),
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
                Container(
                  width: MediaQuery.of(context).size.width * 0.6,
                  child: Text(
                    "*Required Fields",
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 14,
                      color: Theme.of(context).accentColor.withOpacity(0.7),
                    ),
                  ),
                ),
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
                            color:
                                Theme.of(context).accentColor.withOpacity(0.6),
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
                                  ? "Note - We have a strong review policy, and submitting irrelevant images & info will lead to ban. Your photo will be visible in the profile/community section."
                                  : "Note - We have a strong review policy, and submitting irrelevant images & info will lead to ban. We take about 24 hours to review the submissions, and after a successful review, your setup will be visible in the setups section.",
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
                    if (setupName.text == "" ||
                        setupDesc.text == "" ||
                        wallpaperUrl.text == "" ||
                        iconName.text == "" ||
                        iconURL.text == "") {
                      toasts.error("Please fill all required fields!");
                    } else {
                      navStack.removeLast();
                      print(navStack);
                      Navigator.pop(context);
                      analytics.logEvent(
                          name: 'upload_setup',
                          parameters: {'id': id, 'link': imageURL});
                      await WallStore.createSetup(
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
                : null),
      ),
    );
  }
}

class InputTextField extends StatefulWidget {
  const InputTextField({
    Key key,
    @required this.myController,
    @required this.text,
    @required this.icon,
    @required this.initialText,
  }) : super(key: key);

  final TextEditingController myController;
  final String text;
  final IconData icon;
  final String initialText;

  @override
  _InputTextFieldState createState() => _InputTextFieldState();
}

class _InputTextFieldState extends State<InputTextField> {
  @override
  void initState() {
    widget.myController.text = widget.initialText;
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(10, 10, 10, 10),
      child: Container(
        width: MediaQuery.of(context).size.width,
        height: 60,
        decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(5.0),
            border: Border.all(width: 2, color: Theme.of(context).accentColor)),
        child: TextField(
          style: TextStyle(
            fontSize: 18,
            fontFamily: "Proxima Nova",
            fontWeight: FontWeight.w700,
            color: Theme.of(context).accentColor,
          ),
          controller: widget.myController,
          decoration: InputDecoration(
            fillColor: Colors.red,
            labelText: widget.text,
            labelStyle: TextStyle(
              fontFamily: "Proxima Nova",
              fontWeight: FontWeight.w700,
              fontSize: 14,
              color: Color(0xFFE57697).withOpacity(0.5),
            ),
            border: InputBorder.none,
            focusedBorder: InputBorder.none,
            enabledBorder: InputBorder.none,
            errorBorder: InputBorder.none,
            disabledBorder: InputBorder.none,
            prefixIcon: Icon(
              widget.icon,
              color: Color(0xFFE57697),
            ),
          ),
        ),
      ),
    );
  }
}
