import 'dart:io';

import 'package:Prism/core/router/app_router.dart';
import 'package:Prism/core/state/app_state.dart' as app_state;
import 'package:Prism/data/upload/wallpaper/setup_submission.dart';
import 'package:Prism/features/setups/views/widgets/setup_form_icon_picker.dart';
import 'package:Prism/theme/jam_icons_icons.dart';
import 'package:Prism/theme/toasts.dart' as toasts;
import 'package:auto_route/auto_route.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

/// The upload and edit setup form. The screen owns the setup image and submits through [onPost].
class SetupForm extends StatefulWidget {
  const SetupForm({
    super.key,
    required this.isEdit,
    required this.preview,
    required this.onPreviewTap,
    required this.busy,
    required this.onPost,
    this.onSaveDraft,
    this.initial = const SetupDetails(),
  });

  final bool isEdit;
  final Widget preview;
  final VoidCallback onPreviewTap;
  final bool busy;
  final ValueChanged<SetupDetails> onPost;
  final ValueChanged<SetupDetails>? onSaveDraft;
  final SetupDetails initial;

  @override
  State<SetupForm> createState() => _SetupFormState();
}

class _SetupFormState extends State<SetupForm> {
  static const Map<int, Widget> _wallpaperSources = <int, Widget>{
    0: _SegmentLabel(JamIcons.link, 'Link'),
    1: _SegmentLabel(JamIcons.upload, 'Upload'),
    2: _SegmentLabel(JamIcons.android, 'App'),
  };
  static const Map<int, Widget> _widgetSources = <int, Widget>{
    0: _SegmentLabel(JamIcons.google_play, 'Widgets'),
    1: _SegmentLabel(JamIcons.google_play_circle, '* Icons'),
  };

  late final TextEditingController _setupName = TextEditingController(text: widget.initial.setupName);
  late final TextEditingController _setupDesc = TextEditingController(text: widget.initial.setupDesc);
  late final TextEditingController _iconName = TextEditingController(text: widget.initial.iconName);
  late final TextEditingController _iconUrl = TextEditingController(text: widget.initial.iconUrl);
  late final TextEditingController _widgetName1 = TextEditingController(text: widget.initial.widgetName);
  late final TextEditingController _widgetUrl1 = TextEditingController(text: widget.initial.widgetUrl);
  late final TextEditingController _widgetName2 = TextEditingController(text: widget.initial.widgetName2);
  late final TextEditingController _widgetUrl2 = TextEditingController(text: widget.initial.widgetUrl2);
  late final TextEditingController _wallpaperLink = TextEditingController(
    text: switch (widget.initial.wallpaper) {
      LinkWallpaper(:final url) => url,
      _ => '',
    },
  );
  late final TextEditingController _appName = TextEditingController(
    text: switch (widget.initial.wallpaper) {
      AppWallpaper(:final appName) => appName,
      _ => '',
    },
  );
  late final TextEditingController _appLink = TextEditingController(
    text: switch (widget.initial.wallpaper) {
      AppWallpaper(:final link) => link,
      _ => '',
    },
  );
  late final TextEditingController _appWallName = TextEditingController(
    text: switch (widget.initial.wallpaper) {
      AppWallpaper(:final wallName) => wallName,
      _ => '',
    },
  );
  late UploadedWallpaper? _uploaded = switch (widget.initial.wallpaper) {
    final UploadedWallpaper uploaded => uploaded,
    _ => null,
  };
  late int _wallpaperSource = switch (widget.initial.wallpaper) {
    LinkWallpaper() => 0,
    UploadedWallpaper() => 1,
    AppWallpaper() => 2,
  };
  int _widgetSource = 0;
  late bool _secondWidgetAdded = widget.initial.widgetName2.isNotEmpty;

