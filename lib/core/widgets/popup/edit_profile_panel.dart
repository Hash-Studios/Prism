import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:Prism/auth/google_profile_sync.dart';
import 'package:Prism/auth/user_model.dart';
import 'package:Prism/core/account/username_service.dart';
import 'package:Prism/core/coins/coins_service.dart';
import 'package:Prism/core/constants/profile_links.dart';
import 'package:Prism/core/firestore/firestore_collections.dart';
import 'package:Prism/core/firestore/firestore_runtime.dart';
import 'package:Prism/core/haptics/prism_haptics.dart';
import 'package:Prism/core/profile/profile_link_type_label.dart';
import 'package:Prism/core/state/app_state.dart' as app_state;
import 'package:Prism/core/widgets/prism/prism_ui.dart';
import 'package:Prism/data/upload/github_content_api.dart';
import 'package:Prism/env/env.dart';
import 'package:Prism/features/public_profile/views/widgets/edit_profile_header.dart';
import 'package:Prism/features/public_profile/views/widgets/edit_profile_link_field.dart';
import 'package:Prism/l10n/l10n.dart';
import 'package:Prism/logger/logger.dart';
import 'package:Prism/theme/toasts.dart' as toasts;
import 'package:auto_route/auto_route.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path/path.dart' as path;

/// `<uid>_<epochMs>_<basename>`: unique per user and per upload, so one upload never overwrites another.
@visibleForTesting
String uploadFileName(String uid, String basename, {int? epochMs}) =>
    '${uid}_${epochMs ?? DateTime.now().millisecondsSinceEpoch}_$basename';

/// The photo on the signed-in Firebase user. Google sign-in keeps it equal to the Google account photo.
@visibleForTesting
String? Function() signedInAccountPhoto = () => FirebaseAuth.instance.currentUser?.photoURL;

@RoutePage(name: 'EditProfilePanelRoute')
class EditProfilePanel extends StatefulWidget {
  const EditProfilePanel({super.key});

  @override
  _EditProfilePanelState createState() => _EditProfilePanelState();
}

class _EditProfilePanelState extends State<EditProfilePanel> {
  String get _usernameRule => context.l10n.coreEditUsernameRule(minUsernameLength);

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
  String? _usernameError;
  final Set<String> _invalidLinks = <String>{};
  bool isCheckingUsername = false;
  Timer? _usernameDebounce;
  int _usernameCheckId = 0;
  File? _pfp;
  File? _cover;
  final picker2 = ImagePicker();
  bool _picking = false;
  late final Map<String, String> _linkValues = <String, String>{
    for (final ProfileLinkKind kind in profileLinkKinds) kind.name: app_state.prismUser.links[kind.name] ?? '',
  };
  ProfileLinkKind _link = profileLinkKinds.firstWhere((kind) => kind.name == customLinkName);

  @override
  void initState() {
    bioController = TextEditingController(text: app_state.prismUser.bio);
    usernameController = TextEditingController(text: app_state.prismUser.username);
    nameController = TextEditingController(text: app_state.prismUser.name);
    linkController.text = _linkValues[_link.name] ?? '';
    super.initState();
  }

  @override
  void dispose() {
    _usernameDebounce?.cancel();
    linkController.dispose();
    bioController.dispose();
    usernameController.dispose();
    nameController.dispose();
    super.dispose();
  }

  Future<void> _pickImage(ValueSetter<File> onPicked) async {
    if (_picking) return;
    _picking = true;
    PrismHaptics.tap();
    try {
      final pickedFile = await picker2.pickImage(source: ImageSource.gallery);
      if (pickedFile != null) {
        setState(() => onPicked(File(pickedFile.path)));
      }
    } on PlatformException catch (error) {
      // already_active means another screen has the gallery open, and the user is choosing there.
      if (error.code != 'already_active') rethrow;
    } finally {
      _picking = false;
    }
  }

  Future<Uint8List> compressFile(File file, {required int minWidth}) async {
    final result = await FlutterImageCompress.compressWithFile(file.absolute.path, minWidth: minWidth, quality: 85);
    return result!;
  }

  /// Uploads [file] under a name no other user or upload can share and returns its download URL.
  Future<String> _uploadImage(
    File file, {
    required int minWidth,
    required String ownerId,
    required bool Function() ownsSession,
  }) async {
    final Uint8List compressed = await compressFile(file, minWidth: minWidth);
    if (!ownsSession()) throw StateError('The profile session changed during image compression.');
    final String fileName = uploadFileName(ownerId, path.basename(file.path));
    final value = await GitHubContentApi().putFile(
      repo: Env.normalize(Env.ghRepoWalls),
      message: fileName,
      contentBase64: base64Encode(compressed),
      path: fileName,
    );
    return value.downloadUrl!;
  }

