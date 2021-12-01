import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:Prism/auth/google_auth.dart';
import 'package:Prism/gitkey.dart';
import 'package:Prism/global/globals.dart' as globals;
import 'package:Prism/global/svgAssets.dart';
import 'package:Prism/logger/logger.dart';
import 'package:Prism/main.dart' as main;
import 'package:Prism/routes/router.dart';
import 'package:Prism/theme/jam_icons_icons.dart';
import 'package:Prism/theme/toasts.dart' as toasts;
import 'package:animations/animations.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:github/github.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path/path.dart' as Path;

class EditProfilePanel extends StatefulWidget {
  const EditProfilePanel({
    Key? key,
  }) : super(key: key);

  @override
  _EditProfilePanelState createState() => _EditProfilePanelState();
}

class _EditProfilePanelState extends State<EditProfilePanel> {
  final TextEditingController linkController = TextEditingController();
  late TextEditingController bioController;
  late TextEditingController usernameController;
  late TextEditingController nameController;
  final FirebaseFirestore firestore = FirebaseFirestore.instance;
  bool isLoading = false;
  bool pfpEdit = false;
  bool coverEdit = false;
  bool usernameEdit = false;
  bool nameEdit = false;
  bool bioEdit = false;
  bool linkEdit = false;
  bool enabled = false;
  bool? available;
  bool isCheckingUsername = false;
  File? _pfp;
  File? _cover;
  late List<int> _compressedPFP;
  late List<int> _compressedCover;
  late String pfpSha;
  late String pfpPath;
  late String pfpUrl;
  late String coverSha;
  late String coverPath;
  late String coverUrl;
  final picker2 = ImagePicker();
  List<Map<String, dynamic>> linkIcons = [
    // {
    //   'name': 'Edit links...',
    //   'link': 'Select your link first',
    //   'icon': JamIcons.link,
    //   'value': '',
    //   'validator': '',
    // },
    {
      'name': 'github',
      'link': 'https://github.com/username',
      'icon': JamIcons.github,
      'value': '',
      'validator': 'github',
    },
    {
      'name': 'twitter',
      'link': 'https://twitter.com/username',
      'icon': JamIcons.twitter,
      'value': '',
      'validator': 'twitter',
    },
    {
      'name': 'instagram',
      'link': 'https://instagram.com/username',
      'icon': JamIcons.instagram,
      'value': '',
      'validator': 'instagram',
    },
    {
      'name': 'email',
      'link': 'your@email.com',
      'icon': JamIcons.inbox,
      'value': '',
      'validator': '@',
    },
    {
      'name': 'telegram',
      'link': 'https://t.me/username',
      'icon': JamIcons.paper_plane,
      'value': '',
      'validator': 't.me',
    },
    {
      'name': 'dribbble',
      'link': 'https://dribbble.com/username',
      'icon': JamIcons.basketball,
      'value': '',
      'validator': 'dribbble',
    },
    {
      'name': 'linkedin',
      'link': 'https://linkedin.com/in/username',
      'icon': JamIcons.linkedin,
      'value': '',
      'validator': 'linkedin',
    },
    {
      'name': 'bio.link',
      'link': 'https://bio.link/username',
      'icon': JamIcons.world,
      'value': '',
      'validator': 'bio.link',
    },
    {
      'name': 'patreon',
      'link': 'https://patreon.com/username',
      'icon': JamIcons.patreon,
      'value': '',
      'validator': 'patreon',
    },
    {
      'name': 'trello',
      'link': 'https://trello.com/username',
      'icon': JamIcons.trello,
      'value': '',
      'validator': 'trello',
    },
    {
      'name': 'reddit',
      'link': 'https://reddit.com/user/username',
      'icon': JamIcons.reddit,
      'value': '',
      'validator': 'reddit',
    },
    {
      'name': 'behance',
      'link': 'https://behance.net/username',
      'icon': JamIcons.behance,
      'value': '',
      'validator': 'behance.net',
    },
    {
      'name': 'deviantart',
      'link': 'https://deviantart.com/username',
      'icon': JamIcons.deviantart,
      'value': '',
      'validator': 'deviantart',
    },
    {
      'name': 'gitlab',
      'link': 'https://gitlab.com/username',
      'icon': JamIcons.gitlab,
      'value': '',
      'validator': 'gitlab',
    },
    {
      'name': 'medium',
      'link': 'https://username.medium.com/',
      'icon': JamIcons.medium,
      'value': '',
      'validator': 'medium',
    },
    {
      'name': 'paypal',
      'link': 'https://paypal.me/username',
      'icon': JamIcons.paypal,
      'value': '',
      'validator': 'paypal',
    },
    {
      'name': 'spotify',
      'link': 'https://open.spotify.com/user/username',
      'icon': JamIcons.spotify,
      'value': '',
      'validator': 'open.spotify',
    },
    {
      'name': 'twitch',
      'link': 'https://twitch.tv/username',
      'icon': JamIcons.twitch,
      'value': '',
      'validator': 'twitch.tv',
    },
    {
      'name': 'unsplash',
      'link': 'https://unsplash.com/username',
      'icon': JamIcons.unsplash,
      'value': '',
      'validator': 'unsplash',
    },
    {
      'name': 'youtube',
      'link': 'https://youtube.com/channel/username',
      'icon': JamIcons.youtube,
      'value': '',
      'validator': 'youtube',
    },
    {
      'name': 'linktree',
      'link': 'https://linktr.ee/username',
      'icon': JamIcons.tree_alt,
      'value': '',
      'validator': 'linktr.ee',
    },
    {
      'name': 'buymeacoffee',
      'link': 'https://buymeacoff.ee/username',
      'icon': JamIcons.coffee,
      'value': '',
      'validator': 'buymeacoff.ee',
    },
    {
      'name': 'custom link',
      'link': '',
      'icon': JamIcons.link,
      'value': '',
      'validator': '',
    },
  ];
  Map<String, dynamic>? _link;
  @override
  void initState() {
    linkIcons
        .sort((a, b) => a['name'].toString().compareTo(b['name'].toString()));
    final links = globals.prismUser.links;
    for (var element in linkIcons) {
      if (links[element['name']] != "" && links[element['name']] != null) {
        element['value'] = links[element['name']];
      }
    }
    _link = linkIcons[3];
    bioController = TextEditingController(text: globals.prismUser.bio);
    usernameController =
        TextEditingController(text: globals.prismUser.username);
    nameController = TextEditingController(text: globals.prismUser.name);
    super.initState();
  }