  @override
  void dispose() {
    for (final TextEditingController c in <TextEditingController>[
      _setupName,
      _setupDesc,
      _iconName,
      _iconUrl,
      _widgetName1,
      _widgetUrl1,
      _widgetName2,
      _widgetUrl2,
      _wallpaperLink,
      _appName,
      _appLink,
      _appWallName,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  SetupDetails _details() {
    final AppWallpaper app = AppWallpaper(appName: _appName.text, link: _appLink.text, wallName: _appWallName.text);
    final SetupWallpaperInput wallpaper = _uploaded ?? (app.isFilled ? app : LinkWallpaper(_wallpaperLink.text));
    return SetupDetails(
      setupName: _setupName.text,
      setupDesc: _setupDesc.text,
      iconName: _iconName.text,
      iconUrl: _iconUrl.text,
      widgetName: _widgetName1.text,
      widgetUrl: _widgetUrl1.text,
      widgetName2: _widgetName2.text,
      widgetUrl2: _widgetUrl2.text,
      wallpaper: wallpaper,
    );
  }

  void _post() {
    final SetupDetails details = _details();
    if (!details.hasRequiredFields) {
      toasts.error("Please fill all required fields!");
      return;
    }
    widget.onPost(details);
  }

  Future<void> _pickWallpaper() async {
    final XFile? picked = await ImagePicker().pickImage(source: ImageSource.gallery);
    if (!mounted || picked == null) return;
    final UploadedWallpaper? uploaded = await context.router.push<UploadedWallpaper>(
      UploadWallRoute(image: File(picked.path), fromSetupRoute: true),
    );
    if (uploaded != null && mounted) {
      setState(() => _uploaded = uploaded);
    }
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final Color secondary = theme.colorScheme.secondary;
    final bool actionsEnabled = !widget.busy;
    final TextStyle noteStyle = TextStyle(
      fontSize: 11,
      fontWeight: FontWeight.w100,
      color: secondary.withValues(alpha: 0.7),
    );
    final TextStyle sectionStyle = TextStyle(fontSize: 14, fontWeight: FontWeight.normal, color: secondary);
    return Scaffold(
      backgroundColor: theme.primaryColor,
      appBar: AppBar(
        title: Text(widget.isEdit ? "Edit Setup" : "Upload Setup", style: TextStyle(color: secondary)),
        actions: [
          if (widget.onSaveDraft != null)
            _ActionButton(label: "Save", enabled: actionsEnabled, onPressed: () => widget.onSaveDraft!(_details())),
          _ActionButton(label: "Post", enabled: actionsEnabled, onPressed: _post),
        ],
      ),
      body: ListView(
        children: [
          Row(
            children: [
              Padding(
                padding: const EdgeInsets.all(20.0),
                child: CircleAvatar(
                  backgroundColor: theme.colorScheme.error,
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
                    _LabelField(
                      controller: _setupName,
                      label: widget.isEdit ? "* Write a Name..." : "* Write setup Name...",
                    ),
                    _LabelField(controller: _setupDesc, label: "* Write a description... (50 chars only)", maxLines: 2),
                  ],
                ),
              ),
              const Spacer(flex: 10),
              GestureDetector(
                onTap: widget.onPreviewTap,
                child: Stack(
                  children: [
                    Container(padding: const EdgeInsets.all(20.0), height: 200, width: 120, child: widget.preview),
                    if (widget.busy)
                      Container(
                        padding: const EdgeInsets.all(20.0),
                        height: 200,
                        width: 120,
                        child: Center(
                          child: CircularProgressIndicator(
                            valueColor: AlwaysStoppedAnimation<Color>(theme.colorScheme.error),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
          const Divider(height: 1),
          ExpansionTile(
            title: Text("Add widgets, icon packs", style: sectionStyle),
            children: [
              _SourceSelector(
                children: _widgetSources,
                groupValue: _widgetSource,
                onChanged: (int val) => setState(() => _widgetSource = val),
              ),
              if (_widgetSource == 0)
                Column(
                  children: [
                    _PillField(controller: _widgetName1, hint: "Write widget app name...", icon: JamIcons.android),
                    _PillField(controller: _widgetUrl1, hint: "Write widget app link...", icon: JamIcons.google_play),
                    if (_secondWidgetAdded) ...[
                      _PillField(
                        controller: _widgetName2,
                        hint: "Write 2nd widget app name...",
                        icon: JamIcons.android,
                      ),
                      _PillField(
                        controller: _widgetUrl2,
                        hint: "Write 2nd widget app link...",
                        icon: JamIcons.google_play,
                      ),
                    ] else
                      TextButton(
                        onPressed: () => setState(() => _secondWidgetAdded = true),
                        child: Text("Add more widget", style: theme.textTheme.bodyMedium),
                      ),
                  ],
                )
              else
                Column(
                  children: [
                    _PillField(
                      controller: _iconName,
                      hint: "Write icon pack name...",
                      suffix: IconButton(
                        onPressed: () => showSetupIconPicker(
                          context,
                          onPicked: (icon) {
                            _iconName.text = icon.name.trim();
                            _iconUrl.text = icon.link.trim();
                          },
                        ),
                        icon: Icon(JamIcons.search, color: secondary),
                      ),
                    ),
                    _PillField(controller: _iconUrl, hint: "Write icon app link...", icon: JamIcons.google_play_circle),
                  ],
                ),
            ],
          ),
          const Divider(height: 1),
          ExpansionTile(
            title: Text("* Add wallpaper", style: sectionStyle),
            children: [
              _SourceSelector(
                children: _wallpaperSources,
                groupValue: _wallpaperSource,
                onChanged: (int val) => setState(() => _wallpaperSource = val),
              ),
              if (_wallpaperSource == 0)
                _PillField(controller: _wallpaperLink, hint: "Write wallpaper link...", icon: JamIcons.picture)
              else if (_wallpaperSource == 1)
                Padding(
                  padding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
                  child: FloatingActionButton.extended(
                    backgroundColor: _uploaded != null ? theme.hintColor : theme.colorScheme.error,
                    onPressed: _uploaded != null && !widget.isEdit ? null : _pickWallpaper,
                    label: Text(
                      _uploaded == null ? "Upload" : (widget.isEdit ? "Change Wall" : "Uploaded"),
                      style: TextStyle(color: secondary, fontWeight: FontWeight.normal),
                    ),
                    icon: Icon(JamIcons.upload, color: secondary),
                  ),
                )
              else
                Column(
                  children: [
                    _PillField(controller: _appName, hint: "Write wallpaper app name...", icon: JamIcons.android),
                    _PillField(controller: _appLink, hint: "Write app link...", icon: JamIcons.google_play),
                    _PillField(controller: _appWallName, hint: "Write wallpaper name", icon: JamIcons.picture),
                  ],
                ),
            ],
          ),
          const Divider(height: 1),
          ListTile(title: Text("Fields marked with * are required.", style: noteStyle)),
          const Divider(height: 1),
          if (!widget.isEdit) ...[
            ListTile(
              title: Text(
                "If you are using a wallpaper from Prism, just click link and paste the share link of wallpaper there.",
                style: noteStyle,
              ),
            ),
            const Divider(height: 1),
          ],
          ListTile(
            title: Text(
              app_state.prismUser.premium
                  ? "Note - We have a strong review policy, and submitting irrelevant images & info will lead to ban. Your setup will be visible in the setups section."
                  : "Note - We have a strong review policy, and submitting irrelevant images & info will lead to ban. We take about 24 hours to review the submissions, and after a successful review, your setup will be visible in the setups section.",
              style: noteStyle,
            ),
          ),
        ],
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  const _ActionButton({required this.label, required this.enabled, required this.onPressed});

  final String label;
  final bool enabled;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return TextButton(
      onPressed: enabled ? onPressed : null,
      child: Text(
        label,
        style: TextStyle(
          color: enabled
              ? theme.colorScheme.error == Colors.black
                    ? Colors.white
                    : theme.colorScheme.error
              : theme.hintColor,
          fontWeight: FontWeight.normal,
        ),
      ),
    );
  }
}

class _SegmentLabel extends StatelessWidget {
  const _SegmentLabel(this.icon, this.label);

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        mainAxisSize: MainAxisSize.min,
        children: [Icon(icon), Text(label)],
      ),
    );
  }
}

class _SourceSelector extends StatelessWidget {
  const _SourceSelector({required this.children, required this.groupValue, required this.onChanged});

  final Map<int, Widget> children;
  final int groupValue;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.all(8.0),
      child: CupertinoSegmentedControl<int>(
        children: children,
        groupValue: groupValue,
        borderColor: theme.colorScheme.secondary,
        pressedColor: theme.hintColor,
        unselectedColor: theme.primaryColor,
        selectedColor: theme.colorScheme.secondary,
        padding: EdgeInsets.zero,
        onValueChanged: onChanged,
      ),
    );
  }
}

class _LabelField extends StatelessWidget {
  const _LabelField({required this.controller, required this.label, this.maxLines = 1});

  final TextEditingController controller;
  final String label;
  final int maxLines;

  @override
  Widget build(BuildContext context) {
    final TextStyle style = TextStyle(
      fontSize: 14,
      fontWeight: FontWeight.normal,
      color: Theme.of(context).colorScheme.secondary,
    );
    return TextField(
      maxLines: maxLines,
      controller: controller,
      style: style,
      decoration: InputDecoration(
        labelText: label,
        hintText: label,
        hintStyle: style,
        labelStyle: style,
        floatingLabelBehavior: FloatingLabelBehavior.never,
        border: InputBorder.none,
      ),
    );
  }
}

class _PillField extends StatelessWidget {
  const _PillField({required this.controller, required this.hint, this.icon, this.suffix});

  final TextEditingController controller;
  final String hint;
  final IconData? icon;
  final Widget? suffix;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final TextStyle style = theme.textTheme.headlineSmall!.copyWith(color: theme.colorScheme.secondary);
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
      child: Container(
        decoration: BoxDecoration(borderRadius: BorderRadius.circular(500), color: theme.hintColor),
        child: TextField(
          cursorColor: theme.colorScheme.error,
          style: style,
          controller: controller,
          decoration: InputDecoration(
            contentPadding: const EdgeInsets.only(left: 30, top: 15),
            border: InputBorder.none,
            disabledBorder: InputBorder.none,
            enabledBorder: InputBorder.none,
            focusedBorder: InputBorder.none,
            hintText: hint,
            hintStyle: style,
            suffixIcon: suffix ?? Icon(icon, color: theme.colorScheme.secondary),
          ),
        ),
      ),
    );
  }
}
