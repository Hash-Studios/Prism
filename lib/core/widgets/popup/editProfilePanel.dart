import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:Prism/auth/google_auth.dart';
import 'package:Prism/core/coins/coins_service.dart';
import 'package:Prism/core/firestore/firestore_query_specs.dart';
import 'package:Prism/core/firestore/firestore_runtime.dart';
import 'package:Prism/core/state/app_state.dart' as app_state;
import 'package:Prism/env/env.dart';
import 'package:Prism/global/svgAssets.dart';
import 'package:Prism/logger/logger.dart';
import 'package:Prism/theme/jam_icons_icons.dart';
import 'package:Prism/theme/toasts.dart' as toasts;
import 'package:animations/animations.dart';
import 'package:auto_route/auto_route.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:github/github.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path/path.dart' as Path;

@RoutePage(name: 'EditProfilePanelRoute')
class EditProfilePanel extends StatefulWidget {
  const EditProfilePanel({super.key});

  @override
  _EditProfilePanelState createState() => _EditProfilePanelState();
}

class _ProfileLinkOption {
  _ProfileLinkOption({
    required this.name,
    required this.link,
    required this.icon,
    required this.validator,
    // ignore: unused_element_parameter
    this.value = '',
  });

  final String name;
  final String link;
  final IconData icon;
  final String validator;
  String value;
}

class _EditProfilePanelState extends State<EditProfilePanel> {
  final TextEditingController linkController = TextEditingController();
  late TextEditingController bioController;
  late TextEditingController usernameController;
  late TextEditingController nameController;
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
  List<_ProfileLinkOption> linkIcons = [
    // {
    //   'name': 'Edit links...',
    //   'link': 'Select your link first',
    //   'icon': JamIcons.link,
    //   'value': '',
    //   'validator': '',
    // },
    _ProfileLinkOption(name: 'github', link: 'https://github.com/username', icon: JamIcons.github, validator: 'github'),
    _ProfileLinkOption(
      name: 'twitter',
      link: 'https://twitter.com/username',
      icon: JamIcons.twitter,
      validator: 'twitter',
    ),
    _ProfileLinkOption(
      name: 'instagram',
      link: 'https://instagram.com/username',
      icon: JamIcons.instagram,
      validator: 'instagram',
    ),
    _ProfileLinkOption(name: 'email', link: 'your@email.com', icon: JamIcons.inbox, validator: '@'),
    _ProfileLinkOption(name: 'telegram', link: 'https://t.me/username', icon: JamIcons.paper_plane, validator: 't.me'),
    _ProfileLinkOption(
      name: 'dribbble',
      link: 'https://dribbble.com/username',
      icon: JamIcons.basketball,
      validator: 'dribbble',
    ),
    _ProfileLinkOption(
      name: 'linkedin',
      link: 'https://linkedin.com/in/username',
      icon: JamIcons.linkedin,
      validator: 'linkedin',
    ),
    _ProfileLinkOption(
      name: 'bio.link',
      link: 'https://bio.link/username',
      icon: JamIcons.world,
      validator: 'bio.link',
    ),
    _ProfileLinkOption(
      name: 'patreon',
      link: 'https://patreon.com/username',
      icon: JamIcons.patreon,
      validator: 'patreon',
    ),
    _ProfileLinkOption(name: 'trello', link: 'https://trello.com/username', icon: JamIcons.trello, validator: 'trello'),
    _ProfileLinkOption(
      name: 'reddit',
      link: 'https://reddit.com/user/username',
      icon: JamIcons.reddit,
      validator: 'reddit',
    ),
    _ProfileLinkOption(
      name: 'behance',
      link: 'https://behance.net/username',
      icon: JamIcons.behance,
      validator: 'behance.net',
    ),
    _ProfileLinkOption(
      name: 'deviantart',
      link: 'https://deviantart.com/username',
      icon: JamIcons.deviantart,
      validator: 'deviantart',
    ),
    _ProfileLinkOption(name: 'gitlab', link: 'https://gitlab.com/username', icon: JamIcons.gitlab, validator: 'gitlab'),
    _ProfileLinkOption(
      name: 'medium',
      link: 'https://username.medium.com/',
      icon: JamIcons.medium,
      validator: 'medium',
    ),
    _ProfileLinkOption(name: 'paypal', link: 'https://paypal.me/username', icon: JamIcons.paypal, validator: 'paypal'),
    _ProfileLinkOption(
      name: 'spotify',
      link: 'https://open.spotify.com/user/username',
      icon: JamIcons.spotify,
      validator: 'open.spotify',
    ),
    _ProfileLinkOption(
      name: 'twitch',
      link: 'https://twitch.tv/username',
      icon: JamIcons.twitch,
      validator: 'twitch.tv',
    ),
    _ProfileLinkOption(
      name: 'unsplash',
      link: 'https://unsplash.com/username',
      icon: JamIcons.unsplash,
      validator: 'unsplash',
    ),
    _ProfileLinkOption(
      name: 'youtube',
      link: 'https://youtube.com/channel/username',
      icon: JamIcons.youtube,
      validator: 'youtube',
    ),
    _ProfileLinkOption(
      name: 'linktree',
      link: 'https://linktr.ee/username',
      icon: JamIcons.tree_alt,
      validator: 'linktr.ee',
    ),
    _ProfileLinkOption(
      name: 'buymeacoffee',
      link: 'https://buymeacoff.ee/username',
      icon: JamIcons.coffee,
      validator: 'buymeacoff.ee',
    ),
    _ProfileLinkOption(name: 'custom link', link: '', icon: JamIcons.link, validator: ''),
  ];
  _ProfileLinkOption? _link;
  @override
  void initState() {
    linkIcons.sort((a, b) => a.name.compareTo(b.name));
    final links = app_state.prismUser.links;
    for (final element in linkIcons) {
      final String value = links[element.name]?.toString() ?? '';
      if (value.isNotEmpty) {
        element.value = value;
      }
    }
    _link = linkIcons[3];
    bioController = TextEditingController(text: app_state.prismUser.bio);
    usernameController = TextEditingController(text: app_state.prismUser.username);
    nameController = TextEditingController(text: app_state.prismUser.name);
    super.initState();
  }

