import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:Prism/core/coins/coins_service.dart';
import 'package:Prism/core/constants/profile_links.dart';
import 'package:Prism/core/firestore/firestore_collections.dart';
import 'package:Prism/core/firestore/firestore_query_specs.dart';
import 'package:Prism/core/firestore/firestore_runtime.dart';
import 'package:Prism/core/state/app_state.dart' as app_state;
import 'package:Prism/core/utils/string_extensions.dart';
import 'package:Prism/core/widgets/prism/prism_ui.dart';
import 'package:Prism/data/upload/github_content_api.dart';
import 'package:Prism/env/env.dart';
import 'package:Prism/features/public_profile/views/widgets/edit_profile_header.dart';
import 'package:Prism/features/public_profile/views/widgets/edit_profile_link_field.dart';
import 'package:Prism/logger/logger.dart';
import 'package:Prism/theme/toasts.dart' as toasts;
import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path/path.dart' as path;

@RoutePage(name: 'EditProfilePanelRoute')
class EditProfilePanel extends StatefulWidget {
  const EditProfilePanel({super.key});

  @override
  _EditProfilePanelState createState() => _EditProfilePanelState();
}

class _EditProfilePanelState extends State<EditProfilePanel> {
  static const String _usernameRule = 'Use 8 or more letters, numbers or underscores (_).';

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
  int _usernameCheckId = 0;
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
    linkController.text = _linkValues[_link.name] ?? '';
    super.initState();
  }

  @override
  void dispose() {
    linkController.dispose();
    bioController.dispose();
    usernameController.dispose();
    nameController.dispose();
    super.dispose();
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
    try {
      final Uint8List compressed = await compressFile(file);
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

  /// Asks before removing [removeWhat], then runs [remove].
  Future<void> _confirmRemove(Future<void> Function() remove, String removeWhat) async {
    final bool ok = await showPrismConfirm(
      context,
      title: 'Remove $removeWhat?',
      message: "This can't be undone.",
      confirmLabel: 'Remove',
      destructive: true,
    );
    if (ok && mounted) await remove();
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
      (!usernameEdit && (pfpEdit || bioEdit || linkEdit || coverEdit || nameEdit)) ||
      (usernameEdit && enabled && available != false);

  Future<void> _saveProfile() async {
    setState(() => isLoading = true);
    try {
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
    } catch (e) {
      logger.d(e.toString());
      if (mounted) setState(() => isLoading = false);
      toasts.error('Could not save your profile. Please try again.');
      return;
    }
    if (!mounted) return;
    setState(() => isLoading = false);
    Navigator.pop(context);
    toasts.success("Profile updated");
  }

  Future<void> _onUsernameChanged(String value) async {
    final int checkId = ++_usernameCheckId;
    final valid = value.isNotEmpty && value.length >= 8 && !value.contains(RegExp(r"(?: |[^\w\s])+"));
    setState(() {
      enabled = valid;
      usernameEdit = value.isNotEmpty && value != app_state.prismUser.username;
      available = null;
      isCheckingUsername = valid && usernameEdit;
    });
    if (!valid || !usernameEdit) return;
    final isAvailable = await _isUsernameAvailable(value);
    // A newer keystroke owns the result now.
    if (mounted && checkId == _usernameCheckId) {
      setState(() {
        available = isAvailable;
        isCheckingUsername = false;
      });
    }
  }

  String? get _usernameError {
    final String value = usernameController.text;
    if (!usernameEdit || value.isEmpty) return null;
    if (!enabled) return _usernameRule;
    if (available == false) return 'That username is taken.';
    return null;
  }

  String? get _linkError {
    final String value = linkController.text.trim();
    if (value.isEmpty || value.toLowerCase().contains(_link.validator.toLowerCase())) return null;
    return 'Enter a valid ${_link.name.inCaps} link.';
  }

  Future<void> _pickLinkKind() async {
    final ProfileLinkKind? picked = await showLinkKindSheet(context, selected: _link, values: _linkValues);
    if (picked == null || !mounted) return;
    setState(() => _link = picked);
    linkController.text = _linkValues[_link.name] ?? '';
  }

  void _onLinkChanged(String value) {
    if (value.toLowerCase().contains(_link.validator.toLowerCase())) {
      _linkValues[_link.name] = value;
    } else if (value.isEmpty) {
      _linkValues[_link.name] = '';
    }
    final changed = _linkValues.values.any((v) => v.isNotEmpty);
    setState(() => linkEdit = changed);
  }

  Future<void> _confirmDiscard() async {
    final bool discard = await showPrismConfirm(
      context,
      title: 'Discard changes?',
      message: 'Your edits have not been saved.',
      confirmLabel: 'Discard',
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
                  semanticLabel: available! ? 'Username available' : 'Username taken',
                ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final ColorScheme cs = Theme.of(context).colorScheme;
    const double fieldGap = PrismSpace.md;
    return PopScope(
      canPop: !_hasChanges || isLoading,
      onPopInvokedWithResult: (bool didPop, Object? result) {
        if (!didPop) _confirmDiscard();
      },
      child: PrismPage(
        title: 'Edit profile',
        bottomBar: PrismButton(
          label: 'Save changes',
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
                }, 'cover photo'),
                onChangePhoto: () => _pickImage((file) {
                  _pfp = file;
                  pfpEdit = true;
                }),
              ),
              const SizedBox(height: fieldGap),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: PrismSpace.page),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: <Widget>[
                    PrismTextField(
                      label: 'Name',
                      controller: nameController,
                      textCapitalization: TextCapitalization.words,
                      textInputAction: TextInputAction.next,
                      onChanged: (value) => setState(() {
                        nameEdit = value.isNotEmpty && value != app_state.prismUser.name;
                      }),
                    ),
                    const SizedBox(height: fieldGap),
                    PrismTextField(
                      label: 'Username',
                      controller: usernameController,
                      prefixIcon: Icons.alternate_email_rounded,
                      helper: available == true ? 'Username is available.' : _usernameRule,
                      error: _usernameError,
                      suffix: _availabilityIndicator(cs),
                      autocorrect: false,
                      textInputAction: TextInputAction.next,
                      onChanged: _onUsernameChanged,
                    ),
                    const SizedBox(height: fieldGap),
                    PrismTextField(
                      label: 'Bio',
                      hint: 'Tell people about yourself…',
                      controller: bioController,
                      maxLength: 150,
                      minLines: 3,
                      maxLines: 3,
                      textCapitalization: TextCapitalization.sentences,
                      suffix: bioController.text.isEmpty
                          ? null
                          : PrismIconButton(
                              icon: Icons.close_rounded,
                              tooltip: 'Remove bio',
                              iconSize: 20,
                              onPressed: () => _confirmRemove(() async {
                                setState(() {
                                  bioController.text = '';
                                  bioEdit = false;
                                });
                                app_state.prismUser.bio = '';
                                app_state.persistPrismUser();
                                await _updateCurrentUser(<String, dynamic>{"bio": ""}, 'profile.edit.clearBio');
                              }, 'bio'),
                            ),
                      onChanged: (value) => setState(() {
                        bioEdit = value.isNotEmpty && value != app_state.prismUser.bio;
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
                        });
                        final links = app_state.prismUser.links;
                        links.remove(_link.name);
                        app_state.prismUser.links = links;
                        app_state.persistPrismUser();
                        await _updateCurrentUser(<String, dynamic>{
                          "links": app_state.prismUser.links,
                        }, 'profile.edit.removeLink');
                      }, '${_link.name.inCaps} link'),
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
