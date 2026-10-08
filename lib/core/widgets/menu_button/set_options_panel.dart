import 'dart:async';
import 'dart:io';

import 'package:Prism/core/cache/prism_image_cache.dart';
import 'package:Prism/core/di/injection.dart';
import 'package:Prism/core/haptics/prism_haptics.dart';
import 'package:Prism/core/persistence/data_sources/settings_local_data_source.dart';
import 'package:Prism/core/persistence/persistence_keys.dart';
import 'package:Prism/core/platform/wallpaper_service.dart';
import 'package:Prism/core/widgets/menu_button/set_wallpaper_choice.dart';
import 'package:Prism/logger/logger.dart';
import 'package:Prism/theme/app_tokens.dart';
import 'package:Prism/theme/contrast.dart';
import 'package:Prism/theme/jam_icons_icons.dart';
import 'package:async_wallpaper/async_wallpaper.dart' as aw;
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

/// The set sheet: where to set the wall, how it fits, and the studio and pair entries.
class SetOptionsPanel extends StatefulWidget {
  const SetOptionsPanel({
    super.key,
    required this.onSelected,
    this.thumbnailUrl,
    this.notes = const <String>[],
    this.canAdjust = false,
  });

  final ValueChanged<SetWallpaperChoice> onSelected;

  /// The wall at the top of the sheet.
  final String? thumbnailUrl;

  /// Short warnings about this wall, for example low resolution. They show as chips.
  final List<String> notes;

  /// True when the sheet may offer the position studio and a different lock screen wall.
  final bool canAdjust;

  @override
  State<SetOptionsPanel> createState() => _SetOptionsPanelState();
}

class _SetOptionsPanelState extends State<SetOptionsPanel> {
  WallpaperFit _fit = WallpaperFit.fill;
  bool _alwaysUse = false;
  late final Future<aw.WallpaperCapabilities> _capabilities = aw.AsyncWallpaper.getCapabilities();

  void _select(WallpaperTarget target) {
    PrismHaptics.tap();
    if (_alwaysUse) _saveDefault(target);
    widget.onSelected(SetWallpaperChoice(target, fit: _fit));
  }

  void _saveDefault(WallpaperTarget target) {
    try {
      if (!getIt.isRegistered<SettingsLocalDataSource>()) return;
      unawaited(getIt<SettingsLocalDataSource>().set(PersistenceKeys.defaultApplyTarget, target.name));
    } catch (error) {
      logger.w('SetOptionsPanel: could not save the default target', error: error);
    }
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme scheme = theme.colorScheme;
    return Material(
      color: theme.primaryColor,
      borderRadius: const BorderRadius.only(topLeft: Radius.circular(20), topRight: Radius.circular(20)),
      child: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 12, 24, 16),
          child: FutureBuilder<aw.WallpaperCapabilities>(
            future: _capabilities,
            builder: (context, snapshot) {
              final aw.WallpaperCapabilities? capabilities = snapshot.data;
              bool supported(WallpaperTarget target) =>
                  capabilities == null || isWallpaperTargetSupported(capabilities, target);
              final bool canPair =
                  widget.canAdjust &&
                  capabilities != null &&
                  supported(WallpaperTarget.home) &&
                  supported(WallpaperTarget.lock);
              return Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  Center(
                    child: Container(
                      height: 5,
                      width: 30,
                      decoration: BoxDecoration(color: theme.hintColor, borderRadius: BorderRadius.circular(500)),
                    ),
                  ),
                  const SizedBox(height: 16),
                  _Header(thumbnailUrl: widget.thumbnailUrl, notes: widget.notes),
                  const SizedBox(height: 16),
                  _TargetButton(label: 'Home Screen', onTap: () => _select(WallpaperTarget.home)),
                  if (supported(WallpaperTarget.lock))
                    _TargetButton(label: 'Lock Screen', onTap: () => _select(WallpaperTarget.lock)),
                  if (supported(WallpaperTarget.both))
                    _TargetButton(label: 'Both', onTap: () => _select(WallpaperTarget.both)),
                  const SizedBox(height: 8),
                  SegmentedButton<WallpaperFit>(
                    segments: const <ButtonSegment<WallpaperFit>>[
                      ButtonSegment<WallpaperFit>(value: WallpaperFit.fill, label: Text('Fill screen')),
                      ButtonSegment<WallpaperFit>(value: WallpaperFit.whole, label: Text('Fit whole image')),
                    ],
                    selected: <WallpaperFit>{_fit},
                    style: ButtonStyle(
                      backgroundColor: WidgetStateProperty.resolveWith(
                        (states) => states.contains(WidgetState.selected) ? scheme.error : null,
                      ),
                      foregroundColor: WidgetStateProperty.resolveWith(
                        (states) => states.contains(WidgetState.selected) ? onColor(scheme.error) : scheme.secondary,
                      ),
                      textStyle: WidgetStateProperty.resolveWith(
                        (states) => TextStyle(
                          fontFamily: PrismFonts.proximaNova,
                          fontWeight: states.contains(WidgetState.selected) ? FontWeight.bold : FontWeight.normal,
                        ),
                      ),
                    ),
                    onSelectionChanged: (selection) {
                      PrismHaptics.selection();
                      setState(() => _fit = selection.first);
                    },
                  ),
                  if (widget.canAdjust) ...<Widget>[
                    const SizedBox(height: 4),
                    _SheetRow(
                      icon: JamIcons.set_square,
                      title: 'Adjust position and preview',
                      subtitle: 'Pan, zoom and dim before you set it.',
                      onTap: () {
                        PrismHaptics.tap();
                        widget.onSelected(const SetWallpaperChoice.adjust());
                      },
                    ),
                    if (canPair)
                      _SheetRow(
                        icon: JamIcons.picture,
                        title: 'Different wallpaper for lock screen',
                        subtitle: 'This one goes on the home screen.',
                        onTap: () {
                          PrismHaptics.tap();
                          widget.onSelected(SetWallpaperChoice.pair(fit: _fit));
                        },
                      ),
                  ],
                  CheckboxListTile(
                    contentPadding: EdgeInsets.zero,
                    controlAffinity: ListTileControlAffinity.leading,
                    value: _alwaysUse,
                    onChanged: (value) {
                      PrismHaptics.selection();
                      setState(() => _alwaysUse = value ?? false);
                    },
                    title: Text('Always use this', style: TextStyle(color: scheme.secondary, fontSize: 16)),
                    subtitle: Text(
                      'Next time, Set uses the screen you pick and skips this sheet.',
                      style: theme.textTheme.bodySmall?.copyWith(color: scheme.secondary.withValues(alpha: 0.7)),
                    ),
                  ),
                  if (supported(WallpaperTarget.both)) ...<Widget>[
                    const SizedBox(height: 4),
                    Text(
                      'Both sets it on your home screen and lock screen.',
                      textAlign: TextAlign.center,
                      style: theme.textTheme.bodySmall?.copyWith(color: scheme.secondary),
                    ),
                  ],
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.thumbnailUrl, required this.notes});

  final String? thumbnailUrl;
  final List<String> notes;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final String? thumb = thumbnailUrl;
    final Widget title = Text(
      'Set Wallpaper as',
      textAlign: thumb == null ? TextAlign.center : TextAlign.start,
      style: theme.textTheme.displayMedium,
    );
    if (thumb == null || thumb.isEmpty) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          title,
          if (notes.isNotEmpty) ...<Widget>[const SizedBox(height: 8), _NoteChips(notes: notes)],
        ],
      );
    }
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: SizedBox(width: 56, height: 96, child: _SheetThumbnail(thumb)),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              title,
              if (notes.isNotEmpty) ...<Widget>[const SizedBox(height: 8), _NoteChips(notes: notes)],
            ],
          ),
        ),
      ],
    );
  }
}