  Future getPFP() async {
    final pickedFile = await picker2.pickImage(source: ImageSource.gallery);
    if (pickedFile != null) {
      setState(() {
        _pfp = File(pickedFile.path);
        pfpEdit = true;
      });
    }
  }

  Future getCover() async {
    final pickedFile = await picker2.pickImage(source: ImageSource.gallery);
    if (pickedFile != null) {
      setState(() {
        _cover = File(pickedFile.path);
        coverEdit = true;
      });
    }
  }

  Future<Uint8List> compressFile(File file) async {
    final result = await FlutterImageCompress.compressWithFile(file.absolute.path, minWidth: 400, quality: 85);
    logger.d(file.lengthSync().toString());
    logger.d(result!.length.toString());
    return result;
  }

  Future processImage() async {
    _compressedPFP = await compressFile(_pfp!);
    await uploadFile();
  }

  Future processImageCover() async {
    _compressedCover = await compressFile(_cover!);
    await uploadFileCover();
  }

  Future uploadFile() async {
    try {
      final String base64Image = base64Encode(_compressedPFP);
      final github = GitHub(auth: Authentication.withToken(Env.normalize(Env.ghToken)));
      await github.repositories
          .createFile(
            RepositorySlug(Env.normalize(Env.ghUserName), Env.normalize(Env.ghRepoWalls)),
            CreateFile(message: Path.basename(_pfp!.path), content: base64Image, path: Path.basename(_pfp!.path)),
          )
          .then(
            (value) => setState(() {
              pfpUrl = value.content!.downloadUrl!;
              pfpPath = value.content!.path!;
              pfpSha = value.content!.sha!;
            }),
          );
      logger.d('File Uploaded');
      app_state.prismUser.profilePhoto = pfpUrl;
      app_state.persistPrismUser();
      await _updateCurrentUser(<String, dynamic>{"profilePhoto": pfpUrl}, 'profile.edit.profilePhoto');
    } catch (e) {
      logger.d(e.toString());
      toasts.error("Some uploading issue, please try again.");
    }
  }

