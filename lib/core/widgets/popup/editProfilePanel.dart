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
    if (!mounted) return;

    await showModal(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Text(
            'Remove $removeWhat?',
            style: TextStyle(
              fontFamily: 'Proxima Nova',
              fontWeight: FontWeight.w700,
              fontSize: 17,
              color: Theme.of(dialogContext).colorScheme.secondary,
            ),
          ),
          content: Text(
            "This can't be undone.",
            style: TextStyle(
              fontFamily: 'Proxima Nova',
              fontWeight: FontWeight.normal,
              fontSize: 14,
              color: Theme.of(dialogContext).colorScheme.secondary.withValues(alpha: 0.65),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext, rootNavigator: true).pop(),
              child: Text(
                'Cancel',
                style: TextStyle(
                  fontFamily: 'Proxima Nova',
                  color: Theme.of(dialogContext).colorScheme.secondary,
                ),
              ),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Theme.of(dialogContext).hintColor,
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              onPressed: () async {
                Navigator.of(dialogContext, rootNavigator: true).pop();
                if (!mounted) return;
                await remove();
              },
              child: const Text(
                'Remove',
                style: TextStyle(fontFamily: 'Proxima Nova', fontWeight: FontWeight.w600),
              ),
            ),
          ],
          backgroundColor: Theme.of(dialogContext).primaryColor,
          actionsPadding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
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

  bool get _hasChanges =>
      (!usernameEdit && (pfpEdit || bioEdit || linkEdit || coverEdit || nameEdit)) ||
      (usernameEdit && enabled);

  Future<void> _saveProfile() async {
    setState(() => isLoading = true);

    if (usernameEdit && usernameController.text.isNotEmpty && usernameController.text.length >= 8) {
      app_state.prismUser.username = usernameController.text;
      app_state.persistPrismUser();
      await _updateCurrentUser(
        <String, dynamic>{"username": usernameController.text},
        'profile.edit.username',
      );
    }
    if (_pfp != null && pfpEdit) {
      await processImage();
    }
    if (_cover != null && coverEdit) {
      await processImageCover();
    }
    if (bioEdit && bioController.text.isNotEmpty) {
      app_state.prismUser.bio = bioController.text;
      app_state.persistPrismUser();
      await _updateCurrentUser(<String, dynamic>{"bio": bioController.text}, 'profile.edit.bio');
    }
    if (nameEdit && nameController.text.isNotEmpty) {
      app_state.prismUser.name = nameController.text;
      app_state.persistPrismUser();
      await _updateCurrentUser(<String, dynamic>{"name": nameController.text}, 'profile.edit.name');
    }
    if (linkEdit) {
      final Map<String, String> links = Map<String, String>.from(app_state.prismUser.links);
      for (final icon in linkIcons) {
        if (icon.value.isNotEmpty) {
          links[icon.name] = icon.value;
        }
      }
      app_state.prismUser.links = links;
      app_state.persistPrismUser();
      await _updateCurrentUser(<String, dynamic>{"links": links}, 'profile.edit.links');
    }

    await CoinsService.instance.maybeAwardProfileCompletion();
    setState(() => isLoading = false);
    if (mounted) {
      Navigator.pop(context);
      toasts.codeSend("Profile updated!");
    }
  }

  InputDecoration _fieldDecoration({
    required String label,
    Widget? prefixIcon,
    Widget? suffixIcon,
    String? hintText,
  }) {
    final accent = Theme.of(context).colorScheme.error;
    final secondary = Theme.of(context).colorScheme.secondary;
    final borderColor = secondary.withValues(alpha: 0.22);
    return InputDecoration(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: borderColor, width: 1.5),
      ),
      disabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: borderColor, width: 1.5),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: borderColor, width: 1.5),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: accent, width: 1.5),
      ),
      labelText: label,
      labelStyle: TextStyle(
        fontFamily: 'Proxima Nova',
        fontSize: 14,
        color: secondary.withValues(alpha: 0.55),
      ),
      hintText: hintText,
      hintStyle: TextStyle(
        fontFamily: 'Proxima Nova',
        fontSize: 13,
        color: secondary.withValues(alpha: 0.3),
      ),
      prefixIcon: prefixIcon,
      suffixIcon: suffixIcon,
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final accent = theme.colorScheme.error;
    final secondary = theme.colorScheme.secondary;
    final screenWidth = MediaQuery.of(context).size.width;
    final hPad = screenWidth * 0.06;
    const avatarSize = 88.0;
    const avatarOverlap = 44.0;

    return Scaffold(
      backgroundColor: theme.primaryColor,
      appBar: AppBar(
        backgroundColor: theme.primaryColor,
        elevation: 0,
        leading: IconButton(
          icon: Icon(JamIcons.close, color: secondary),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text('Edit Profile', style: theme.textTheme.displaySmall),
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Stack(
              clipBehavior: Clip.none,
              children: [
                _buildCoverArea(theme, screenWidth),
                Positioned(
                  left: hPad,
                  bottom: -avatarOverlap,
                  child: _buildAvatar(theme, accent, avatarSize),
                ),
              ],
            ),
            SizedBox(height: avatarOverlap + 16),
            Padding(
              padding: EdgeInsets.symmetric(horizontal: hPad),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _buildNameField(accent, secondary),
                  const SizedBox(height: 12),
                  _buildUsernameField(accent, secondary),
                  const SizedBox(height: 12),
                  _buildBioField(accent, secondary),
                  const SizedBox(height: 12),
                  _buildLinkRow(theme, accent, secondary),
                  const SizedBox(height: 28),
                  _buildSaveButton(accent, secondary),
                  const SizedBox(height: 16),
                  Center(child: _buildUsernameHint(secondary, screenWidth)),
                  const SizedBox(height: 40),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCoverArea(ThemeData theme, double screenWidth) {
    final coverHeight = screenWidth * 508 / 1234;
    return SizedBox(
      height: coverHeight,
      width: screenWidth,
      child: Stack(
        fit: StackFit.expand,
        children: [
          GestureDetector(
            onTap: getCover,
            child: (_cover == null)
                ? (app_state.prismUser.coverPhoto != null &&
                          Uri.tryParse(app_state.prismUser.coverPhoto!)?.hasAuthority == true)
                      ? CachedNetworkImage(imageUrl: app_state.prismUser.coverPhoto!, fit: BoxFit.cover)
                      : SvgPicture.string(
                          defaultHeader
                              .replaceAll(
                                "#181818",
                                "#${theme.primaryColor.toARGB32().toRadixString(16).substring(2)}",
                              )
                              .replaceAll(
                                "#E77597",
                                "#${theme.colorScheme.error.toARGB32().toRadixString(16).substring(2)}",
                              ),
                          fit: BoxFit.cover,
                        )
                : Image.file(_cover!, fit: BoxFit.cover),
          ),
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: IgnorePointer(
              child: Container(
                height: 52,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [Colors.transparent, Colors.black.withValues(alpha: 0.5)],
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(JamIcons.camera, color: Colors.white.withValues(alpha: 0.85), size: 15),
                    const SizedBox(width: 6),
                    Text(
                      'Edit cover',
                      style: TextStyle(
                        fontFamily: 'Proxima Nova',
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: Colors.white.withValues(alpha: 0.85),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          Positioned(
            top: 10,
            right: 10,
            child: _iconChip(
              icon: JamIcons.close,
              onTap: () => showRemoveAlertDialog(
                context,
                () async {
                  setState(() => _cover = null);
                  app_state.prismUser.coverPhoto = null;
                  app_state.persistPrismUser();
                  await _updateCurrentUser(
                    <String, dynamic>{"coverPhoto": null},
                    'profile.edit.removeCoverPhoto',
                  );
                },
                "cover photo",
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAvatar(ThemeData theme, Color accent, double size) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        GestureDetector(
          onTap: getPFP,
          child: Container(
            width: size,
            height: size,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: theme.primaryColor, width: 3),
            ),
            child: ClipOval(
              child: (_pfp == null)
                  ? (Uri.tryParse(app_state.prismUser.profilePhoto)?.hasAuthority == true)
                        ? CachedNetworkImage(imageUrl: app_state.prismUser.profilePhoto, fit: BoxFit.cover)
                        : Container(
                            color: accent.withValues(alpha: 0.12),
                            child: Icon(Icons.person, size: size * 0.5, color: accent.withValues(alpha: 0.5)),
                          )
                  : Image.file(_pfp!, fit: BoxFit.cover),
            ),
          ),
        ),
        Positioned(
          bottom: 0,
          right: 0,
          child: GestureDetector(
            onTap: getPFP,
            child: Container(
              width: 26,
              height: 26,
              decoration: BoxDecoration(
                color: accent,
                shape: BoxShape.circle,
                border: Border.all(color: theme.primaryColor, width: 2),
              ),
              child: const Icon(JamIcons.camera, size: 13, color: Colors.white),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildNameField(Color accent, Color secondary) {
    return TextField(
      cursorColor: accent,
      style: TextStyle(fontFamily: 'Proxima Nova', fontSize: 15, color: secondary),
      controller: nameController,
      decoration: _fieldDecoration(label: 'Name'),
      onChanged: (value) {
        setState(() {
          nameEdit = value.isNotEmpty && value != app_state.prismUser.name;
        });
      },
    );
  }

  Widget _buildUsernameField(Color accent, Color secondary) {
    return TextField(
      cursorColor: accent,
      style: TextStyle(fontFamily: 'Proxima Nova', fontSize: 15, color: secondary),
      controller: usernameController,
      decoration: _fieldDecoration(
        label: 'Username',
        prefixIcon: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
          child: Text(
            '@',
            style: TextStyle(
              fontFamily: 'Proxima Nova',
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: secondary.withValues(alpha: 0.45),
            ),
          ),
        ),
        suffixIcon: SizedBox(
          width: 48,
          height: 48,
          child: Center(
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 200),
              transitionBuilder: (child, anim) => ScaleTransition(scale: anim, child: child),
              child: isCheckingUsername
                  ? SizedBox(
                      key: const ValueKey('loading'),
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2, color: accent),
                    )
                  : available == null
                  ? const SizedBox.shrink(key: ValueKey('none'))
                  : Icon(
                      available! ? JamIcons.check : JamIcons.close,
                      key: ValueKey(available),
                      color: available! ? Colors.green : Colors.red,
                      size: 20,
                    ),
            ),
          ),
        ),
      ),
      onChanged: (value) async {
        final valid = value.isNotEmpty && value.length >= 8 && !value.contains(RegExp(r"(?: |[^\w\s])+"));
        setState(() => enabled = valid);

        if (valid) {
          setState(() => isCheckingUsername = true);
          final isAvailable = await _isUsernameAvailable(value);
          if (mounted) {
            setState(() {
              available = isAvailable;
              isCheckingUsername = false;
            });
          }
        } else {
          setState(() => available = null);
        }

        setState(() {
          usernameEdit = value.isNotEmpty && value != app_state.prismUser.username;
          if (!usernameEdit) available = null;
        });
      },
    );
  }

  Widget _buildBioField(Color accent, Color secondary) {
    return TextField(
      cursorColor: accent,
      style: TextStyle(fontFamily: 'Proxima Nova', fontSize: 15, color: secondary),
      controller: bioController,
      maxLength: 150,
      maxLines: 2,
      decoration: _fieldDecoration(
        label: 'Bio',
        suffixIcon: Align(
          alignment: Alignment.topRight,
          child: Padding(
            padding: const EdgeInsets.only(top: 4),
            child: IconButton(
              onPressed: () => showRemoveAlertDialog(
                context,
                () async {
                  bioController.text = '';
                  app_state.prismUser.bio = '';
                  app_state.persistPrismUser();
                  await _updateCurrentUser(<String, dynamic>{"bio": ""}, 'profile.edit.clearBio');
                },
                "bio",
              ),
              icon: Icon(JamIcons.close, color: secondary.withValues(alpha: 0.4), size: 20),
            ),
          ),
        ),
      ),
      onChanged: (value) {
        setState(() {
          bioEdit = value.isNotEmpty && value != app_state.prismUser.bio;
        });
      },
    );
  }

  Widget _buildLinkRow(ThemeData theme, Color accent, Color secondary) {
    final borderColor = secondary.withValues(alpha: 0.22);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Container(
          height: 56,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: borderColor, width: 1.5),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: DropdownButton<_ProfileLinkOption>(
            menuWidth: 200,
            items: linkIcons.map((link) {
              return DropdownMenuItem(
                value: link,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Icon(link.icon, size: 18, color: secondary),
                    const SizedBox(width: 12),
                    Text(
                      link.name.inCaps,
                      style: TextStyle(fontFamily: 'Proxima Nova', fontSize: 14, color: secondary),
                    ),
                  ],
                ),
              );
            }).toList(),
            underline: const SizedBox.shrink(),
            onChanged: (value) {
              setState(() => _link = value);
              linkController.text = _link?.value ?? '';
            },
            icon: const SizedBox.shrink(),
            value: _link,
            dropdownColor: theme.primaryColor,
            selectedItemBuilder: (BuildContext context) {
              return linkIcons.map<Widget>((link) {
                return Center(
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(link.icon, size: 20, color: secondary),
                      const SizedBox(width: 4),
                      Icon(JamIcons.chevron_down, size: 12, color: secondary.withValues(alpha: 0.5)),
                    ],
                  ),
                );
              }).toList();
            },
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: TextField(
            cursorColor: accent,
            style: TextStyle(fontFamily: 'Proxima Nova', fontSize: 14, color: secondary),
            controller: linkController,
            decoration: _fieldDecoration(
              label: _link?.name.inCaps ?? '',
              hintText: _link?.link,
              suffixIcon: IconButton(
                onPressed: () => showRemoveAlertDialog(
                  context,
                  () async {
                    linkController.text = '';
                    final links = app_state.prismUser.links;
                    links.remove(_link?.name);
                    app_state.prismUser.links = links;
                    app_state.persistPrismUser();
                    await _updateCurrentUser(
                      <String, dynamic>{"links": app_state.prismUser.links},
                      'profile.edit.removeLink',
                    );
                  },
                  "${_link?.name.inCaps} link",
                ),
                icon: Icon(JamIcons.close, color: secondary.withValues(alpha: 0.4), size: 20),
              ),
            ),
            onChanged: (value) {
              if (value.toLowerCase().contains('${_link?.validator.toLowerCase()}')) {
                if (_link != null) _link!.value = value;
              } else if (value.isEmpty) {
                if (_link != null) _link!.value = '';
              }
              final changed = linkIcons.any((icon) => icon.value.isNotEmpty);
              setState(() => linkEdit = changed);
            },
          ),
        ),
      ],
    );
  }

  Widget _buildSaveButton(Color accent, Color secondary) {
    final isActive = _hasChanges;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOutQuart,
      height: 56,
      decoration: BoxDecoration(
        color: isActive ? accent.withValues(alpha: 0.12) : Colors.transparent,
        border: Border.all(
          color: isActive ? accent : secondary.withValues(alpha: 0.18),
          width: 1.5,
        ),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: isActive && !isLoading ? _saveProfile : null,
          child: Center(
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 180),
              child: isLoading
                  ? SizedBox(
                      key: const ValueKey('loading'),
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(strokeWidth: 2.5, color: accent),
                    )
                  : Text(
                      'Update',
                      key: const ValueKey('text'),
                      style: TextStyle(
                        fontFamily: 'Proxima Nova',
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: isActive ? secondary : secondary.withValues(alpha: 0.28),
                      ),
                    ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildUsernameHint(Color secondary, double screenWidth) {
    return SizedBox(
      width: screenWidth * 0.75,
      child: Text(
        "Usernames must be 8+ characters with no symbols except underscore (_).",
        textAlign: TextAlign.center,
        style: TextStyle(
          fontFamily: 'Proxima Nova',
          fontSize: 12,
          color: secondary.withValues(alpha: 0.4),
        ),
      ),
    );
  }

  Widget _iconChip({required IconData icon, required VoidCallback onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 32,
        height: 32,
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.45),
          shape: BoxShape.circle,
        ),
        child: Icon(icon, color: Colors.white, size: 15),
      ),
    );
  }
}