  /// Asks before removing [removeWhat], then runs [remove].
  Future<void> _confirmRemove(Future<void> Function() remove, String removeWhat, {String? title}) async {
    final AppLocalizations l10n = context.l10n;
    final bool ok = await showPrismConfirm(
      context,
      title: title ?? l10n.coreEditRemoveTitle(removeWhat),
      message: l10n.corePopupCannotUndo,
      confirmLabel: l10n.coreEditRemoveConfirm,
      destructive: true,
    );
    if (ok && mounted) await remove();
  }

  /// Puts back the Google account photo, or the placeholder when there is none. Later Google sign-ins keep it current.
  /// The custom photo stays when the write fails.
  Future<void> _removePhoto() async {
    final AppLocalizations l10n = context.l10n;
    final String photo = photoOrPlaceholder(signedInAccountPhoto());
    try {
      await _updateCurrentUser(<String, dynamic>{'profilePhoto': photo}, 'profile.edit.removePhoto');
    } catch (e) {
      logger.d(e.toString());
      toasts.error(l10n.coreProfileSaveFailed);
      return;
    }
    app_state.prismUser.profilePhoto = photo;
    app_state.persistPrismUser();
    if (mounted) setState(() {});
  }

  Future<void> _updateCurrentUser(Map<String, dynamic> data, String sourceTag) {
    return firestoreClient.updateDoc(FirebaseCollections.usersV2, app_state.prismUser.id, data, sourceTag: sourceTag);
  }

  Future<bool> _isUsernameAvailable(String username) {
    return UsernameService.instance.isAvailable(username, app_state.prismUser.id);
  }

  bool get _hasChanges {
    final bool usernameOk = !usernameEdit || (enabled && available == true && !isCheckingUsername);
    return (usernameEdit || pfpEdit || bioEdit || linkEdit || coverEdit || nameEdit) &&
        usernameOk &&
        _invalidLinks.isEmpty;
  }

  bool get _hasUnsavedChanges => pfpEdit || bioEdit || linkEdit || coverEdit || nameEdit || usernameEdit;

  Future<void> _saveProfile() async {
    final PrismUsersV2 user = app_state.prismUser;
    final String ownerId = user.id;
    bool ownsSession() => mounted && identical(app_state.prismUser, user) && user.id == ownerId;
    final AppLocalizations l10n = context.l10n;
    if (usernameEdit && available != true) {
      toasts.error(l10n.coreChooseUsername);
      return;
    }
    setState(() => isLoading = true);
    try {
      final Map<String, dynamic> updates = <String, dynamic>{};
      if (usernameEdit && usernameController.text.length >= minUsernameLength) {
        final String claimed = await UsernameService.instance.claim(usernameController.text);
        if (!ownsSession()) return;
        user.username = claimed;
        await app_state.persistPrismUser();
        if (!ownsSession()) return;
      }
      if (_pfp != null && pfpEdit) {
        updates['profilePhoto'] = await _uploadImage(_pfp!, minWidth: 400, ownerId: ownerId, ownsSession: ownsSession);
        if (!ownsSession()) return;
      }
      if (_cover != null && coverEdit) {
        updates['coverPhoto'] = await _uploadImage(_cover!, minWidth: 1080, ownerId: ownerId, ownsSession: ownsSession);
        if (!ownsSession()) return;
      }
      if (bioEdit) {
        updates['bio'] = bioController.text;
      }
      if (nameEdit && nameController.text.isNotEmpty) {
        updates['name'] = nameController.text;
      }
      if (linkEdit) {
        final Map<String, String> links = Map<String, String>.from(user.links);
        _linkValues.forEach((name, value) {
          if (value.isNotEmpty) {
            links[name] = value;
          }
        });
        updates['links'] = links;
      }
      if (updates.isNotEmpty) {
        if (!ownsSession()) return;
        await firestoreClient.updateDoc(FirebaseCollections.usersV2, ownerId, updates, sourceTag: 'profile.edit.save');
        if (!ownsSession()) return;
      }

      if (!ownsSession()) return;
      if (updates['profilePhoto'] != null) user.profilePhoto = updates['profilePhoto'] as String;
      if (updates['coverPhoto'] != null) user.coverPhoto = updates['coverPhoto'] as String;
      if (updates['bio'] != null) user.bio = updates['bio'] as String;
      if (updates['name'] != null) user.name = updates['name'] as String;
      if (updates['links'] != null) user.links = updates['links'] as Map<String, String>;
      await app_state.persistPrismUser();
      if (!ownsSession()) return;

      await CoinsService.instance.maybeAwardProfileCompletion();
      if (mounted && ownsSession()) {
        Navigator.pop(context);
        toasts.success(l10n.coreProfileUpdated);
      }
    } catch (e) {
      logger.d(e.toString());
      if (ownsSession()) toasts.error(l10n.coreProfileSaveFailed);
    } finally {
      if (mounted) setState(() => isLoading = false);
    }
  }

