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
import 'package:Prism/theme/app_tokens.dart';
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
        final cs = Theme.of(dialogContext).colorScheme;
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(PrismProfile.dialogBorderRadius)),
          title: Text(
            'Remove $removeWhat?',
            style: TextStyle(
              fontFamily: PrismFonts.proximaNova,
              fontWeight: FontWeight.w700,
              fontSize: PrismProfile.dialogTitleFontSize,
              color: cs.secondary,
            ),
          ),
          content: Text(
            "This can't be undone.",
            style: TextStyle(
              fontFamily: PrismFonts.proximaNova,
              fontWeight: FontWeight.normal,
              fontSize: PrismProfile.dialogBodyFontSize,
              color: cs.secondary.withValues(alpha: PrismProfile.dialogBodyOpacity),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext, rootNavigator: true).pop(),
              child: Text(
                'Cancel',
                style: TextStyle(fontFamily: PrismFonts.proximaNova, color: cs.secondary),
              ),
            ),
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: PrismColors.brandPink,
                foregroundColor: PrismColors.onPrimary,
                elevation: 0,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(PrismProfile.dialogButtonRadius)),
              ),
              onPressed: () async {
                Navigator.of(dialogContext, rootNavigator: true).pop();
                if (!mounted) return;
                await remove();
              },
              child: const Text(
                'Remove',
                style: TextStyle(fontFamily: PrismFonts.proximaNova, fontWeight: FontWeight.w600),
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
      (!usernameEdit && (pfpEdit || bioEdit || linkEdit || coverEdit || nameEdit)) || (usernameEdit && enabled);

  Future<void> _saveProfile() async {
    setState(() => isLoading = true);

    if (usernameEdit && usernameController.text.isNotEmpty && usernameController.text.length >= 8) {
      app_state.prismUser.username = usernameController.text;
      app_state.persistPrismUser();
      await _updateCurrentUser(<String, dynamic>{"username": usernameController.text}, 'profile.edit.username');
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

  InputDecoration _fieldDecoration({required String label, Widget? prefixIcon, Widget? suffixIcon, String? hintText}) {
    final secondary = Theme.of(context).colorScheme.secondary;
    final borderColor = secondary.withValues(alpha: PrismFormField.restingBorderOpacity);
    final borderSide = BorderSide(color: borderColor, width: PrismFormField.borderWidth);
    final radius = BorderRadius.circular(PrismFormField.borderRadius);
    return InputDecoration(
      contentPadding: PrismFormField.contentPadding,
      border: OutlineInputBorder(borderRadius: radius, borderSide: borderSide),
      disabledBorder: OutlineInputBorder(borderRadius: radius, borderSide: borderSide),
      enabledBorder: OutlineInputBorder(borderRadius: radius, borderSide: borderSide),
      focusedBorder: OutlineInputBorder(
        borderRadius: radius,
        borderSide: const BorderSide(color: PrismColors.brandPink, width: PrismFormField.borderWidth),
      ),
      labelText: label,
      labelStyle: TextStyle(
        fontFamily: PrismFonts.proximaNova,
        fontSize: PrismFormField.labelFontSize,
        color: secondary.withValues(alpha: PrismFormField.labelOpacity),
      ),
      hintText: hintText,
      hintStyle: TextStyle(
        fontFamily: PrismFonts.proximaNova,
        fontSize: PrismFormField.hintFontSize,
        color: secondary.withValues(alpha: PrismFormField.hintOpacity),
      ),
      prefixIcon: prefixIcon,
      suffixIcon: suffixIcon,
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final secondary = theme.colorScheme.secondary;
    final screenWidth = MediaQuery.of(context).size.width;
    // Percentage-based padding keeps avatar positioning consistent across screen widths.
    final hPad = screenWidth * 0.06;

    return Scaffold(
      backgroundColor: theme.primaryColor,
      appBar: AppBar(
        backgroundColor: theme.primaryColor,
        elevation: 0,
        leading: IconButton(
          icon: Icon(JamIcons.close, color: secondary),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text('Edit Profile', style: PrismTextStyles.panelTitle(context)),
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
                  bottom: -PrismProfile.avatarOverlap,
                  child: _buildAvatar(theme, PrismProfile.avatarSize),
                ),
              ],
            ),
            const SizedBox(height: PrismProfile.avatarOverlap + 16),
            Padding(
              padding: EdgeInsets.symmetric(horizontal: hPad),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _buildNameField(secondary),
                  const SizedBox(height: PrismProfile.fieldGap),
                  _buildUsernameField(secondary),
                  const SizedBox(height: PrismProfile.fieldGap),
                  _buildBioField(secondary),
                  const SizedBox(height: PrismProfile.fieldGap),
                  _buildLinkRow(theme, secondary),
                  const SizedBox(height: PrismProfile.preSaveGap),
                  _buildSaveButton(secondary),
                  const SizedBox(height: PrismProfile.postSaveGap),
                  Center(child: _buildUsernameHint(screenWidth)),
                  const SizedBox(height: PrismProfile.bottomPadding),
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
                              .replaceAll("#181818", "#${theme.primaryColor.toARGB32().toRadixString(16).substring(2)}")
                              .replaceAll(
                                "#E77597",
                                "#${theme.colorScheme.error.toARGB32().toRadixString(16).substring(2)}",
                              ),
                          fit: BoxFit.cover,
                        )
                : Image.file(_cover!, fit: BoxFit.cover),
          ),
          // "Edit cover" scrim hint — always legible over any cover image.
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: IgnorePointer(
              child: Container(
                height: PrismProfile.coverScrimHeight,
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
                    Icon(
                      JamIcons.camera,
                      color: PrismColors.onPrimary.withValues(alpha: 0.85),
                      size: PrismProfile.coverEditIconSize,
                    ),
                    const SizedBox(width: PrismProfile.coverEditIconGap),
                    Text(
                      'Edit cover',
                      style: PrismTextStyles.photoOverlayLabel.copyWith(
                        color: PrismColors.onPrimary.withValues(alpha: 0.85),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          // Remove cover photo button.
          Positioned(
            top: PrismProfile.removeChipPositionOffset,
            right: PrismProfile.removeChipPositionOffset,
            child: _iconChip(
              icon: JamIcons.close,
              onTap: () => showRemoveAlertDialog(context, () async {
                setState(() => _cover = null);
                app_state.prismUser.coverPhoto = null;
                app_state.persistPrismUser();
                await _updateCurrentUser(<String, dynamic>{"coverPhoto": null}, 'profile.edit.removeCoverPhoto');
              }, "cover photo"),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAvatar(ThemeData theme, double size) {
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
              border: Border.all(color: theme.primaryColor, width: PrismProfile.avatarBorderWidth),
            ),
            child: ClipOval(
              child: (_pfp == null)
                  ? (Uri.tryParse(app_state.prismUser.profilePhoto)?.hasAuthority == true)
                        ? CachedNetworkImage(imageUrl: app_state.prismUser.profilePhoto, fit: BoxFit.cover)
                        : ColoredBox(
                            color: PrismColors.brandPink.withValues(alpha: 0.12),
                            child: Icon(
                              Icons.person,
                              size: size * 0.5,
                              color: PrismColors.brandPink.withValues(alpha: 0.5),
                            ),
                          )
                  : Image.file(_pfp!, fit: BoxFit.cover),
            ),
          ),
        ),
        // Pink camera badge — brand-locked so it never goes cyan/blue.
        Positioned(
          bottom: 0,
          right: 0,
          child: GestureDetector(
            onTap: getPFP,
            child: Container(
              width: PrismProfile.cameraChipSize,
              height: PrismProfile.cameraChipSize,
              decoration: BoxDecoration(
                color: PrismColors.brandPink,
                shape: BoxShape.circle,
                border: Border.all(color: theme.primaryColor, width: PrismProfile.cameraChipBorderWidth),
              ),
              child: const Icon(JamIcons.camera, size: PrismProfile.cameraChipIconSize, color: PrismColors.onPrimary),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildNameField(Color secondary) {
    return TextField(
      cursorColor: PrismColors.brandPink,
      style: PrismTextStyles.fieldInput(context),
      controller: nameController,
      decoration: _fieldDecoration(label: 'Name'),
      onChanged: (value) {
        setState(() {
          nameEdit = value.isNotEmpty && value != app_state.prismUser.name;
        });
      },
    );
  }

  Widget _buildUsernameField(Color secondary) {
    return TextField(
      cursorColor: PrismColors.brandPink,
      style: PrismTextStyles.fieldInput(context),
      controller: usernameController,
      decoration: _fieldDecoration(
        label: 'Username',
        prefixIcon: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
          child: Text(
            '@',
            style: TextStyle(
              fontFamily: PrismFonts.proximaNova,
              fontSize: PrismFormField.inputFontSize,
              fontWeight: FontWeight.w600,
              color: secondary.withValues(alpha: 0.45),
            ),
          ),
        ),
        suffixIcon: SizedBox(
          width: PrismFormField.availabilityIndicatorSize,
          height: PrismFormField.availabilityIndicatorSize,
          child: Center(
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 200),
              transitionBuilder: (child, anim) => ScaleTransition(scale: anim, child: child),
              child: isCheckingUsername
                  ? const SizedBox(
                      key: ValueKey('loading'),
                      width: PrismFormField.availabilitySpinnerSize,
                      height: PrismFormField.availabilitySpinnerSize,
                      child: CircularProgressIndicator(strokeWidth: 2, color: PrismColors.brandPink),
                    )
                  : available == null
                  ? const SizedBox.shrink(key: ValueKey('none'))
                  : Icon(
                      available! ? JamIcons.check : JamIcons.close,
                      key: ValueKey(available),
                      // Soft semantic green for available; theme error for taken.
                      color: available! ? Colors.green.shade400 : Colors.red.shade400,
                      size: PrismFormField.availabilityIconSize,
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

  Widget _buildBioField(Color secondary) {
    return Stack(
      children: [
        TextField(
          cursorColor: PrismColors.brandPink,
          style: PrismTextStyles.fieldInput(context),
          controller: bioController,
          maxLength: 150,
          maxLines: 2,
          decoration: _fieldDecoration(label: 'Bio', hintText: 'Tell people about yourself…').copyWith(
            counterStyle: PrismTextStyles.fieldCaption(context).copyWith(fontSize: 10),
            contentPadding: PrismFormField.contentPadding.add(const EdgeInsets.only(right: 36)),
          ),
          onChanged: (value) {
            setState(() {
              bioEdit = value.isNotEmpty && value != app_state.prismUser.bio;
            });
          },
        ),
        Positioned(
          top: 0,
          right: 0,
          child: IconButton(
            onPressed: () => showRemoveAlertDialog(context, () async {
              bioController.text = '';
              app_state.prismUser.bio = '';
              app_state.persistPrismUser();
              await _updateCurrentUser(<String, dynamic>{"bio": ""}, 'profile.edit.clearBio');
            }, "bio"),
            icon: Icon(JamIcons.close, color: secondary.withValues(alpha: PrismFormField.iconOpacity), size: 20),
          ),
        ),
      ],
    );
  }

  Widget _buildLinkRow(ThemeData theme, Color secondary) {
    final borderColor = secondary.withValues(alpha: PrismFormField.restingBorderOpacity);
    return Row(
      children: [
        Container(
          height: PrismProfile.linkSelectorHeight,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(PrismFormField.borderRadius),
            border: Border.all(color: borderColor, width: PrismFormField.borderWidth),
          ),
          padding: const EdgeInsets.symmetric(horizontal: PrismProfile.linkSelectorHorizontalPadding),
          child: DropdownButton<_ProfileLinkOption>(
            menuWidth: 200,
            items: linkIcons.map((link) {
              return DropdownMenuItem(
                value: link,
                child: Row(
                  children: [
                    Icon(link.icon, size: PrismProfile.linkDropdownIconSize, color: secondary),
                    const SizedBox(width: PrismProfile.linkDropdownTextGap),
                    Text(
                      link.name.inCaps,
                      style: TextStyle(
                        fontFamily: PrismFonts.proximaNova,
                        fontSize: PrismProfile.linkDropdownFontSize,
                        color: secondary,
                      ),
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
                      Icon(link.icon, size: PrismProfile.linkSelectorIconSize, color: secondary),
                      const SizedBox(width: 4),
                      Icon(
                        JamIcons.chevron_down,
                        size: PrismProfile.linkSelectorCaretSize,
                        color: secondary.withValues(alpha: 0.5),
                      ),
                    ],
                  ),
                );
              }).toList();
            },
          ),
        ),
        const SizedBox(width: PrismProfile.linkSelectorGap),
        Expanded(
          child: TextField(
            cursorColor: PrismColors.brandPink,
            style: PrismTextStyles.fieldInputSmall(context),
            controller: linkController,
            decoration: _fieldDecoration(
              label: _link?.name.inCaps ?? '',
              hintText: _link?.link,
              suffixIcon: IconButton(
                onPressed: () => showRemoveAlertDialog(context, () async {
                  linkController.text = '';
                  final links = app_state.prismUser.links;
                  links.remove(_link?.name);
                  app_state.prismUser.links = links;
                  app_state.persistPrismUser();
                  await _updateCurrentUser(<String, dynamic>{
                    "links": app_state.prismUser.links,
                  }, 'profile.edit.removeLink');
                }, "${_link?.name.inCaps} link"),
                icon: Icon(JamIcons.close, color: secondary.withValues(alpha: PrismFormField.iconOpacity), size: 20),
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

  Widget _buildSaveButton(Color secondary) {
    final isActive = _hasChanges;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOutQuart,
      height: PrismProfile.saveButtonHeight,
      decoration: BoxDecoration(
        // Brand pink tint when active — consistent with all other primary actions.
        color: isActive ? PrismColors.brandPink.withValues(alpha: 0.12) : Colors.transparent,
        border: Border.all(
          color: isActive ? PrismColors.brandPink : secondary.withValues(alpha: 0.18),
          width: PrismFormField.borderWidth,
        ),
        borderRadius: BorderRadius.circular(PrismFormField.borderRadius),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(PrismFormField.borderRadius),
          onTap: isActive && !isLoading ? _saveProfile : null,
          child: Center(
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 180),
              child: isLoading
                  ? const SizedBox(
                      key: ValueKey('loading'),
                      width: PrismProfile.savingIndicatorSize,
                      height: PrismProfile.savingIndicatorSize,
                      child: CircularProgressIndicator(
                        strokeWidth: PrismProfile.savingIndicatorStrokeWidth,
                        color: PrismColors.brandPink,
                      ),
                    )
                  : Text(
                      'Update',
                      key: const ValueKey('text'),
                      style: TextStyle(
                        fontFamily: PrismFonts.proximaNova,
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

  Widget _buildUsernameHint(double screenWidth) {
    return SizedBox(
      width: screenWidth * 0.75,
      child: Text(
        "Usernames must be 8+ characters with no symbols except underscore (_).",
        textAlign: TextAlign.center,
        style: PrismTextStyles.fieldCaption(context),
      ),
    );
  }

  Widget _iconChip({required IconData icon, required VoidCallback onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: PrismProfile.removeChipSize,
        height: PrismProfile.removeChipSize,
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: PrismProfile.removeChipScrimAlpha),
          shape: BoxShape.circle,
        ),
        child: Icon(icon, color: PrismColors.onPrimary, size: PrismProfile.removeChipIconSize),
      ),
    );
  }
}