  Future getPFP() async {
    final pickedFile = await picker2.getImage(source: ImageSource.gallery);
    if (pickedFile != null) {
      setState(() {
        _pfp = File(pickedFile.path);
        pfpEdit = true;
      });
    }
  }

  Future getCover() async {
    final pickedFile = await picker2.getImage(source: ImageSource.gallery);
    if (pickedFile != null) {
      setState(() {
        _cover = File(pickedFile.path);
        coverEdit = true;
      });
    }
  }

  Future<Uint8List> compressFile(File file) async {
    final result = await FlutterImageCompress.compressWithFile(
      file.absolute.path,
      minWidth: 400,
      quality: 85,
    );
    logger.d(file.lengthSync().toString());
    logger.d(result!.length.toString());
    return result;
  }

  Future processImage() async {
    final imgList = _pfp!.readAsBytesSync();
    _compressedPFP = await compressFile(_pfp!);
    await uploadFile();
  }

  Future processImageCover() async {
    final imgList = _cover!.readAsBytesSync();
    _compressedCover = await compressFile(_cover!);
    await uploadFileCover();
  }

  Future uploadFile() async {
    try {
      final String base64Image = base64Encode(_compressedPFP);
      final github = GitHub(auth: Authentication.withToken(token));
      await github.repositories
          .createFile(
              RepositorySlug(gitUserName, repoName),
              CreateFile(
                  message: Path.basename(_pfp!.path),
                  content: base64Image,
                  path: Path.basename(_pfp!.path)))
          .then((value) => setState(() {
                pfpUrl = value.content!.downloadUrl!;
                pfpPath = value.content!.path!;
                pfpSha = value.content!.sha!;
              }));
      logger.d('File Uploaded');
      globals.prismUser.profilePhoto = pfpUrl;
      main.prefs.put(main.userHiveKey, globals.prismUser);
      await firestore
          .collection(USER_NEW_COLLECTION)
          .doc(globals.prismUser.id)
          .update({
        "profilePhoto": pfpUrl,
      });
    } catch (e) {
      logger.d(e.toString());
      toasts.error("Some uploading issue, please try again.");
    }
  }