  void _onUsernameChanged(String value) {
    _usernameDebounce?.cancel();
    final bool longEnough = value.length >= minUsernameLength;
    final bool validChars = RegExp(r'^\w{1,30}$').hasMatch(value);
    final bool allCaps = isAllCapsUsername(value);
    final bool valid = longEnough && validChars && !allCaps;
    final int checkId = ++_usernameCheckId;
    setState(() {
      enabled = valid;
      available = null;
      _usernameError = value.isEmpty || value == app_state.prismUser.username
          ? null
          : !longEnough
          ? context.l10n.coreEditUsernameMinLength(minUsernameLength)
          : !validChars
          ? context.l10n.coreEditUsernameChars
          : allCaps
          ? context.l10n.coreEditUsernameAllCaps
          : null;
      isCheckingUsername = valid && value != app_state.prismUser.username;
      usernameEdit = value.isNotEmpty && value != app_state.prismUser.username;
    });
    if (!isCheckingUsername) return;
    _usernameDebounce = Timer(const Duration(milliseconds: 400), () async {
      bool? isAvailable;
      try {
        isAvailable = await _isUsernameAvailable(value);
      } catch (e) {
        logger.d(e.toString());
      }
      // A newer keystroke owns the result now.
      if (!mounted || checkId != _usernameCheckId) return;
      setState(() {
        available = isAvailable;
        isCheckingUsername = false;
        if (isAvailable == false) _usernameError = context.l10n.coreEditUsernameTaken;
      });
      if (isAvailable == null) toasts.error(context.l10n.coreUsernameCheckFailed);
    });
  }

  String? get _linkError => _invalidLinks.contains(_link.name) ? _linkErrorText(_link) : null;

  String _linkDisplayName(ProfileLinkKind kind) => profileLinkTypeLabel(context.l10n, kind.type);

  String _linkErrorText(ProfileLinkKind kind) => switch (kind.name) {
    'email' => context.l10n.coreEditEmailInvalid,
    customLinkName => context.l10n.coreEditLinkInvalid,
    _ => context.l10n.coreEditKindLinkInvalid(_linkDisplayName(kind)),
  };

  Future<void> _pickLinkKind() async {
    final ProfileLinkKind? picked = await showLinkKindSheet(context, selected: _link, values: _linkValues);
    if (picked == null || !mounted) return;
    setState(() {
      _invalidLinks.remove(_link.name);
      _link = picked;
    });
    linkController.text = _linkValues[_link.name] ?? '';
  }

  void _onLinkChanged(String value) {
    final String? clean = value.trim().isEmpty ? '' : sanitizeProfileLink(_link, value);
    if (clean == null) {
      _invalidLinks.add(_link.name);
    } else {
      _invalidLinks.remove(_link.name);
      _linkValues[_link.name] = clean;
    }
    final changed = _linkValues.values.any((v) => v.isNotEmpty);
    setState(() => linkEdit = changed);
  }

  Future<void> _confirmDiscard() async {
    final AppLocalizations l10n = context.l10n;
    final bool discard = await showPrismConfirm(
      context,
      title: l10n.coreEditDiscardTitle,
      message: l10n.coreEditDiscardBody,
      confirmLabel: l10n.corePopupDiscard,
      destructive: true,
    );
    if (discard && mounted) Navigator.pop(context);
  }

