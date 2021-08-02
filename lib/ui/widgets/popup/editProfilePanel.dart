import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:Prism/auth/google_auth.dart';
import 'package:Prism/gitkey.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:Prism/global/globals.dart' as globals;
import 'package:Prism/theme/toasts.dart' as toasts;
import 'package:flutter/material.dart';
import 'package:Prism/theme/jam_icons_icons.dart';
import 'package:Prism/main.dart' as main;
import 'package:flutter_image_compress/flutter_image_compress.dart';
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
  final TextEditingController bioController = TextEditingController();
  final TextEditingController usernameController = TextEditingController();
  final FirebaseFirestore firestore = FirebaseFirestore.instance;
  bool isLoading = false;
  bool pfpEdit = false;
  bool usernameEdit = false;
  bool bioEdit = false;
  bool linkEdit = false;
  bool enabled = false;
  bool? available;
  bool isCheckingUsername = false;
  File? _pfp;
  late List<int> _compressedPFP;
  late String pfpSha;
  late String pfpPath;
  late String pfpUrl;
  final picker2 = ImagePicker();
  List<Map<String, dynamic>> linkIcons = [
    {
      'name': 'Edit links...',
      'link': 'Select your link first',
      'icon': JamIcons.link,
    },
    {
      'name': 'github',
      'link': 'https://github.com/username',
      'icon': JamIcons.github,
    },
    {
      'name': 'twitter',
      'link': 'https://twitter.com/username',
      'icon': JamIcons.twitter,
    },
    {
      'name': 'instagram',
      'link': 'https://instagram.com/username',
      'icon': JamIcons.instagram,
    },
    {
      'name': 'email',
      'link': 'your@email.com',
      'icon': JamIcons.message,
    },
  ];
  Map<String, dynamic>? _link;
  @override
  void initState() {
    _link = linkIcons[0];
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

  Future<Uint8List> compressFile(File file) async {
    final result = await FlutterImageCompress.compressWithFile(
      file.absolute.path,
      minWidth: 400,
      quality: 85,
    );
    debugPrint(file.lengthSync().toString());
    debugPrint(result!.length.toString());
    return result;
  }

  Future processImage() async {
    final imgList = _pfp!.readAsBytesSync();
    _compressedPFP = await compressFile(_pfp!);
    uploadFile();
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
      debugPrint('File Uploaded');
      globals.prismUser.profilePhoto = pfpUrl;
      main.prefs.put("prismUserV2", globals.prismUser);
      await firestore
          .collection(USER_NEW_COLLECTION)
          .doc(globals.prismUser.id)
          .update({
        "profilePhoto": pfpUrl,
      });
    } catch (e) {
      debugPrint(e.toString());
      toasts.error("Some uploading issue, please try again.");
    }
  }

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.of(context).size.width * 0.85;
    return Padding(
      padding: MediaQuery.of(context).viewInsets,
      child: SingleChildScrollView(
        child: Container(
          height: MediaQuery.of(context).size.height * 0.8,
          decoration: BoxDecoration(
            color: Theme.of(context).primaryColor,
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(20),
              topRight: Radius.circular(20),
            ),
          ),
          child: Column(
            children: <Widget>[
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  Padding(
                    padding: const EdgeInsets.all(12.0),
                    child: Container(
                      height: 5,
                      width: 30,
                      decoration: BoxDecoration(
                          color: Theme.of(context).hintColor,
                          borderRadius: BorderRadius.circular(500)),
                    ),
                  )
                ],
              ),
              const Spacer(),
              Text(
                "Edit Profile",
                style: Theme.of(context).textTheme.headline2,
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
                          height: 120,
                          width: 120,
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
                          height: 120,
                          width: 120,
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
                          if (value == "") {
                            setState(() {
                              usernameEdit = false;
                            });
                          } else {
                            setState(() {
                              usernameEdit = true;
                            });
                          }
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
                        ),
                        onChanged: (value) {
                          if (value == "") {
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
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      SizedBox(
                        height: 80,
                        width: 48,
                        child: Center(
                          child: DropdownButton<Map<String, dynamic>>(
                            items: linkIcons.map((Map<String, dynamic> link) {
                              return DropdownMenuItem(
                                value: link,
                                child: Icon(link!["icon"] as IconData),
                              );
                            }).toList(),
                            underline: Container(),
                            onChanged: (value) {
                              setState(() => _link = value);
                            },
                            value: _link,
                          ),
                        ),
                      ),
                      SizedBox(
                        height: 80,
                        width: width - 72,
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
                              labelText: _link?["name"].toString().inCaps ?? "",
                              labelStyle: Theme.of(context)
                                  .textTheme
                                  .headline5!
                                  .copyWith(fontSize: 14, color: Colors.white),
                              hintText: _link?["link"].toString() ?? "",
                              hintStyle: Theme.of(context)
                                  .textTheme
                                  .headline5!
                                  .copyWith(fontSize: 14, color: Colors.white),
                            ),
                            onChanged: (value) {
                              if (value == "") {
                                setState(() {
                                  linkEdit = false;
                                });
                              } else {
                                setState(() {
                                  linkEdit = true;
                                });
                              }
                            },
                          ),
                        ),
                      ),
                    ],
                  ),
                  Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: GestureDetector(
                      onTap: (!usernameEdit && (pfpEdit || bioEdit))
                          ? () async {
                              setState(() {
                                isLoading = true;
                              });
                              if (_pfp != null && pfpEdit) {
                                await processImage();
                              }
                              if (bioEdit && bioController.text != "") {
                                globals.prismUser.bio = bioController.text;
                                main.prefs
                                    .put("prismUserV2", globals.prismUser);
                                await firestore
                                    .collection(USER_NEW_COLLECTION)
                                    .doc(globals.prismUser.id)
                                    .update({
                                  "bio": bioController.text,
                                });
                              }
                              setState(() {
                                isLoading = false;
                              });
                              Navigator.pop(context);
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
                                        .put("prismUserV2", globals.prismUser);
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
                                  if (bioEdit && bioController.text != "") {
                                    globals.prismUser.bio = bioController.text;
                                    main.prefs
                                        .put("prismUserV2", globals.prismUser);
                                    await firestore
                                        .collection(USER_NEW_COLLECTION)
                                        .doc(globals.prismUser.id)
                                        .update({
                                      "bio": bioController.text,
                                    });
                                  }
                                  setState(() {
                                    isLoading = false;
                                  });
                                  Navigator.pop(context);
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
                            color: !((!usernameEdit && (pfpEdit || bioEdit)) ||
                                    (usernameEdit && enabled))
                                ? Theme.of(context).primaryColor
                                : Theme.of(context).errorColor.withOpacity(0.2),
                            border: Border.all(
                                color:
                                    !((!usernameEdit && (pfpEdit || bioEdit)) ||
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
                                    "Continue",
                                    style: TextStyle(
                                        fontSize: 16,
                                        color: !((!usernameEdit &&
                                                    (pfpEdit || bioEdit)) ||
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
                ],
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
              const Spacer(),
            ],
          ),
        ),
      ),
    );
  }
}