  Future uploadFileCover() async {
    try {
      final String base64Image = base64Encode(_compressedCover);
      final github = GitHub(auth: Authentication.withToken(token));
      await github.repositories
          .createFile(
              RepositorySlug(gitUserName, repoName),
              CreateFile(
                  message: Path.basename(_cover!.path),
                  content: base64Image,
                  path: Path.basename(_cover!.path)))
          .then((value) => setState(() {
                coverUrl = value.content!.downloadUrl!;
                coverPath = value.content!.path!;
                coverSha = value.content!.sha!;
              }));
      logger.d('Cover File Uploaded');
      globals.prismUser.coverPhoto = coverUrl;
      main.prefs.put(main.userHiveKey, globals.prismUser);
      await firestore
          .collection(USER_NEW_COLLECTION)
          .doc(globals.prismUser.id)
          .update({
        "coverPhoto": coverUrl,
      });
    } catch (e) {
      logger.d(e.toString());
      toasts.error("Some uploading issue, please try again.");
    }
  }

  Future<bool> onWillPop() async {
    if (navStack.length > 1) navStack.removeLast();
    logger.d(navStack.toString());
    return true;
  }

  Future<void> showRemoveAlertDialog(
      BuildContext context, Function() remove, String removeWhat) async {
    final AlertDialog deletePopUp = AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      title: Text(
        'Delete the $removeWhat?',
        style: TextStyle(
            fontWeight: FontWeight.w700,
            fontSize: 16,
            color: Theme.of(context).accentColor),
      ),
      content: Text(
        "This is permanent, and this action can't be undone!",
        style: TextStyle(
            fontFamily: "Proxima Nova",
            fontWeight: FontWeight.normal,
            fontSize: 14,
            color: Theme.of(context).accentColor),
      ),
      actions: [
        FlatButton(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(5)),
          color: Theme.of(context).hintColor,
          onPressed: () async {
            Navigator.pop(context);
            await remove();
          },
          child: const Text(
            'DELETE',
            style: TextStyle(
              fontSize: 16.0,
              color: Colors.white,
            ),
          ),
        ),
        FlatButton(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(5)),
          color: Theme.of(context).errorColor,
          onPressed: () {
            Navigator.of(context).pop();
          },
          child: const Text(
            'CANCEL',
            style: TextStyle(
              fontSize: 16.0,
              color: Colors.white,
            ),
          ),
        ),
      ],
      backgroundColor: Theme.of(context).primaryColor,
      actionsPadding: const EdgeInsets.fromLTRB(10, 0, 10, 0),
    );

    showModal(
        context: context,
        configuration: const FadeScaleTransitionConfiguration(),
        builder: (BuildContext context) => deletePopUp);
  }

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.of(context).size.width * 0.85;
    return WillPopScope(
      onWillPop: onWillPop,
      child: Scaffold(
        appBar: AppBar(
          leading: IconButton(
              icon: const Icon(JamIcons.close),
              onPressed: () {
                navStack.removeLast();
                logger.d(navStack.toString());
                Navigator.pop(context);
              }),
          title: Text(
            "Edit Profile",
            style: Theme.of(context).textTheme.headline3,
          ),
        ),
        backgroundColor: Theme.of(context).primaryColor,
        body: SingleChildScrollView(
          child: Container(
            height: MediaQuery.of(context).size.height,
            width: MediaQuery.of(context).size.width,
            decoration: BoxDecoration(
              color: Theme.of(context).primaryColor,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(20),
                topRight: Radius.circular(20),
              ),
            ),
            child: Column(
              children: <Widget>[
                Stack(
                  children: [
                    Container(
                      height: MediaQuery.of(context).size.width * 508 / 1234,
                      width: MediaQuery.of(context).size.width,
                      decoration: const BoxDecoration(
                        border: Border.fromBorderSide(
                          BorderSide(color: Colors.white, width: 2),
                        ),
                      ),
                      child: (_cover == null)
                          ? (globals.prismUser.coverPhoto != null)
                              ? CachedNetworkImage(
                                  imageUrl: globals.prismUser.coverPhoto!,
                                  fit: BoxFit.cover,
                                )
                              : SvgPicture.string(
                                  defaultHeader
                                      .replaceAll(
                                        "#181818",
                                        "#${Theme.of(context).primaryColor.value.toRadixString(16).toString().substring(2)}",
                                      )
                                      .replaceAll(
                                        "#E77597",
                                        "#${Theme.of(context).errorColor.value.toRadixString(16).toString().substring(2)}",
                                      ),
                                  fit: BoxFit.cover,
                                )
                          : Image.file(
                              _cover!,
                              fit: BoxFit.cover,
                            ),
                    ),
                    Material(
                      child: InkWell(
                        onTap: () async {
                          await getCover();
                        },
                        child: Container(
                          height:
                              MediaQuery.of(context).size.width * 508 / 1234,
                          width: MediaQuery.of(context).size.width,
                          decoration: BoxDecoration(
                            border: const Border.fromBorderSide(
                              BorderSide(color: Colors.white, width: 2),
                            ),
                            color:
                                Theme.of(context).errorColor.withOpacity(0.5),
                          ),
                          child: const Icon(
                            JamIcons.pencil,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                    Positioned(
                      right: 0,
                      child: IconButton(
                        onPressed: () async {
                          showRemoveAlertDialog(context, () async {
                            _cover = null;
                            globals.prismUser.coverPhoto = null;
                            main.prefs.put(main.userHiveKey, globals.prismUser);
                            await firestore
                                .collection(USER_NEW_COLLECTION)
                                .doc(globals.prismUser.id)
                                .update({
                              "coverPhoto": null,
                            });
                          }, "Cover photo");
                        },
                        icon: const Icon(
                          JamIcons.close,
                        ),
                      ),
                    )
                  ],
                ),
                const Spacer(),
                ClipOval(
                  child: Material(
                    child: InkWell(
                      onTap: () async {
                        await getPFP();
                      },
                      child: Stack(
                        children: [
                          Container(
                            height: 100,
                            width: 100,
                            decoration: const BoxDecoration(
                              shape: BoxShape.circle,
                              border: Border.fromBorderSide(
                                BorderSide(color: Colors.white, width: 2),
                              ),
                            ),
                            child: (_pfp == null)
                                ? CachedNetworkImage(
                                    imageUrl: globals.prismUser.profilePhoto,
                                    fit: BoxFit.cover,
                                  )
                                : Image.file(
                                    _pfp!,
                                    fit: BoxFit.cover,
                                  ),
                          ),
                          Container(
                            height: 100,
                            width: 100,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border: const Border.fromBorderSide(
                                BorderSide(color: Colors.white, width: 2),
                              ),
                              color:
                                  Theme.of(context).errorColor.withOpacity(0.5),
                            ),
                            child: const Icon(
                              JamIcons.pencil,
                              color: Colors.white,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const Spacer(),
                Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: <Widget>[
                    SizedBox(
                      height: 80,
                      width: width - 24,
                      child: Center(
                        child: TextField(
                          cursorColor: const Color(0xFFE57697),
                          style: Theme.of(context)
                              .textTheme
                              .headline5!
                              .copyWith(color: Colors.white),
                          controller: nameController,
                          decoration: InputDecoration(
                            contentPadding:
                                const EdgeInsets.only(left: 30, top: 15),
                            border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(10),
                                borderSide: const BorderSide(
                                    color: Colors.white, width: 2)),
                            disabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(10),
                                borderSide: const BorderSide(
                                    color: Colors.white, width: 2)),
                            enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(10),
                                borderSide: const BorderSide(
                                    color: Colors.white, width: 2)),
                            focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(10),
                                borderSide: const BorderSide(
                                    color: Colors.white, width: 2)),
                            labelText: "Name",
                            labelStyle: Theme.of(context)
                                .textTheme
                                .headline5!
                                .copyWith(fontSize: 14, color: Colors.white),
                            prefixIcon: const Padding(
                              padding: EdgeInsets.all(16.0),
                              child: Text(
                                "Name",
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ),
                          onChanged: (value) async {
                            if (value == globals.prismUser.name ||
                                value == "") {
                              setState(() {
                                nameEdit = false;
                              });
                            } else {
                              setState(() {
                                nameEdit = true;
                              });
                            }
                          },
                        ),
                      ),
                    ),
                    SizedBox(
                      height: 80,
                      width: width - 24,
                      child: Center(
                        child: TextField(
                          cursorColor: const Color(0xFFE57697),
                          style: Theme.of(context)
                              .textTheme
                              .headline5!
                              .copyWith(color: Colors.white),
                          controller: usernameController,
                          decoration: InputDecoration(
                            contentPadding:
                                const EdgeInsets.only(left: 30, top: 15),
                            border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(10),
                                borderSide: const BorderSide(
                                    color: Colors.white, width: 2)),
                            disabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(10),
                                borderSide: const BorderSide(
                                    color: Colors.white, width: 2)),
                            enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(10),
                                borderSide: const BorderSide(
                                    color: Colors.white, width: 2)),
                            focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(10),
                                borderSide: const BorderSide(
                                    color: Colors.white, width: 2)),
                            labelText: "username",
                            labelStyle: Theme.of(context)
                                .textTheme
                                .headline5!
                                .copyWith(fontSize: 14, color: Colors.white),
                            prefixIcon: const Padding(
                              padding: EdgeInsets.all(16.0),
                              child: Text(
                                "@",
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                            suffixIcon: isCheckingUsername
                                ? Padding(
                                    padding: const EdgeInsets.all(16.0),
                                    child: SizedBox(
                                      width: 16,
                                      height: 16,
                                      child: CircularProgressIndicator(
                                        color: Theme.of(context).errorColor,
                                      ),
                                    ),
                                  )
                                : Padding(
                                    padding: EdgeInsets.all(
                                        available == null ? 16.0 : 8),
                                    child: available == null
                                        ? const Text(
                                            "",
                                            style: TextStyle(
                                              color: Colors.white,
                                              fontSize: 14,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          )
                                        : Icon(
                                            available!
                                                ? JamIcons.check
                                                : JamIcons.close,
                                            color: available!
                                                ? Colors.green
                                                : Colors.red,
                                            size: 24,
                                          ),
                                  ),
                          ),
                          onChanged: (value) async {
                            if (value != "" &&
                                value.length >= 8 &&
                                !value.contains(RegExp(r"(?: |[^\w\s])+"))) {
                              setState(() {
                                enabled = true;
                              });
                            } else {
                              setState(() {
                                enabled = false;
                              });
                            }
                            if (enabled) {
                              setState(() {
                                isCheckingUsername = true;
                              });
                              await FirebaseFirestore.instance
                                  .collection(USER_NEW_COLLECTION)
                                  .where("username", isEqualTo: value)
                                  .get()
                                  .then((snapshot) {
                                if (snapshot.size == 0) {
                                  setState(() {
                                    available = true;
                                  });
                                } else {
                                  setState(() {
                                    available = false;
                                  });
                                }
                              });
                              setState(() {
                                isCheckingUsername = false;
                              });
                            } else {
                              setState(() {
                                available = null;
                              });
                            }
                            if (value == globals.prismUser.username ||
                                value == "") {
                              setState(() {
                                usernameEdit = false;
                                available = null;
                              });
                            } else {
                              setState(() {
                                usernameEdit = true;
                              });
                            }
                          },
                        ),
                      ),
                    ),
                    SizedBox(
                      height: 80,
                      width: width - 24,
                      child: Center(
                        child: TextField(
                          cursorColor: const Color(0xFFE57697),
                          style: Theme.of(context)
                              .textTheme
                              .headline5!
                              .copyWith(color: Colors.white),
                          controller: bioController,
                          decoration: InputDecoration(
                            contentPadding:
                                const EdgeInsets.only(left: 30, top: 15),
                            border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(10),
                                borderSide: const BorderSide(
                                    color: Colors.white, width: 2)),
                            disabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(10),
                                borderSide: const BorderSide(
                                    color: Colors.white, width: 2)),
                            enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(10),
                                borderSide: const BorderSide(
                                    color: Colors.white, width: 2)),
                            focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(10),
                                borderSide: const BorderSide(
                                    color: Colors.white, width: 2)),
                            labelText: "Bio",
                            labelStyle: Theme.of(context)
                                .textTheme
                                .headline5!
                                .copyWith(fontSize: 14, color: Colors.white),
                            prefixIcon: const Padding(
                              padding: EdgeInsets.all(16.0),
                              child: Text(
                                "bio",
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                            suffixIcon: IconButton(
                              onPressed: () async {
                                showRemoveAlertDialog(context, () async {
                                  bioController.text = "";
                                  globals.prismUser.bio = "";
                                  main.prefs
                                      .put(main.userHiveKey, globals.prismUser);
                                  await firestore
                                      .collection(USER_NEW_COLLECTION)
                                      .doc(globals.prismUser.id)
                                      .update({
                                    "bio": "",
                                  });
                                }, "bio");
                              },
                              icon: const Icon(
                                JamIcons.close,
                                color: Colors.red,
                                size: 24,
                              ),
                            ),
                          ),
                          onChanged: (value) {
                            if (value == globals.prismUser.bio || value == "") {
                              setState(() {
                                bioEdit = false;
                              });
                            } else {
                              setState(() {
                                bioEdit = true;
                              });
                            }
                          },
                        ),
                      ),
                    ),
                    SizedBox(
                      height: 80,
                      width: width - 24,
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          Positioned(
                            left: 0,
                            child: SizedBox(
                              height: 80,
                              width: 130,
                              child: Center(
                                child: DropdownButton<Map<String, dynamic>>(
                                  isExpanded: true,
                                  items: linkIcons
                                      .map((Map<String, dynamic> link) {
                                    return DropdownMenuItem(
                                      value: link,
                                      child: Row(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.end,
                                        children: [
                                          Icon(link["icon"] as IconData),
                                          const SizedBox(
                                            width: 16,
                                          ),
                                          Text(
                                            link["name"].toString().inCaps,
                                            style: Theme.of(context)
                                                .textTheme
                                                .headline5!
                                                .copyWith(
                                                  color: Colors.white,
                                                  fontSize: 14,
                                                ),
                                          )
                                        ],
                                      ),
                                    );
                                  }).toList(),
                                  underline: Container(),
                                  onChanged: (value) {
                                    setState(() => _link = value);
                                    linkController.text =
                                        _link!["value"].toString();
                                  },
                                  icon: Container(),
                                  value: _link,
                                  dropdownColor: Theme.of(context).primaryColor,
                                  selectedItemBuilder: (BuildContext context) {
                                    return linkIcons.map<Widget>((Map link) {
                                      return Padding(
                                        padding:
                                            const EdgeInsets.only(left: 12.0),
                                        child: Row(
                                          children: [
                                            Icon(link["icon"] as IconData),
                                            const Icon(
                                              JamIcons.chevron_down,
                                              size: 14,
                                            ),
                                          ],
                                        ),
                                      );
                                    }).toList();
                                  },
                                ),
                              ),
                            ),
                          ),
                          Positioned(
                            right: 0,
                            child: SizedBox(
                              height: 80,
                              width: width - 80,
                              child: Center(
                                child: TextField(
                                  cursorColor: const Color(0xFFE57697),
                                  style: Theme.of(context)
                                      .textTheme
                                      .headline5!
                                      .copyWith(color: Colors.white),
                                  controller: linkController,
                                  decoration: InputDecoration(
                                    enabled: _link?["name"] != "Edit links...",
                                    contentPadding: const EdgeInsets.only(
                                        left: 30, top: 15),
                                    border: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(10),
                                        borderSide: const BorderSide(
                                            color: Colors.white, width: 2)),
                                    disabledBorder: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(10),
                                        borderSide: const BorderSide(
                                            color: Colors.white, width: 2)),
                                    enabledBorder: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(10),
                                        borderSide: const BorderSide(
                                            color: Colors.white, width: 2)),
                                    focusedBorder: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(10),
                                        borderSide: const BorderSide(
                                            color: Colors.white, width: 2)),
                                    labelText:
                                        _link?["name"].toString().inCaps ?? "",
                                    labelStyle: Theme.of(context)
                                        .textTheme
                                        .headline5!
                                        .copyWith(
                                            fontSize: 14, color: Colors.white),
                                    hintText: _link?["link"].toString() ?? "",
                                    hintStyle: Theme.of(context)
                                        .textTheme
                                        .headline5!
                                        .copyWith(
                                            fontSize: 14, color: Colors.white),
                                    suffixIcon: IconButton(
                                      onPressed: () async {
                                        showRemoveAlertDialog(context,
                                            () async {
                                          linkController.text = "";
                                          final links = globals.prismUser.links;
                                          links.remove(
                                              _link?["name"].toString());
                                          globals.prismUser.links = links;
                                          main.prefs.put(main.userHiveKey,
                                              globals.prismUser);
                                          await firestore
                                              .collection(USER_NEW_COLLECTION)
                                              .doc(globals.prismUser.id)
                                              .update({
                                            "links": globals.prismUser.links,
                                          });
                                        }, "${_link?["name"].toString().inCaps}");
                                      },
                                      icon: const Icon(
                                        JamIcons.close,
                                        color: Colors.red,
                                        size: 24,
                                      ),
                                    ),
                                  ),
                                  onChanged: (value) {
                                    // logger.d("VALUE TEXT ${value.toLowerCase()}");
                                    // logger.d(
                                    //     "VALUE LINK NAME ${_link?["name"].toString().toLowerCase()}");
                                    // logger.d(
                                    //     "VALUE LINK VALUE ${_link?["value"].toString().toLowerCase()}");
                                    // logger.d("VALUE LINK EDIT ${linkEdit}");
                                    // logger.d(
                                    //     "VALUE LINK CONTAINS ${(value.toLowerCase().contains('${_link?["name"].toString().toLowerCase()}'))}");

                                    if (value.toLowerCase().contains(
                                        '${_link?["validator"].toString().toLowerCase()}')) {
                                      setState(() {
                                        _link?["value"] = value;
                                        // if (_link?["name"].toString() == 'github') {
                                        //   githubUrl = value;
                                        // } else if (_link?["name"].toString() ==
                                        //     'twitter') {
                                        //   twitterUrl = value;
                                        // } else if (_link?["name"].toString() ==
                                        //     'instagram') {
                                        //   instagramUrl = value;
                                        // } else if (_link?["name"].toString() ==
                                        //     'email') {
                                        //   emailUrl = value;
                                        // }
                                      });
                                      bool changed = false;
                                      for (int i = 0;
                                          i < linkIcons.length;
                                          i++) {
                                        if (linkIcons[i]["value"] != "") {
                                          changed = true;
                                          break;
                                        }
                                      }
                                      setState(() {
                                        linkEdit = changed;
                                      });
                                    } else if (value == "") {
                                      bool changed = false;
                                      for (int i = 0;
                                          i < linkIcons.length;
                                          i++) {
                                        if (linkIcons[i]["value"] != "") {
                                          changed = true;
                                          break;
                                        }
                                      }
                                      setState(() {
                                        linkEdit = changed;
                                      });
                                    } else {
                                      setState(() {
                                        linkEdit = false;
                                      });
                                    }
                                  },
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const Spacer(),
                Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: GestureDetector(
                    onTap: (!usernameEdit &&
                            (pfpEdit ||
                                bioEdit ||
                                linkEdit ||
                                coverEdit ||
                                nameEdit))
                        ? () async {
                            setState(() {
                              isLoading = true;
                            });
                            if (_pfp != null && pfpEdit) {
                              await processImage();
                            }
                            if (_cover != null && coverEdit) {
                              await processImageCover();
                            }
                            if (bioEdit && bioController.text != "") {
                              globals.prismUser.bio = bioController.text;
                              main.prefs
                                  .put(main.userHiveKey, globals.prismUser);
                              await firestore
                                  .collection(USER_NEW_COLLECTION)
                                  .doc(globals.prismUser.id)
                                  .update({
                                "bio": bioController.text,
                              });
                            }
                            if (linkEdit) {
                              final Map links = globals.prismUser.links;
                              for (int p = 0; p < linkIcons.length; p++) {
                                if (linkIcons[p]["value"] != "") {
                                  links[linkIcons[p]["name"]] =
                                      linkIcons[p]["value"];
                                }
                              }
                              globals.prismUser.links = links;
                              main.prefs
                                  .put(main.userHiveKey, globals.prismUser);
                              await firestore
                                  .collection(USER_NEW_COLLECTION)
                                  .doc(globals.prismUser.id)
                                  .update({
                                "links": links,
                              });
                            }
                            if (nameEdit && nameController.text != "") {
                              globals.prismUser.name = nameController.text;
                              main.prefs
                                  .put(main.userHiveKey, globals.prismUser);
                              await firestore
                                  .collection(USER_NEW_COLLECTION)
                                  .doc(globals.prismUser.id)
                                  .update({
                                "name": nameController.text,
                              });
                            }
                            setState(() {
                              isLoading = false;
                            });
                            Navigator.pop(context);
                            navStack.removeLast();
                            logger.d(navStack.toString());
                            toasts.codeSend("Details updated!");
                          }
                        : (usernameEdit && enabled)
                            ? () async {
                                setState(() {
                                  isLoading = true;
                                });
                                if (usernameEdit &&
                                    usernameController.text != "" &&
                                    usernameController.text.length >= 8) {
                                  globals.prismUser.username =
                                      usernameController.text;
                                  main.prefs
                                      .put(main.userHiveKey, globals.prismUser);
                                  await firestore
                                      .collection(USER_NEW_COLLECTION)
                                      .doc(globals.prismUser.id)
                                      .update({
                                    "username": usernameController.text,
                                  });
                                }
                                if (_pfp != null && pfpEdit) {
                                  await processImage();
                                }
                                if (_cover != null && coverEdit) {
                                  await processImageCover();
                                }
                                if (bioEdit && bioController.text != "") {
                                  globals.prismUser.bio = bioController.text;
                                  main.prefs
                                      .put(main.userHiveKey, globals.prismUser);
                                  await firestore
                                      .collection(USER_NEW_COLLECTION)
                                      .doc(globals.prismUser.id)
                                      .update({
                                    "bio": bioController.text,
                                  });
                                }
                                if (nameEdit && nameController.text != "") {
                                  globals.prismUser.name = nameController.text;
                                  main.prefs
                                      .put(main.userHiveKey, globals.prismUser);
                                  await firestore
                                      .collection(USER_NEW_COLLECTION)
                                      .doc(globals.prismUser.id)
                                      .update({
                                    "name": nameController.text,
                                  });
                                }
                                if (linkEdit) {
                                  final Map links = globals.prismUser.links;
                                  for (int p = 0; p < linkIcons.length; p++) {
                                    if (linkIcons[p]["value"] != "") {
                                      links[linkIcons[p]["name"]] =
                                          linkIcons[p]["value"];
                                    }
                                  }
                                  globals.prismUser.links = links;
                                  main.prefs
                                      .put(main.userHiveKey, globals.prismUser);
                                  await firestore
                                      .collection(USER_NEW_COLLECTION)
                                      .doc(globals.prismUser.id)
                                      .update({
                                    "links": links,
                                  });
                                }
                                setState(() {
                                  isLoading = false;
                                });
                                Navigator.pop(context);
                                navStack.removeLast();
                                logger.d(navStack.toString());
                                toasts.codeSend("Details updated!");
                              }
                            : null,
                    child: SizedBox(
                      width: width - 20,
                      height: 60,
                      child: Container(
                        width: width - 14,
                        height: 60,
                        decoration: BoxDecoration(
                          color: !((!usernameEdit &&
                                      (pfpEdit ||
                                          bioEdit ||
                                          linkEdit ||
                                          coverEdit ||
                                          nameEdit)) ||
                                  (usernameEdit && enabled))
                              ? Theme.of(context).primaryColor
                              : Theme.of(context).errorColor.withOpacity(0.2),
                          border: Border.all(
                              color: !((!usernameEdit &&
                                          (pfpEdit ||
                                              bioEdit ||
                                              linkEdit ||
                                              coverEdit ||
                                              nameEdit)) ||
                                      (usernameEdit && enabled))
                                  ? Theme.of(context)
                                      .accentColor
                                      .withOpacity(0.5)
                                  : Theme.of(context).errorColor,
                              width: 3),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Center(
                          child: isLoading
                              ? CircularProgressIndicator(
                                  color: Theme.of(context).primaryColor)
                              : Text(
                                  "Update",
                                  style: TextStyle(
                                      fontSize: 16,
                                      color: !((!usernameEdit &&
                                                  (pfpEdit ||
                                                      bioEdit ||
                                                      linkEdit ||
                                                      coverEdit ||
                                                      nameEdit)) ||
                                              (usernameEdit && enabled))
                                          ? Theme.of(context)
                                              .accentColor
                                              .withOpacity(0.5)
                                          : Theme.of(context).accentColor,
                                      fontWeight: FontWeight.bold),
                                ),
                        ),
                      ),
                    ),
                  ),
                ),
                const Spacer(flex: 2),
                Padding(
                  padding: const EdgeInsets.fromLTRB(0, 0, 0, 32),
                  child: SizedBox(
                    width: MediaQuery.of(context).size.width * 0.8,
                    child: Text(
                      "Usernames are unique names through which fans can view your profile/search for you. They should be greater than 8 characters, and cannot contain any symbol except for underscore (_).",
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 13,
                        color: Theme.of(context).accentColor,
                      ),
                    ),
                  ),
                ),
                const Spacer(
                  flex: 3,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