  Widget _availabilityIndicator(ColorScheme cs) {
    return SizedBox(
      width: 48,
      height: 48,
      child: Center(
        child: AnimatedSwitcher(
          duration: context.motion(PrismDurations.fast),
          child: isCheckingUsername
              ? SizedBox.square(
                  key: const ValueKey('checking'),
                  dimension: 18,
                  child: CircularProgressIndicator(strokeWidth: 2, color: cs.onSurfaceVariant),
                )
              : available == null
              ? const SizedBox.shrink(key: ValueKey('none'))
              : Icon(
                  available! ? Icons.check_circle_rounded : Icons.cancel_rounded,
                  key: ValueKey(available),
                  color: available! ? cs.primary : cs.error,
                  size: 22,
                  semanticLabel: available!
                      ? context.l10n.coreEditUsernameAvailable
                      : context.l10n.coreEditUsernameTakenSemantic,
                ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final ColorScheme cs = Theme.of(context).colorScheme;
    final AppLocalizations l10n = context.l10n;
    const double fieldGap = PrismSpace.md;
    return PopScope(
      canPop: !_hasUnsavedChanges || isLoading,
      onPopInvokedWithResult: (bool didPop, Object? result) {
        if (!didPop) _confirmDiscard();
      },
      child: PrismPage(
        title: l10n.coreEditProfile,
        bottomBar: PrismButton(
          label: l10n.coreSaveChanges,
          expand: true,
          loading: isLoading,
          onPressed: _hasChanges ? _saveProfile : null,
        ),
        body: SingleChildScrollView(
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          padding: const EdgeInsets.only(top: PrismSpace.xs, bottom: PrismSpace.xl),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              EditProfileHeader(
                coverUrl: app_state.prismUser.coverPhoto,
                coverFile: _cover,
                avatarUrl: app_state.prismUser.profilePhoto,
                avatarFile: _pfp,
                name: nameController.text,
                onChangeCover: () => _pickImage((file) {
                  _cover = file;
                  coverEdit = true;
                }),
                onRemoveCover: () => _confirmRemove(() async {
                  setState(() {
                    _cover = null;
                    coverEdit = false;
                  });
                  app_state.prismUser.coverPhoto = null;
                  app_state.persistPrismUser();
                  await _updateCurrentUser(<String, dynamic>{"coverPhoto": null}, 'profile.edit.removeCoverPhoto');
                }, l10n.corePopupCoverPhoto),
                onChangePhoto: () => _pickImage((file) {
                  _pfp = file;
                  pfpEdit = true;
                }),
                onRemovePhoto: _pfp == null && isCustomProfilePhoto(app_state.prismUser.profilePhoto)
                    ? () => _confirmRemove(_removePhoto, l10n.corePopupProfilePhoto)
                    : null,
              ),
              const SizedBox(height: fieldGap),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: PrismSpace.page),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: <Widget>[
                    PrismTextField(
                      label: l10n.coreName,
                      controller: nameController,
                      textCapitalization: TextCapitalization.words,
                      textInputAction: TextInputAction.next,
                      onChanged: (value) => setState(() {
                        nameEdit = value.isNotEmpty && value != app_state.prismUser.name;
                      }),
                    ),
                    const SizedBox(height: fieldGap),
                    PrismTextField(
                      label: l10n.coreUsername,
                      controller: usernameController,
                      prefixIcon: Icons.alternate_email_rounded,
                      helper: available == true ? l10n.coreEditUsernameAvailable : _usernameRule,
                      error: _usernameError,
                      suffix: _availabilityIndicator(cs),
                      autocorrect: false,
                      textInputAction: TextInputAction.next,
                      onChanged: _onUsernameChanged,
                    ),
                    const SizedBox(height: fieldGap),
                    PrismTextField(
                      label: l10n.coreBio,
                      hint: l10n.coreEditBioHint,
                      controller: bioController,
                      maxLength: 150,
                      minLines: 3,
                      maxLines: 3,
                      textCapitalization: TextCapitalization.sentences,
                      suffix: bioController.text.isEmpty
                          ? null
                          : PrismIconButton(
                              icon: Icons.close_rounded,
                              tooltip: l10n.coreRemoveBio,
                              iconSize: 20,
                              onPressed: () => _confirmRemove(
                                () async {
                                  setState(() {
                                    bioController.text = '';
                                    bioEdit = false;
                                  });
                                  app_state.prismUser.bio = '';
                                  app_state.persistPrismUser();
                                  await _updateCurrentUser(<String, dynamic>{"bio": ""}, 'profile.edit.clearBio');
                                },
                                l10n.coreBio,
                                title: l10n.coreEditRemoveBioTitle,
                              ),
                            ),
                      onChanged: (value) => setState(() {
                        bioEdit = value != app_state.prismUser.bio;
                      }),
                    ),
                    const SizedBox(height: fieldGap),
                    EditProfileLinkField(
                      kind: _link,
                      controller: linkController,
                      error: _linkError,
                      onPickKind: _pickLinkKind,
                      onChanged: _onLinkChanged,
                      onRemove: () => _confirmRemove(() async {
                        setState(() {
                          linkController.text = '';
                          _linkValues[_link.name] = '';
                          _invalidLinks.remove(_link.name);
                        });
                        final links = app_state.prismUser.links;
                        links.remove(_link.name);
                        app_state.prismUser.links = links;
                        app_state.persistPrismUser();
                        await _updateCurrentUser(<String, dynamic>{
                          "links": app_state.prismUser.links,
                        }, 'profile.edit.removeLink');
                      }, l10n.coreEditProfileLink(_linkDisplayName(_link))),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
