import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:Prism/core/coins/coins_service.dart';
import 'package:Prism/core/constants/profile_links.dart';
import 'package:Prism/core/firestore/firestore_collections.dart';
import 'package:Prism/core/firestore/firestore_query_specs.dart';
import 'package:Prism/core/firestore/firestore_runtime.dart';
import 'package:Prism/core/state/app_state.dart' as app_state;
import 'package:Prism/core/utils/theme_utils.dart';
import 'package:Prism/data/upload/github_content_api.dart';
import 'package:Prism/env/env.dart';
import 'package:Prism/global/svg_assets.dart';
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
import 'package:image_picker/image_picker.dart';
import 'package:path/path.dart' as path;

@RoutePage(name: 'EditProfilePanelRoute')
class EditProfilePanel extends StatefulWidget {
  const EditProfilePanel({super.key});

  @override
  _EditProfilePanelState createState() => _EditProfilePanelState();
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
  final picker2 = ImagePicker();
  late final Map<String, String> _linkValues = <String, String>{
    for (final ProfileLinkKind kind in profileLinkKinds) kind.name: app_state.prismUser.links[kind.name] ?? '',
  };
  ProfileLinkKind _link = profileLinkKinds.firstWhere((kind) => kind.name == customLinkName);

  @override
  void initState() {
    bioController = TextEditingController(text: app_state.prismUser.bio);
    usernameController = TextEditingController(text: app_state.prismUser.username);
    nameController = TextEditingController(text: app_state.prismUser.name);
    super.initState();
  }

  Future<void> _pickImage(ValueSetter<File> onPicked) async {
    final pickedFile = await picker2.pickImage(source: ImageSource.gallery);
    if (pickedFile != null) {
      setState(() => onPicked(File(pickedFile.path)));
    }
  }

  Future<Uint8List> compressFile(File file) async {
    final result = await FlutterImageCompress.compressWithFile(file.absolute.path, minWidth: 400, quality: 85);
    return result!;
  }

  Future<void> _uploadImage(File file, {required String field}) async {
    final Uint8List compressed = await compressFile(file);
    try {
      final value = await GitHubContentApi().putFile(
        repo: Env.normalize(Env.ghRepoWalls),
        message: path.basename(file.path),
        contentBase64: base64Encode(compressed),
        path: path.basename(file.path),
      );
      final String url = value.downloadUrl!;
      if (field == 'profilePhoto') {
        app_state.prismUser.profilePhoto = url;
      } else {
        app_state.prismUser.coverPhoto = url;
      }
      app_state.persistPrismUser();
      await _updateCurrentUser(<String, dynamic>{field: url}, 'profile.edit.$field');
    } catch (e) {
      logger.d(e.toString());
      toasts.error('Some uploading issue, please try again.');
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
    return firestoreClient.updateDoc(FirebaseCollections.usersV2, app_state.prismUser.id, data, sourceTag: sourceTag);
  }

  Future<bool> _isUsernameAvailable(String username) async {
    final users = await firestoreClient.query<Map<String, dynamic>>(
      FirestoreQuerySpec(
        collection: FirebaseCollections.usersV2,
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
      await _uploadImage(_pfp!, field: 'profilePhoto');
    }
    if (_cover != null && coverEdit) {
      await _uploadImage(_cover!, field: 'coverPhoto');
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
      _linkValues.forEach((name, value) {
        if (value.isNotEmpty) {
          links[name] = value;
        }
      });
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
          tooltip: 'Close',
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
          Semantics(
            button: true,
            label: 'Change cover photo',
            child: GestureDetector(
              onTap: () => _pickImage((file) {
                _cover = file;
                coverEdit = true;
              }),
              child: (_cover == null)
                  ? (app_state.prismUser.coverPhoto != null &&
                            Uri.tryParse(app_state.prismUser.coverPhoto!)?.hasAuthority == true)
                        ? CachedNetworkImage(
                            imageUrl: app_state.prismUser.coverPhoto!,
                            fit: BoxFit.cover,
                            errorWidget: (context, url, error) => const SizedBox.shrink(),
                          )
                        : SvgPicture.string(
                            defaultHeader
                                .replaceAll("#181818", "#${theme.primaryColor.rgbHex}")
                                .replaceAll("#E77597", "#${theme.colorScheme.error.rgbHex}"),
                            fit: BoxFit.cover,
                          )
                  : Image.file(_cover!, fit: BoxFit.cover),
            ),
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
              label: 'Remove cover photo',
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
        Semantics(
          button: true,
          label: 'Change profile photo',
          child: GestureDetector(
            onTap: () => _pickImage((file) {
              _pfp = file;
              pfpEdit = true;
            }),
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
                          ? CachedNetworkImage(
                              imageUrl: app_state.prismUser.profilePhoto,
                              fit: BoxFit.cover,
                              errorWidget: (context, url, error) => ColoredBox(
                                color: PrismColors.brandPink.withValues(alpha: 0.12),
                                child: Icon(
                                  Icons.person,
                                  size: size * 0.5,
                                  color: PrismColors.brandPink.withValues(alpha: 0.5),
                                ),
                              ),
                            )
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
        ),
        // Pink camera badge — brand-locked so it never goes cyan/blue.
        Positioned(
          bottom: 0,
          right: 0,
          child: ExcludeSemantics(
            child: GestureDetector(
              onTap: () => _pickImage((file) {
                _pfp = file;
                pfpEdit = true;
              }),
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
            tooltip: 'Remove bio',
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
          child: Semantics(
            label: 'Link type',
            child: DropdownButton<ProfileLinkKind>(
              menuWidth: 200,
              items: profileLinkKinds.map((link) {
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
                setState(() => _link = value!);
                linkController.text = _linkValues[_link.name] ?? '';
              },
              icon: const SizedBox.shrink(),
              value: _link,
              dropdownColor: theme.primaryColor,
              selectedItemBuilder: (BuildContext context) {
                return profileLinkKinds.map<Widget>((link) {
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
        ),
        const SizedBox(width: PrismProfile.linkSelectorGap),
        Expanded(
          child: TextField(
            cursorColor: PrismColors.brandPink,
            style: PrismTextStyles.fieldInputSmall(context),
            controller: linkController,
            decoration: _fieldDecoration(
              label: _link.name.inCaps,
              hintText: _link.placeholder,
              suffixIcon: IconButton(
                tooltip: 'Remove link',
                onPressed: () => showRemoveAlertDialog(context, () async {
                  linkController.text = '';
                  final links = app_state.prismUser.links;
                  links.remove(_link.name);
                  app_state.prismUser.links = links;
                  app_state.persistPrismUser();
                  await _updateCurrentUser(<String, dynamic>{
                    "links": app_state.prismUser.links,
                  }, 'profile.edit.removeLink');
                }, '${_link.name.inCaps} link'),
                icon: Icon(JamIcons.close, color: secondary.withValues(alpha: PrismFormField.iconOpacity), size: 20),
              ),
            ),
            onChanged: (value) {
              if (value.toLowerCase().contains(_link.validator.toLowerCase())) {
                _linkValues[_link.name] = value;
              } else if (value.isEmpty) {
                _linkValues[_link.name] = '';
              }
              final changed = _linkValues.values.any((v) => v.isNotEmpty);
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
      child: Semantics(
        button: true,
        enabled: isActive && !isLoading,
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

  Widget _iconChip({required IconData icon, required String label, required VoidCallback onTap}) {
    return Semantics(
      button: true,
      label: label,
      child: GestureDetector(
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
      ),
    );
  }
}