class _NoteChips extends StatelessWidget {
  const _NoteChips({required this.notes});

  final List<String> notes;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme scheme = theme.colorScheme;
    return Wrap(
      spacing: 8,
      runSpacing: 4,
      children: <Widget>[
        for (final String note in notes)
          DecoratedBox(
            decoration: BoxDecoration(
              color: scheme.error.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(999),
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  Icon(JamIcons.alert, size: 14, color: scheme.error),
                  const SizedBox(width: 6),
                  Flexible(
                    child: Text(note, style: theme.textTheme.bodySmall?.copyWith(color: scheme.secondary)),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}

class _SheetThumbnail extends StatelessWidget {
  const _SheetThumbnail(this.url);

  final String url;

  @override
  Widget build(BuildContext context) {
    final Widget placeholder = ColoredBox(color: Theme.of(context).colorScheme.surfaceContainerHighest);
    if (url.startsWith('http')) {
      return CachedNetworkImage(
        cacheManager: PrismImageCache.instance,
        imageUrl: url,
        fit: BoxFit.cover,
        memCacheWidth: 160,
        placeholder: (_, _) => placeholder,
        errorWidget: (_, _, _) => placeholder,
      );
    }
    return Image.file(File(url), fit: BoxFit.cover, cacheWidth: 160, errorBuilder: (_, _, _) => placeholder);
  }
}

class _SheetRow extends StatelessWidget {
  const _SheetRow({required this.icon, required this.title, required this.subtitle, required this.onTap});

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme scheme = theme.colorScheme;
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Icon(icon, color: scheme.secondary),
      title: Text(
        title,
        style: TextStyle(
          color: scheme.secondary,
          fontFamily: PrismFonts.proximaNova,
          fontSize: 16,
          fontWeight: FontWeight.bold,
        ),
      ),
      subtitle: Text(
        subtitle,
        style: theme.textTheme.bodySmall?.copyWith(color: scheme.secondary.withValues(alpha: 0.7), fontSize: 14),
      ),
      trailing: Icon(JamIcons.chevron_right, color: scheme.secondary.withValues(alpha: 0.7)),
      onTap: onTap,
    );
  }
}

class _TargetButton extends StatelessWidget {
  const _TargetButton({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: SizedBox(
        height: 56,
        child: OutlinedButton(
          onPressed: onTap,
          style: OutlinedButton.styleFrom(
            foregroundColor: scheme.secondary,
            backgroundColor: scheme.error.withValues(alpha: 0.2),
            side: BorderSide(color: scheme.error, width: 3),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          ),
          child: Text(label, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        ),
      ),
    );
  }
}
