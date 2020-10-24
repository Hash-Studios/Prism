import 'dart:io';
import 'dart:math';
import 'package:Prism/analytics/analytics_service.dart';
import 'package:Prism/theme/jam_icons_icons.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
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
      final StorageReference storageReference =
          FirebaseStorage.instance.ref().child(Path.basename(image.path));
      final StorageUploadTask uploadTask = storageReference.putFile(image);
      await uploadTask.onComplete;
      debugPrint('File Uploaded');
      storageReference.getDownloadURL().then((fileURL) {
        setState(() {
          imageURL = fileURL.toString();
          isUploading = false;
        });
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
                        ? config.Colors().mainAccentColor(1)
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
                        : Image.network(
                            main.prefs.get("googleimage").toString()),
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
                  child: Container(
                    padding: const EdgeInsets.all(20.0),
                    height: 200,
                    width: 120,
                    child: Image.file(image, fit: BoxFit.contain),
                  ),
                )
              ],
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
              onTap: () {},
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
            ListTile(
              title: Text(
                "Note - We have a strong review policy, and submitting irrelevant images and information will lead to a permanent ban. Your setup will be visible in the setups section of the app after review.",
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w100,
                  color: Theme.of(context).accentColor.withOpacity(0.6),
                ),
              ),
            )
          ])
          // body: SingleChildScrollView(
          //   physics: const ScrollPhysics(),
          //   child: Container(
          //     height: MediaQuery.of(context).size.height * 0.9,
          //     child: Column(
          //       children: <Widget>[
          //         ClipRRect(
          //           child: Container(
          //             color: Theme.of(context).hintColor,
          //             width: MediaQuery.of(context).size.width,
          //             height: MediaQuery.of(context).size.width / 1.5,
          //             child: PhotoView(
          //               imageProvider: FileImage(image),
          //               backgroundDecoration: BoxDecoration(
          //                 color: Theme.of(context).hintColor,
          //               ),
          //             ),
          //           ),
          //         ),
          //         Container(
          //           height: MediaQuery.of(context).size.height -
          //               MediaQuery.of(context).size.width / 0.8,
          //           child: Scrollbar(
          //             controller: _scrollController,
          //             isAlwaysShown: true,
          //             child: ListView(
          //               controller: _scrollController,
          //               children: <Widget>[
          //                 InputTextField(
          //                     myController: setupName,
          //                     text: "Setup Name*",
          //                     icon: JamIcons.picture,
          //                     initialText: null),
          //                 InputTextField(
          //                     myController: setupDesc,
          //                     text: "Setup Description*",
          //                     icon: JamIcons.color,
          //                     initialText: null),
          //                 InputTextField(
          //                     myController: wallpaperUrl,
          //                     text: "Wallpaper URL*",
          //                     icon: JamIcons.instant_picture,
          //                     initialText: null),
          //                 InputTextField(
          //                     myController: iconName,
          //                     text: "Icon Pack Name*",
          //                     icon: JamIcons.google_play_circle,
          //                     initialText: null),
          //                 InputTextField(
          //                     myController: iconURL,
          //                     text: "Icon Pack Play Store URL*",
          //                     icon: JamIcons.link,
          //                     initialText: null),
          //                 InputTextField(
          //                     myController: widgetName,
          //                     text: "Widget Name",
          //                     icon: JamIcons.google_play,
          //                     initialText: null),
          //                 InputTextField(
          //                     myController: widgetURL,
          //                     text: "Widget Play Store URL",
          //                     icon: JamIcons.link,
          //                     initialText: null),
          //               ],
          //             ),
          //           ),
          //         ),
          //         if (isUploading)
          //           Padding(
          //             padding: const EdgeInsets.only(top: 8, bottom: 12.0),
          //             child: Text(
          //               "Uploading...",
          //               textAlign: TextAlign.center,
          //               style: TextStyle(
          //                 fontSize: 16,
          //                 color: Theme.of(context).accentColor,
          //               ),
          //             ),
          //           )
          //         else
          //           Container(),
          //         if (isProcessing)
          //           Padding(
          //             padding: const EdgeInsets.only(bottom: 12.0),
          //             child: Text(
          //               "Processing...",
          //               textAlign: TextAlign.center,
          //               style: TextStyle(
          //                 fontSize: 16,
          //                 color: Theme.of(context).accentColor,
          //               ),
          //             ),
          //           )
          //         else
          //           Container(),
          //         if (isProcessing || isUploading)
          //           Container(
          //               width: MediaQuery.of(context).size.width / 2,
          //               child: ClipRRect(
          //                   borderRadius: BorderRadius.circular(500),
          //                   child: LinearProgressIndicator(
          //                     backgroundColor: Theme.of(context).hintColor,
          //                     valueColor: AlwaysStoppedAnimation<Color>(
          //                         config.Colors().mainAccentColor(1)),
          //                   )))
          //         else
          //           Container(),
          //         const Spacer(),
          //         Container(
          //           width: MediaQuery.of(context).size.width * 0.6,
          //           child: Text(
          //             "*Required Fields",
          //             textAlign: TextAlign.center,
          //             style: TextStyle(
          //               fontSize: 14,
          //               color: Theme.of(context).accentColor.withOpacity(0.7),
          //             ),
          //           ),
          //         ),
          //         Padding(
          //           padding: const EdgeInsets.fromLTRB(0, 0, 0, 16),
          //           child: Row(
          //             children: <Widget>[
          //               Container(
          //                 width: MediaQuery.of(context).size.width * 0.2,
          //                 child: Center(
          //                   child: Icon(
          //                     JamIcons.info,
          //                     color:
          //                         Theme.of(context).accentColor.withOpacity(0.6),
          //                   ),
          //                 ),
          //               ),
          //               Container(
          //                 width: MediaQuery.of(context).size.width * 0.6,
          //                 child: Padding(
          //                   padding: const EdgeInsets.all(8.0),
          //                   child: Center(
          //                     child: Text(
          //                       main.prefs.get('premium') == true
          //                           ? "Note - We have a strong review policy, and submitting irrelevant images & info will lead to ban. Your photo will be visible in the profile/community section."
          //                           : "Note - We have a strong review policy, and submitting irrelevant images & info will lead to ban. We take about 24 hours to review the submissions, and after a successful review, your setup will be visible in the setups section.",
          //                       textAlign: TextAlign.center,
          // style: TextStyle(
          //   fontSize: 10,
          //   color: Theme.of(context)
          //       .accentColor
          //       .withOpacity(0.6),
          // ),
          //                     ),
          //                   ),
          //                 ),
          //               ),
          //             ],
          //           ),
          //         )
          //       ],
          //     ),
          //   ),
          // ),
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
              color: config.Colors().mainAccentColor(1).withOpacity(0.5),
            ),
            border: InputBorder.none,
            focusedBorder: InputBorder.none,
            enabledBorder: InputBorder.none,
            errorBorder: InputBorder.none,
            disabledBorder: InputBorder.none,
            prefixIcon: Icon(
              widget.icon,
              color: config.Colors().mainAccentColor(1),
            ),
          ),
        ),
      ),
    );
  }
}
