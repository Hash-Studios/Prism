import 'dart:convert';
import 'dart:io';

import 'package:Prism/analytics/analytics_service.dart';
import 'package:Prism/core/analytics/events/events.dart';
import 'package:Prism/core/firestore/firestore_document.dart';
import 'package:Prism/core/router/app_router.dart';
import 'package:Prism/core/state/app_state.dart' as app_state;
import 'package:Prism/data/apps/app_icon.dart';
import 'package:Prism/data/apps/appsData.dart';
import 'package:Prism/data/upload/wallpaper/wallfirestore.dart' as WallStore;
import 'package:Prism/env/env.dart';
import 'package:Prism/logger/logger.dart';
import 'package:Prism/theme/jam_icons_icons.dart';
import 'package:Prism/theme/toasts.dart' as toasts;
import 'package:auto_route/auto_route.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:github/github.dart';
import 'package:hive_io/hive_io.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path/path.dart' as Path;

@RoutePage()
class EditSetupReviewScreen extends StatefulWidget {
  const EditSetupReviewScreen({super.key, required this.setupDoc});

  final FirestoreDocument setupDoc;

  @override
  _EditSetupReviewScreenState createState() => _EditSetupReviewScreenState();
}

class _EditSetupReviewScreenState extends State<EditSetupReviewScreen> {
  late bool isUploading;
  late bool isProcessing;
  late File image;
  late FirestoreDocument setupDoc;
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
    setupDoc = widget.setupDoc;
    final wallpaperValue = setupDoc.setupWallpaperValue;
    final String wallpaperUrlText = wallpaperValue.raw;
    imageURL = setupDoc.image;
    groupWidgetValue = 0;
    setupName = TextEditingController(text: setupDoc.name);
    id = setupDoc.id;
    setupDesc = TextEditingController(text: setupDoc.desc);
    iconName = TextEditingController(text: setupDoc.icon);
    iconURL = TextEditingController(text: setupDoc.iconUrl);
    widgetName1 = TextEditingController(text: setupDoc.widget);
    widgetURL1 = TextEditingController(text: setupDoc.widgetUrl);
    if (wallpaperUrlText.isNotEmpty) {
      if (!wallpaperValue.isEncoded) {
        if (setupDoc.wallId.isNotEmpty) {
          wallpaperUploaded = true;
          wallpaperUploadLink = wallpaperValue.primaryUrl;
          wallpaperId = setupDoc.wallId;
          groupValue = 1;
        } else {
          wallpaperUrl = TextEditingController(text: wallpaperValue.primaryUrl);
          groupValue = 0;
        }
      } else {
        wallpaperAppName = TextEditingController(text: wallpaperValue.title ?? "");
        wallpaperAppWallName = TextEditingController(text: wallpaperValue.subtitle ?? "");
        wallpaperAppLink = TextEditingController(text: wallpaperValue.deepLinkUrl ?? "");
        groupValue = 2;
      }
    } else {
      wallpaperUrl = TextEditingController(text: wallpaperUrlText);
      groupValue = 0;
    }
    widgetName2 = TextEditingController(text: setupDoc.widget2);
    widgetURL2 = TextEditingController(text: setupDoc.widgetUrl2);
    isUploading = false;
    isProcessing = false;
    wallpaperProvider = setupDoc.wallpaperProvider;
    wallpaperThumb = setupDoc.wallpaperThumb;
    review = setupDoc.review;
    secondWidgetAdded = setupDoc.widget2.isNotEmpty;
  }

  final Map<int, Widget> logoWidgets = <int, Widget>{
    0: const Padding(
      padding: EdgeInsets.all(4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        mainAxisSize: MainAxisSize.min,
        children: [Icon(JamIcons.link), Text("Link")],
      ),
    ),
    1: const Padding(
      padding: EdgeInsets.all(4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        mainAxisSize: MainAxisSize.min,
        children: [Icon(JamIcons.upload), Text("Upload")],
      ),
    ),
    2: const Padding(
      padding: EdgeInsets.all(4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        mainAxisSize: MainAxisSize.min,
        children: [Icon(JamIcons.android), Text("App")],
      ),
    ),
  };
  final Map<int, Widget> widgetsIcons = <int, Widget>{
    0: const Padding(
      padding: EdgeInsets.all(4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        mainAxisSize: MainAxisSize.min,
        children: [Icon(JamIcons.google_play), Text("Widgets")],
      ),
    ),
    1: const Padding(
      padding: EdgeInsets.all(4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        mainAxisSize: MainAxisSize.min,
        children: [Icon(JamIcons.google_play_circle), Text("* Icons")],
      ),
    ),
  };

  Future pickImage() async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: ImageSource.gallery);
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
      final github = GitHub(auth: Authentication.withToken(Env.normalize(Env.ghToken)));
      await github.repositories
          .createFile(
            RepositorySlug(Env.normalize(Env.ghUserName), Env.normalize(Env.ghRepoSetups)),
            CreateFile(message: Path.basename(image.path), content: base64Image, path: Path.basename(image.path)),
          )
          .then(
            (value) => setState(() {
              imageURL = value.content!.downloadUrl;
            }),
          );
      logger.d('File Uploaded');
      setState(() {
        isUploading = false;
      });
    } catch (e) {
      logger.d(e.toString());
      Navigator.pop(context);
      toasts.error("Some uploading issue, please try again.");
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).primaryColor,
      appBar: AppBar(
        title: Text("Edit Setup", style: TextStyle(color: Theme.of(context).colorScheme.secondary)),
        actions: [
          TextButton(
            onPressed: !isProcessing && !isUploading
                ? () async {
                    if (setupName.text == "" ||
                        setupDesc.text == "" ||
                        (wallpaperUploaded == false &&
                            (wallpaperUrl.text == "") &&
                            ((wallpaperAppLink.text == "") || (wallpaperAppName.text == ""))) ||
                        iconName.text == "" ||
                        iconURL.text == "") {
                      toasts.error("Please fill all required fields!");
                    } else {
                      Navigator.pop(context);
                      analytics.track(EditSetupEvent(setupId: id ?? '', link: imageURL ?? ''));
                      WallStore.updateSetup(
                        setupDoc.id,
                        id,
                        imageURL,
                        wallpaperProvider,
                        wallpaperThumb,
                        wallpaperUploaded == true
                            ? wallpaperUploadLink
                            : wallpaperAppName.text != "" && wallpaperAppLink.text != ""
                            ? [wallpaperAppName.text, wallpaperAppLink.text, wallpaperAppWallName.text]
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
              "Post",
              style: TextStyle(
                color: !isProcessing && !isUploading
                    ? Theme.of(context).colorScheme.error == Colors.black
                          ? Colors.white
                          : Theme.of(context).colorScheme.error
                    : Theme.of(context).hintColor,
                fontWeight: FontWeight.normal,
              ),
            ),
          ),
        ],
      ),
      body: ListView(
        children: [
          Row(
            children: [
              Padding(
                padding: const EdgeInsets.all(20.0),
                child: CircleAvatar(
                  backgroundColor: Theme.of(context).colorScheme.error,
                  radius: 20,
                  child: ClipOval(child: Image.network(app_state.prismUser.profilePhoto)),
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
                        color: Theme.of(context).colorScheme.secondary,
                      ),
                      decoration: InputDecoration(
                        labelText: "* Write a Name...",
                        hintText: "* Write a Name...",
                        hintStyle: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.normal,
                          color: Theme.of(context).colorScheme.secondary,
                        ),
                        labelStyle: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.normal,
                          color: Theme.of(context).colorScheme.secondary,
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
                        color: Theme.of(context).colorScheme.secondary,
                      ),
                      decoration: InputDecoration(
                        labelText: "* Write a description... (50 chars only)",
                        hintText: "* Write a description... (50 chars only)",
                        hintStyle: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.normal,
                          color: Theme.of(context).colorScheme.secondary,
                        ),
                        labelStyle: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.normal,
                          color: Theme.of(context).colorScheme.secondary,
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
                      child: CachedNetworkImage(imageUrl: imageURL!, fit: BoxFit.contain),
                    ),
                    if (isUploading || isProcessing)
                      Container(
                        padding: const EdgeInsets.all(20.0),
                        height: 200,
                        width: 120,
                        child: Center(
                          child: CircularProgressIndicator(
                            valueColor: AlwaysStoppedAnimation<Color>(Theme.of(context).colorScheme.error),
                          ),
                        ),
                      )
                    else
                      Container(),
                  ],
                ),
              ),
            ],
          ),
          const Divider(height: 1),
          ExpansionTile(
            title: Text(
              "Add widgets, icon packs",
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.normal,
                color: Theme.of(context).colorScheme.secondary,
              ),
            ),
            children: [
              Padding(
                padding: const EdgeInsets.all(8.0),
                child: CupertinoSegmentedControl(
                  children: widgetsIcons,
                  groupValue: groupWidgetValue,
                  borderColor: Theme.of(context).colorScheme.secondary,
                  pressedColor: Theme.of(context).hintColor,
                  unselectedColor: Theme.of(context).primaryColor,
                  selectedColor: Theme.of(context).colorScheme.secondary,
                  padding: EdgeInsets.zero,
                  onValueChanged: (int val) {
                    setState(() {
                      groupWidgetValue = val;
                    });
                  },
                ),
              ),
              if (groupWidgetValue == 0)
                Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
                      child: Container(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(500),
                          color: Theme.of(context).hintColor,
                        ),
                        child: TextField(
                          cursorColor: Theme.of(context).colorScheme.error,
                          style: Theme.of(
                            context,
                          ).textTheme.headlineSmall!.copyWith(color: Theme.of(context).colorScheme.secondary),
                          controller: widgetName1,
                          focusNode: textFocusNode,
                          decoration: InputDecoration(
                            contentPadding: const EdgeInsets.only(left: 30, top: 15),
                            border: InputBorder.none,
                            disabledBorder: InputBorder.none,
                            enabledBorder: InputBorder.none,
                            focusedBorder: InputBorder.none,
                            hintText: "Write widget app name...",
                            hintStyle: Theme.of(
                              context,
                            ).textTheme.headlineSmall!.copyWith(color: Theme.of(context).colorScheme.secondary),
                            suffixIcon: Icon(JamIcons.android, color: Theme.of(context).colorScheme.secondary),
                          ),
                        ),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
                      child: Container(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(500),
                          color: Theme.of(context).hintColor,
                        ),
                        child: TextField(
                          cursorColor: Theme.of(context).colorScheme.error,
                          style: Theme.of(
                            context,
                          ).textTheme.headlineSmall!.copyWith(color: Theme.of(context).colorScheme.secondary),
                          controller: widgetURL1,
                          focusNode: textFocusNode,
                          decoration: InputDecoration(
                            contentPadding: const EdgeInsets.only(left: 30, top: 15),
                            border: InputBorder.none,
                            disabledBorder: InputBorder.none,
                            enabledBorder: InputBorder.none,
                            focusedBorder: InputBorder.none,
                            hintText: "Write widget app link...",
                            hintStyle: Theme.of(
                              context,
                            ).textTheme.headlineSmall!.copyWith(color: Theme.of(context).colorScheme.secondary),
                            suffixIcon: Icon(JamIcons.google_play, color: Theme.of(context).colorScheme.secondary),
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
                            color: Theme.of(context).hintColor,
                          ),
                          child: TextField(
                            cursorColor: Theme.of(context).colorScheme.error,
                            style: Theme.of(
                              context,
                            ).textTheme.headlineSmall!.copyWith(color: Theme.of(context).colorScheme.secondary),
                            controller: widgetName2,
                            focusNode: textFocusNode,
                            decoration: InputDecoration(
                              contentPadding: const EdgeInsets.only(left: 30, top: 15),
                              border: InputBorder.none,
                              disabledBorder: InputBorder.none,
                              enabledBorder: InputBorder.none,
                              focusedBorder: InputBorder.none,
                              hintText: "Write 2nd widget app name...",
                              hintStyle: Theme.of(
                                context,
                              ).textTheme.headlineSmall!.copyWith(color: Theme.of(context).colorScheme.secondary),
                              suffixIcon: Icon(JamIcons.android, color: Theme.of(context).colorScheme.secondary),
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
                        child: Text("Add more widget", style: Theme.of(context).textTheme.bodyMedium),
                      ),
                    if (secondWidgetAdded == true)
                      Padding(
                        padding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
                        child: Container(
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(500),
                            color: Theme.of(context).hintColor,
                          ),
                          child: TextField(
                            cursorColor: Theme.of(context).colorScheme.error,
                            style: Theme.of(
                              context,
                            ).textTheme.headlineSmall!.copyWith(color: Theme.of(context).colorScheme.secondary),
                            controller: widgetURL2,
                            focusNode: textFocusNode,
                            decoration: InputDecoration(
                              contentPadding: const EdgeInsets.only(left: 30, top: 15),
                              border: InputBorder.none,
                              disabledBorder: InputBorder.none,
                              enabledBorder: InputBorder.none,
                              focusedBorder: InputBorder.none,
                              hintText: "Write 2nd widget app link...",
                              hintStyle: Theme.of(
                                context,
                              ).textTheme.headlineSmall!.copyWith(color: Theme.of(context).colorScheme.secondary),
                              suffixIcon: Icon(JamIcons.google_play, color: Theme.of(context).colorScheme.secondary),
                            ),
                          ),
                        ),
                      )
                    else
                      Container(),
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
                          color: Theme.of(context).hintColor,
                        ),
                        child: TextField(
                          cursorColor: Theme.of(context).colorScheme.error,
                          style: Theme.of(
                            context,
                          ).textTheme.headlineSmall!.copyWith(color: Theme.of(context).colorScheme.secondary),
                          controller: iconName,
                          focusNode: textFocusNode,
                          decoration: InputDecoration(
                            contentPadding: const EdgeInsets.only(left: 30, top: 15),
                            border: InputBorder.none,
                            disabledBorder: InputBorder.none,
                            enabledBorder: InputBorder.none,
                            focusedBorder: InputBorder.none,
                            hintText: "Write icon pack name...",
                            hintStyle: Theme.of(
                              context,
                            ).textTheme.headlineSmall!.copyWith(color: Theme.of(context).colorScheme.secondary),
                            suffixIcon: IconButton(
                              onPressed: () {
                                bool fetched = false;
                                bool loading = true;
                                List<AppIcon> icons = <AppIcon>[];
                                List<AppIcon> allIcons = <AppIcon>[];
                                showModalBottomSheet(
                                  context: context,
                                  isScrollControlled: true,
                                  backgroundColor: Colors.transparent,
                                  shape: const RoundedRectangleBorder(
                                    borderRadius: BorderRadius.only(
                                      topLeft: Radius.circular(24),
                                      topRight: Radius.circular(24),
                                    ),
                                  ),
                                  builder: (context) => GestureDetector(
                                    onTap: () => Navigator.of(context).pop(),
                                    child: ColoredBox(
                                      color: const Color.fromRGBO(0, 0, 0, 0.001),
                                      child: GestureDetector(
                                        onTap: () {},
                                        child: DraggableScrollableSheet(
                                          initialChildSize: 0.8,
                                          minChildSize: 0.4,
                                          builder: (context, controller) => StatefulBuilder(
                                            builder: (BuildContext context, StateSetter setState) {
                                              if (!fetched) {
                                                final Box box = Hive.box('appsCache');
                                                setState(() {
                                                  fetched = true;
                                                  final Object? cachedIcons = box.get('icons', defaultValue: null);
                                                  if (cachedIcons is Map) {
                                                    icons = cachedIcons.values
                                                        .whereType<Map>()
                                                        .map(AppIcon.fromMap)
                                                        .toList(growable: false);
                                                    allIcons = icons;
                                                  }
                                                  if (icons.isNotEmpty) {
                                                    loading = false;
                                                  }
                                                });
                                                getIcons().then(
                                                  (value) => setState(() {
                                                    icons = value;
                                                    allIcons = value;
                                                    loading = false;
                                                  }),
                                                );
                                              }
                                              return Container(
                                                decoration: BoxDecoration(
                                                  color: Theme.of(context).primaryColor,
                                                  borderRadius: const BorderRadius.only(
                                                    topLeft: Radius.circular(24),
                                                    topRight: Radius.circular(24),
                                                  ),
                                                ),
                                                child: Column(
                                                  mainAxisSize: MainAxisSize.min,
                                                  crossAxisAlignment: CrossAxisAlignment.start,
                                                  children: [
                                                    Center(
                                                      child: Container(
                                                        margin: const EdgeInsets.all(16.0),
                                                        width: 32,
                                                        height: 6,
                                                        decoration: BoxDecoration(
                                                          color: Theme.of(
                                                            context,
                                                          ).textTheme.bodyLarge!.color!.withValues(alpha: 0.1),
                                                          borderRadius: BorderRadius.circular(5000),
                                                        ),
                                                      ),
                                                    ),
                                                    if (loading)
                                                      const Padding(
                                                        padding: EdgeInsets.all(16.0),
                                                        child: Center(child: CircularProgressIndicator()),
                                                      )
                                                    else
                                                      Column(
                                                        mainAxisSize: MainAxisSize.min,
                                                        children: [
                                                          Padding(
                                                            padding: const EdgeInsets.all(16.0),
                                                            child: TextField(
                                                              onSubmitted: (query) {
                                                                query = query.toLowerCase();
                                                                icons = List<AppIcon>.from(allIcons);
                                                                if (query != '') {
                                                                  icons = icons
                                                                      .where(
                                                                        (e) =>
                                                                            e.name.trim().toLowerCase().contains(query),
                                                                      )
                                                                      .toList();
                                                                }
                                                                setState(() => {});
                                                              },
                                                              onChanged: (query) {
                                                                query = query.toLowerCase();
                                                                icons = List<AppIcon>.from(allIcons);
                                                                if (query != '') {
                                                                  icons = icons
                                                                      .where(
                                                                        (e) =>
                                                                            e.name.trim().toLowerCase().contains(query),
                                                                      )
                                                                      .toList();
                                                                }
                                                                setState(() => {});
                                                              },
                                                              style: Theme.of(
                                                                context,
                                                              ).textTheme.bodyLarge!.copyWith(fontSize: 16),
                                                              decoration: InputDecoration(
                                                                prefixIcon: const Icon(Icons.search),
                                                                hintText: "Search Icons",
                                                                hintStyle: Theme.of(context).textTheme.bodyLarge!
                                                                    .copyWith(
                                                                      fontSize: 16,
                                                                      color: Theme.of(context)
                                                                          .textTheme
                                                                          .bodyLarge!
                                                                          .color!
                                                                          .withValues(alpha: 0.6),
                                                                    ),
                                                              ),
                                                            ),
                                                          ),
                                                          SizedBox(
                                                            height: MediaQuery.of(context).size.height * 1 - 119,
                                                            child: ListView.separated(
                                                              separatorBuilder: (context, index) =>
                                                                  const Divider(height: 2),
                                                              shrinkWrap: true,
                                                              controller: controller,
                                                              itemCount: icons.length + 1,
                                                              itemBuilder: (context, index) => (index == icons.length)
                                                                  ? const ListTile(title: SizedBox(height: 60))
                                                                  : ListTile(
                                                                      onTap: () {
                                                                        iconName.text = icons[index].name.trim();
                                                                        iconURL.text = icons[index].link.trim();
                                                                        Navigator.pop(context);
                                                                      },
                                                                      leading: ClipRRect(
                                                                        borderRadius: BorderRadius.circular(8),
                                                                        child: CachedNetworkImage(
                                                                          imageUrl: icons[index].iconUrl,
                                                                          width: 38,
                                                                          height: 38,
                                                                          fit: BoxFit.cover,
                                                                        ),
                                                                      ),
                                                                      title: Text(
                                                                        icons[index].name.trim(),
                                                                        style: TextStyle(
                                                                          color: Theme.of(
                                                                            context,
                                                                          ).colorScheme.secondary,
                                                                          fontSize: 16,
                                                                          fontFamily: "Proxima Nova",
                                                                          fontWeight: FontWeight.normal,
                                                                        ),
                                                                      ),
                                                                      subtitle: Text(
                                                                        icons[index].id.trim(),
                                                                        style: TextStyle(
                                                                          color: Theme.of(context).colorScheme.secondary
                                                                              .withValues(alpha: 0.5),
                                                                          fontSize: 12,
                                                                          fontFamily: "Proxima Nova",
                                                                          fontWeight: FontWeight.normal,
                                                                        ),
                                                                      ),
                                                                    ),
                                                            ),
                                                          ),
                                                        ],
                                                      ),
                                                  ],
                                                ),
                                              );
                                            },
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                );
                              },
                              icon: Icon(JamIcons.search, color: Theme.of(context).colorScheme.secondary),
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
                          color: Theme.of(context).hintColor,
                        ),
                        child: TextField(
                          cursorColor: Theme.of(context).colorScheme.error,
                          style: Theme.of(
                            context,
                          ).textTheme.headlineSmall!.copyWith(color: Theme.of(context).colorScheme.secondary),
                          controller: iconURL,
                          focusNode: textFocusNode,
                          decoration: InputDecoration(
                            contentPadding: const EdgeInsets.only(left: 30, top: 15),
                            border: InputBorder.none,
                            disabledBorder: InputBorder.none,
                            enabledBorder: InputBorder.none,
                            focusedBorder: InputBorder.none,
                            hintText: "Write icon app link...",
                            hintStyle: Theme.of(
                              context,
                            ).textTheme.headlineSmall!.copyWith(color: Theme.of(context).colorScheme.secondary),
                            suffixIcon: Icon(
                              JamIcons.google_play_circle,
                              color: Theme.of(context).colorScheme.secondary,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
            ],
          ),
          const Divider(height: 1),
          ExpansionTile(
            title: Text(
              "* Add wallpaper",
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.normal,
                color: Theme.of(context).colorScheme.secondary,
              ),
            ),
            children: [
              Padding(
                padding: const EdgeInsets.all(8.0),
                child: CupertinoSegmentedControl(
                  children: logoWidgets,
                  groupValue: groupValue,
                  borderColor: Theme.of(context).colorScheme.secondary,
                  pressedColor: Theme.of(context).hintColor,
                  unselectedColor: Theme.of(context).primaryColor,
                  selectedColor: Theme.of(context).colorScheme.secondary,
                  padding: EdgeInsets.zero,
                  onValueChanged: (int val) {
                    setState(() {
                      groupValue = val;
                    });
                  },
                ),
              ),
              if (groupValue == 0)
                Padding(
                  padding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
                  child: Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(500),
                      color: Theme.of(context).hintColor,
                    ),
                    child: TextField(
                      cursorColor: Theme.of(context).colorScheme.error,
                      style: Theme.of(
                        context,
                      ).textTheme.headlineSmall!.copyWith(color: Theme.of(context).colorScheme.secondary),
                      controller: wallpaperUrl,
                      focusNode: textFocusNode,
                      decoration: InputDecoration(
                        contentPadding: const EdgeInsets.only(left: 30, top: 15),
                        border: InputBorder.none,
                        disabledBorder: InputBorder.none,
                        enabledBorder: InputBorder.none,
                        focusedBorder: InputBorder.none,
                        hintText: "Write wallpaper link...",
                        hintStyle: Theme.of(
                          context,
                        ).textTheme.headlineSmall!.copyWith(color: Theme.of(context).colorScheme.secondary),
                        suffixIcon: Icon(JamIcons.picture, color: Theme.of(context).colorScheme.secondary),
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
                              : Theme.of(context).colorScheme.error,
                          onPressed: () async {
                            final pickedFile = await ImagePicker().pickImage(source: ImageSource.gallery);
                            if (pickedFile != null) {
                              Future.delayed(Duration.zero).then((value) async {
                                final argumentsFromWall = await context.router.push(
                                  UploadWallRoute(image: File(pickedFile.path), fromSetupRoute: true),
                                );
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
                            wallpaperUploaded == true ? "Change Wall" : "Upload",
                            style: TextStyle(
                              color: Theme.of(context).colorScheme.secondary,
                              fontWeight: FontWeight.normal,
                            ),
                          ),
                          icon: Icon(JamIcons.upload, color: Theme.of(context).colorScheme.secondary),
                        ),
                      )
                    : Column(
                        children: [
                          Padding(
                            padding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
                            child: Container(
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(500),
                                color: Theme.of(context).hintColor,
                              ),
                              child: TextField(
                                cursorColor: Theme.of(context).colorScheme.error,
                                style: Theme.of(
                                  context,
                                ).textTheme.headlineSmall!.copyWith(color: Theme.of(context).colorScheme.secondary),
                                controller: wallpaperAppName,
                                focusNode: textFocusNode,
                                decoration: InputDecoration(
                                  contentPadding: const EdgeInsets.only(left: 30, top: 15),
                                  border: InputBorder.none,
                                  disabledBorder: InputBorder.none,
                                  enabledBorder: InputBorder.none,
                                  focusedBorder: InputBorder.none,
                                  hintText: "Write wallpaper app name...",
                                  hintStyle: Theme.of(
                                    context,
                                  ).textTheme.headlineSmall!.copyWith(color: Theme.of(context).colorScheme.secondary),
                                  suffixIcon: Icon(JamIcons.android, color: Theme.of(context).colorScheme.secondary),
                                ),
                              ),
                            ),
                          ),
                          Padding(
                            padding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
                            child: Container(
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(500),
                                color: Theme.of(context).hintColor,
                              ),
                              child: TextField(
                                cursorColor: Theme.of(context).colorScheme.error,
                                style: Theme.of(
                                  context,
                                ).textTheme.headlineSmall!.copyWith(color: Theme.of(context).colorScheme.secondary),
                                controller: wallpaperAppLink,
                                focusNode: textFocusNode,
                                decoration: InputDecoration(
                                  contentPadding: const EdgeInsets.only(left: 30, top: 15),
                                  border: InputBorder.none,
                                  disabledBorder: InputBorder.none,
                                  enabledBorder: InputBorder.none,
                                  focusedBorder: InputBorder.none,
                                  hintText: "Write app link...",
                                  hintStyle: Theme.of(
                                    context,
                                  ).textTheme.headlineSmall!.copyWith(color: Theme.of(context).colorScheme.secondary),
                                  suffixIcon: Icon(
                                    JamIcons.google_play,
                                    color: Theme.of(context).colorScheme.secondary,
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
                                color: Theme.of(context).hintColor,
                              ),
                              child: TextField(
                                cursorColor: Theme.of(context).colorScheme.error,
                                style: Theme.of(
                                  context,
                                ).textTheme.headlineSmall!.copyWith(color: Theme.of(context).colorScheme.secondary),
                                controller: wallpaperAppWallName,
                                focusNode: textFocusNode,
                                decoration: InputDecoration(
                                  contentPadding: const EdgeInsets.only(left: 30, top: 15),
                                  border: InputBorder.none,
                                  disabledBorder: InputBorder.none,
                                  enabledBorder: InputBorder.none,
                                  focusedBorder: InputBorder.none,
                                  hintText: "Write wallpaper name",
                                  hintStyle: Theme.of(
                                    context,
                                  ).textTheme.headlineSmall!.copyWith(color: Theme.of(context).colorScheme.secondary),
                                  suffixIcon: Icon(JamIcons.picture, color: Theme.of(context).colorScheme.secondary),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
            ],
          ),
          const Divider(height: 1),
          ListTile(
            title: Text(
              "Fields marked with * are required.",
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w100,
                color: Theme.of(context).colorScheme.secondary.withValues(alpha: 0.7),
              ),
            ),
          ),
          const Divider(height: 1),
          ListTile(
            title: Text(
              app_state.prismUser.premium == true
                  ? "Note - We have a strong review policy, and submitting irrelevant images & info will lead to ban. Your setup will be visible in the setups section."
                  : "Note - We have a strong review policy, and submitting irrelevant images & info will lead to ban. We take about 24 hours to review the submissions, and after a successful review, your setup will be visible in the setups section.",
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w100,
                color: Theme.of(context).colorScheme.secondary.withValues(alpha: 0.7),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