  Future uploadFileCover() async {
    try {
      final String base64Image = base64Encode(_compressedCover);
      final github = GitHub(auth: Authentication.withToken(Env.normalize(Env.ghToken)));
      await github.repositories
          .createFile(
            RepositorySlug(Env.normalize(Env.ghUserName), Env.normalize(Env.ghRepoWalls)),
            CreateFile(message: Path.basename(_cover!.path), content: base64Image, path: Path.basename(_cover!.path)),
          )
          .then(
            (value) => setState(() {
              coverUrl = value.content!.downloadUrl!;
              coverPath = value.content!.path!;
              coverSha = value.content!.sha!;
            }),
          );
      logger.d('Cover File Uploaded');
      app_state.prismUser.coverPhoto = coverUrl;
      app_state.persistPrismUser();
      await _updateCurrentUser(<String, dynamic>{"coverPhoto": coverUrl}, 'profile.edit.coverPhoto');
    } catch (e) {
      logger.d(e.toString());
      toasts.error("Some uploading issue, please try again.");
    }
  }

  Future<void> showRemoveAlertDialog(BuildContext context, Future<void> Function() remove, String removeWhat) async {
    if (!mounted) {
      return;
    }

    await showModal(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          title: Text(
            'Delete the $removeWhat?',
            style: TextStyle(
              fontWeight: FontWeight.w700,
              fontSize: 16,
              color: Theme.of(dialogContext).colorScheme.secondary,
            ),
          ),
          content: Text(
            "This is permanent, and this action can't be undone!",
            style: TextStyle(
              fontFamily: "Proxima Nova",
              fontWeight: FontWeight.normal,
              fontSize: 14,
              color: Theme.of(dialogContext).colorScheme.secondary,
            ),
          ),
          actions: [
            MaterialButton(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(5)),
              color: Theme.of(dialogContext).hintColor,
              onPressed: () async {
                Navigator.of(dialogContext, rootNavigator: true).pop();
                if (!mounted) {
                  return;
                }
                await remove();
              },
              child: const Text('DELETE', style: TextStyle(fontSize: 16.0, color: Colors.white)),
            ),
            MaterialButton(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(5)),
              color: Theme.of(dialogContext).colorScheme.error,
              onPressed: () {
                Navigator.of(dialogContext, rootNavigator: true).pop();
              },
              child: const Text('CANCEL', style: TextStyle(fontSize: 16.0, color: Colors.white)),
            ),
          ],
          backgroundColor: Theme.of(dialogContext).primaryColor,
          actionsPadding: const EdgeInsets.fromLTRB(10, 0, 10, 0),
        );
      },
    );
  }

  Future<void> _updateCurrentUser(Map<String, dynamic> data, String sourceTag) {
    return firestoreClient.updateDoc(USER_NEW_COLLECTION, app_state.prismUser.id, data, sourceTag: sourceTag);
  }

  Future<bool> _isUsernameAvailable(String username) async {
    final users = await firestoreClient.query<Map<String, dynamic>>(
      FirestoreQuerySpec(
        collection: USER_NEW_COLLECTION,
        sourceTag: 'profile.edit.usernameAvailability',
        filters: <FirestoreFilter>[
          FirestoreFilter(field: "username", op: FirestoreFilterOp.isEqualTo, value: username),
        ],
        limit: 1,
      ),
      (data, _) => data,
    );
    return users.isEmpty;
  }

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.of(context).size.width * 0.85;
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(JamIcons.close),
          onPressed: () {
            Navigator.pop(context);
          },
        ),
        title: Text("Edit Profile", style: Theme.of(context).textTheme.displaySmall),
      ),
      backgroundColor: Theme.of(context).primaryColor,
      body: SingleChildScrollView(
        child: Container(
          height: MediaQuery.of(context).size.height,
          width: MediaQuery.of(context).size.width,
          decoration: BoxDecoration(
            color: Theme.of(context).primaryColor,
            borderRadius: const BorderRadius.only(topLeft: Radius.circular(20), topRight: Radius.circular(20)),
          ),
          child: Column(
            children: <Widget>[
              Stack(
                children: [
                  Container(
                    height: MediaQuery.of(context).size.width * 508 / 1234,
                    width: MediaQuery.of(context).size.width,
                    decoration: const BoxDecoration(
                      border: Border.fromBorderSide(BorderSide(color: Colors.white, width: 2)),
                    ),
                    child: (_cover == null)
                        ? (app_state.prismUser.coverPhoto != null &&
                                  Uri.tryParse(app_state.prismUser.coverPhoto!)?.hasAuthority == true)
                              ? CachedNetworkImage(imageUrl: app_state.prismUser.coverPhoto!, fit: BoxFit.cover)
                              : SvgPicture.string(
                                  defaultHeader
                                      .replaceAll(
                                        "#181818",
                                        "#${Theme.of(context).primaryColor.toARGB32().toRadixString(16).substring(2)}",
                                      )
                                      .replaceAll(
                                        "#E77597",
                                        "#${Theme.of(context).colorScheme.error.toARGB32().toRadixString(16).substring(2)}",
                                      ),
                                  fit: BoxFit.cover,
                                )
                        : Image.file(_cover!, fit: BoxFit.cover),
                  ),
                  Material(
                    child: InkWell(
                      onTap: () async {
                        await getCover();
                      },
                      child: Container(
                        height: MediaQuery.of(context).size.width * 508 / 1234,
                        width: MediaQuery.of(context).size.width,
                        decoration: BoxDecoration(
                          border: const Border.fromBorderSide(BorderSide(color: Colors.white, width: 2)),
                          color: Theme.of(context).colorScheme.error.withValues(alpha: 0.5),
                        ),
                        child: const Icon(JamIcons.pencil, color: Colors.white),
                      ),
                    ),
                  ),
                  Positioned(
                    right: 0,
                    child: IconButton(
                      onPressed: () async {
                        showRemoveAlertDialog(context, () async {
                          _cover = null;
                          app_state.prismUser.coverPhoto = null;
                          app_state.persistPrismUser();
                          await _updateCurrentUser(<String, dynamic>{
                            "coverPhoto": null,
                          }, 'profile.edit.removeCoverPhoto');
                        }, "Cover photo");
                      },
                      icon: const Icon(JamIcons.close),
                    ),
                  ),
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
                            border: Border.fromBorderSide(BorderSide(color: Colors.white, width: 2)),
                          ),
                          child: (_pfp == null)
                              ? (Uri.tryParse(app_state.prismUser.profilePhoto)?.hasAuthority == true)
                                    ? CachedNetworkImage(imageUrl: app_state.prismUser.profilePhoto, fit: BoxFit.cover)
                                    : const Icon(Icons.person, size: 60)
                              : Image.file(_pfp!, fit: BoxFit.cover),
                        ),
                        Container(
                          height: 100,
                          width: 100,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: const Border.fromBorderSide(BorderSide(color: Colors.white, width: 2)),
                            color: Theme.of(context).colorScheme.error.withValues(alpha: 0.5),
                          ),
                          child: const Icon(JamIcons.pencil, color: Colors.white),
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
                        style: Theme.of(context).textTheme.headlineSmall!.copyWith(color: Colors.white),
                        controller: nameController,
                        decoration: InputDecoration(
                          contentPadding: const EdgeInsets.only(left: 30, top: 15),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                            borderSide: const BorderSide(color: Colors.white, width: 2),
                          ),
                          disabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                            borderSide: const BorderSide(color: Colors.white, width: 2),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                            borderSide: const BorderSide(color: Colors.white, width: 2),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                            borderSide: const BorderSide(color: Colors.white, width: 2),
                          ),
                          labelText: "Name",
                          labelStyle: Theme.of(
                            context,
                          ).textTheme.headlineSmall!.copyWith(fontSize: 14, color: Colors.white),
                          prefixIcon: const Padding(
                            padding: EdgeInsets.all(16.0),
                            child: Text(
                              "Name",
                              style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold),
                            ),
                          ),
                        ),
                        onChanged: (value) async {
                          if (value == app_state.prismUser.name || value == "") {
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
                        style: Theme.of(context).textTheme.headlineSmall!.copyWith(color: Colors.white),
                        controller: usernameController,
                        decoration: InputDecoration(
                          contentPadding: const EdgeInsets.only(left: 30, top: 15),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                            borderSide: const BorderSide(color: Colors.white, width: 2),
                          ),
                          disabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                            borderSide: const BorderSide(color: Colors.white, width: 2),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                            borderSide: const BorderSide(color: Colors.white, width: 2),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                            borderSide: const BorderSide(color: Colors.white, width: 2),
                          ),
                          labelText: "username",
                          labelStyle: Theme.of(
                            context,
                          ).textTheme.headlineSmall!.copyWith(fontSize: 14, color: Colors.white),
                          prefixIcon: const Padding(
                            padding: EdgeInsets.all(16.0),
                            child: Text(
                              "@",
                              style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold),
                            ),
                          ),
                          suffixIcon: isCheckingUsername
                              ? Padding(
                                  padding: const EdgeInsets.all(16.0),
                                  child: SizedBox(
                                    width: 16,
                                    height: 16,
                                    child: CircularProgressIndicator(color: Theme.of(context).colorScheme.error),
                                  ),
                                )
                              : Padding(
                                  padding: EdgeInsets.all(available == null ? 16.0 : 8),
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
                                          available! ? JamIcons.check : JamIcons.close,
                                          color: available! ? Colors.green : Colors.red,
                                          size: 24,
                                        ),
                                ),
                        ),
                        onChanged: (value) async {
                          if (value != "" && value.length >= 8 && !value.contains(RegExp(r"(?: |[^\w\s])+"))) {
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
                            final isAvailable = await _isUsernameAvailable(value);
                            setState(() {
                              available = isAvailable;
                            });
                            setState(() {
                              isCheckingUsername = false;
                            });
                          } else {
                            setState(() {
                              available = null;
                            });
                          }
                          if (value == app_state.prismUser.username || value == "") {
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
                        style: Theme.of(context).textTheme.headlineSmall!.copyWith(color: Colors.white),
                        controller: bioController,
                        decoration: InputDecoration(
                          contentPadding: const EdgeInsets.only(left: 30, top: 15),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                            borderSide: const BorderSide(color: Colors.white, width: 2),
                          ),
                          disabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                            borderSide: const BorderSide(color: Colors.white, width: 2),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                            borderSide: const BorderSide(color: Colors.white, width: 2),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                            borderSide: const BorderSide(color: Colors.white, width: 2),
                          ),
                          labelText: "Bio",
                          labelStyle: Theme.of(
                            context,
                          ).textTheme.headlineSmall!.copyWith(fontSize: 14, color: Colors.white),
                          prefixIcon: const Padding(
                            padding: EdgeInsets.all(16.0),
                            child: Text(
                              "bio",
                              style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold),
                            ),
                          ),
                          suffixIcon: IconButton(
                            onPressed: () async {
                              showRemoveAlertDialog(context, () async {
                                bioController.text = "";
                                app_state.prismUser.bio = "";
                                app_state.persistPrismUser();
                                await _updateCurrentUser(<String, dynamic>{"bio": ""}, 'profile.edit.clearBio');
                              }, "bio");
                            },
                            icon: const Icon(JamIcons.close, color: Colors.red, size: 24),
                          ),
                        ),
                        onChanged: (value) {
                          if (value == app_state.prismUser.bio || value == "") {
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
                              child: DropdownButton<_ProfileLinkOption>(
                                isExpanded: true,
                                items: linkIcons.map((link) {
                                  return DropdownMenuItem(
                                    value: link,
                                    child: Row(
                                      crossAxisAlignment: CrossAxisAlignment.end,
                                      children: [
                                        Icon(link.icon),
                                        const SizedBox(width: 16),
                                        Text(
                                          link.name.inCaps,
                                          style: Theme.of(
                                            context,
                                          ).textTheme.headlineSmall!.copyWith(color: Colors.white, fontSize: 14),
                                        ),
                                      ],
                                    ),
                                  );
                                }).toList(),
                                underline: Container(),
                                onChanged: (value) {
                                  setState(() => _link = value);
                                  linkController.text = _link?.value ?? '';
                                },
                                icon: Container(),
                                value: _link,
                                dropdownColor: Theme.of(context).primaryColor,
                                selectedItemBuilder: (BuildContext context) {
                                  return linkIcons.map<Widget>((link) {
                                    return Padding(
                                      padding: const EdgeInsets.only(left: 12.0),
                                      child: Row(
                                        children: [Icon(link.icon), const Icon(JamIcons.chevron_down, size: 14)],
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
                                style: Theme.of(context).textTheme.headlineSmall!.copyWith(color: Colors.white),
                                controller: linkController,
                                decoration: InputDecoration(
                                  enabled: _link?.name != "Edit links...",
                                  contentPadding: const EdgeInsets.only(left: 30, top: 15),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(10),
                                    borderSide: const BorderSide(color: Colors.white, width: 2),
                                  ),
                                  disabledBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(10),
                                    borderSide: const BorderSide(color: Colors.white, width: 2),
                                  ),
                                  enabledBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(10),
                                    borderSide: const BorderSide(color: Colors.white, width: 2),
                                  ),
                                  focusedBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(10),
                                    borderSide: const BorderSide(color: Colors.white, width: 2),
                                  ),
                                  labelText: _link?.name.inCaps ?? "",
                                  labelStyle: Theme.of(
                                    context,
                                  ).textTheme.headlineSmall!.copyWith(fontSize: 14, color: Colors.white),
                                  hintText: _link?.link ?? "",
                                  hintStyle: Theme.of(
                                    context,
                                  ).textTheme.headlineSmall!.copyWith(fontSize: 14, color: Colors.white),
                                  suffixIcon: IconButton(
                                    onPressed: () async {
                                      showRemoveAlertDialog(context, () async {
                                        linkController.text = "";
                                        final links = app_state.prismUser.links;
                                        links.remove(_link?.name);
                                        app_state.prismUser.links = links;
                                        app_state.persistPrismUser();
                                        await _updateCurrentUser(<String, dynamic>{
                                          "links": app_state.prismUser.links,
                                        }, 'profile.edit.removeLink');
                                      }, "${_link?.name.inCaps}");
                                    },
                                    icon: const Icon(JamIcons.close, color: Colors.red, size: 24),
                                  ),
                                ),
                                onChanged: (value) {
                                  if (value.toLowerCase().contains('${_link?.validator.toLowerCase()}')) {
                                    setState(() {
                                      if (_link != null) {
                                        _link!.value = value;
                                      }
                                    });
                                    bool changed = false;
                                    for (int i = 0; i < linkIcons.length; i++) {
                                      if (linkIcons[i].value.isNotEmpty) {
                                        changed = true;
                                        break;
                                      }
                                    }
                                    setState(() {
                                      linkEdit = changed;
                                    });
                                  } else if (value == "") {
                                    bool changed = false;
                                    for (int i = 0; i < linkIcons.length; i++) {
                                      if (linkIcons[i].value.isNotEmpty) {
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
                  onTap: (!usernameEdit && (pfpEdit || bioEdit || linkEdit || coverEdit || nameEdit))
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
                            app_state.prismUser.bio = bioController.text;
                            app_state.persistPrismUser();
                            await _updateCurrentUser(<String, dynamic>{"bio": bioController.text}, 'profile.edit.bio');
                          }
                          if (linkEdit) {
                            final Map<String, String> links = Map<String, String>.from(app_state.prismUser.links);
                            for (int p = 0; p < linkIcons.length; p++) {
                              if (linkIcons[p].value.isNotEmpty) {
                                links[linkIcons[p].name] = linkIcons[p].value;
                              }
                            }
                            app_state.prismUser.links = links;
                            app_state.persistPrismUser();
                            await _updateCurrentUser(<String, dynamic>{"links": links}, 'profile.edit.links');
                          }
                          if (nameEdit && nameController.text != "") {
                            app_state.prismUser.name = nameController.text;
                            app_state.persistPrismUser();
                            await _updateCurrentUser(<String, dynamic>{
                              "name": nameController.text,
                            }, 'profile.edit.name');
                          }
                          await CoinsService.instance.maybeAwardProfileCompletion();
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
                          if (usernameEdit && usernameController.text != "" && usernameController.text.length >= 8) {
                            app_state.prismUser.username = usernameController.text;
                            app_state.persistPrismUser();
                            await _updateCurrentUser(<String, dynamic>{
                              "username": usernameController.text,
                            }, 'profile.edit.username');
                          }
                          if (_pfp != null && pfpEdit) {
                            await processImage();
                          }
                          if (_cover != null && coverEdit) {
                            await processImageCover();
                          }
                          if (bioEdit && bioController.text != "") {
                            app_state.prismUser.bio = bioController.text;
                            app_state.persistPrismUser();
                            await _updateCurrentUser(<String, dynamic>{
                              "bio": bioController.text,
                            }, 'profile.edit.bio.withUsername');
                          }
                          if (nameEdit && nameController.text != "") {
                            app_state.prismUser.name = nameController.text;
                            app_state.persistPrismUser();
                            await _updateCurrentUser(<String, dynamic>{
                              "name": nameController.text,
                            }, 'profile.edit.name.withUsername');
                          }
                          if (linkEdit) {
                            final Map<String, String> links = Map<String, String>.from(app_state.prismUser.links);
                            for (int p = 0; p < linkIcons.length; p++) {
                              if (linkIcons[p].value.isNotEmpty) {
                                links[linkIcons[p].name] = linkIcons[p].value;
                              }
                              if (_pfp != null && pfpEdit) {
                                await processImage();
                              }
                              if (_cover != null && coverEdit) {
                                await processImageCover();
                              }
                              if (bioEdit && bioController.text != "") {
                                app_state.prismUser.bio = bioController.text;
                                app_state.persistPrismUser();
                                await _updateCurrentUser(<String, dynamic>{
                                  "bio": bioController.text,
                                }, 'profile.edit.bio.withUsername');
                              }
                              if (nameEdit && nameController.text != "") {
                                app_state.prismUser.name = nameController.text;
                                app_state.persistPrismUser();
                                await _updateCurrentUser(<String, dynamic>{
                                  "name": nameController.text,
                                }, 'profile.edit.name.withUsername');
                              }
                              if (linkEdit) {
                                final Map<String, String> links = Map<String, String>.from(app_state.prismUser.links);
                                for (int p = 0; p < linkIcons.length; p++) {
                                  if (linkIcons[p].value.isNotEmpty) {
                                    links[linkIcons[p].name] = linkIcons[p].value;
                                  }
                                }
                                app_state.prismUser.links = links;
                                app_state.persistPrismUser();
                                await _updateCurrentUser(<String, dynamic>{
                                  "links": links,
                                }, 'profile.edit.links.withUsername');
                              }
                              await CoinsService.instance.maybeAwardProfileCompletion();
                              setState(() {
                                isLoading = false;
                              });
                              Navigator.pop(context);
                              toasts.codeSend("Details updated!");
                            }
                            app_state.prismUser.links = links;
                            app_state.persistPrismUser();
                            await _updateCurrentUser(<String, dynamic>{
                              "links": links,
                            }, 'profile.edit.links.withUsername');
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
                        color:
                            !((!usernameEdit && (pfpEdit || bioEdit || linkEdit || coverEdit || nameEdit)) ||
                                (usernameEdit && enabled))
                            ? Theme.of(context).primaryColor
                            : Theme.of(context).colorScheme.error.withValues(alpha: 0.2),
                        border: Border.all(
                          color:
                              !((!usernameEdit && (pfpEdit || bioEdit || linkEdit || coverEdit || nameEdit)) ||
                                  (usernameEdit && enabled))
                              ? Theme.of(context).colorScheme.secondary.withValues(alpha: 0.5)
                              : Theme.of(context).colorScheme.error,
                          width: 3,
                        ),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Center(
                        child: isLoading
                            ? CircularProgressIndicator(color: Theme.of(context).primaryColor)
                            : Text(
                                "Update",
                                style: TextStyle(
                                  fontSize: 16,
                                  color:
                                      !((!usernameEdit && (pfpEdit || bioEdit || linkEdit || coverEdit || nameEdit)) ||
                                          (usernameEdit && enabled))
                                      ? Theme.of(context).colorScheme.secondary.withValues(alpha: 0.5)
                                      : Theme.of(context).colorScheme.secondary,
                                  fontWeight: FontWeight.bold,
                                ),
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
                    style: TextStyle(fontSize: 13, color: Theme.of(context).colorScheme.secondary),
                  ),
                ),
              ),
              const Spacer(flex: 3),
            ],
          ),
        ),
      ),
    );
  }
}
