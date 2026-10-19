import 'dart:async';
import 'dart:io';

import 'package:Prism/core/cache/prism_image_cache.dart';
import 'package:Prism/core/di/injection.dart';
import 'package:Prism/core/haptics/prism_haptics.dart';
import 'package:Prism/core/persistence/data_sources/settings_local_data_source.dart';
import 'package:Prism/core/persistence/persistence_keys.dart';
import 'package:Prism/core/platform/wallpaper_service.dart';
import 'package:Prism/core/widgets/menu_button/set_wallpaper_choice.dart';
import 'package:Prism/core/widgets/prism/prism_ui.dart';
import 'package:Prism/l10n/l10n.dart';
import 'package:Prism/logger/logger.dart';
import 'package:Prism/theme/jam_icons_icons.dart';
import 'package:async_wallpaper/async_wallpaper.dart' as aw;
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

/// The set sheet: where to set the wall, how it fits, the system cropper, and the studio and pair entries.
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
  bool _cropFirst = false;
  bool _alwaysUse = false;
  late final Future<aw.WallpaperCapabilities> _capabilities = aw.AsyncWallpaper.getCapabilities();

  void _select(WallpaperTarget target) {
    PrismHaptics.tap();
    if (_alwaysUse) _saveDefault(target);
    widget.onSelected(SetWallpaperChoice(target, fit: _fit, useSystemCropper: _cropFirst));
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
    final bool canCrop = !kIsWeb && defaultTargetPlatform == TargetPlatform.android;
    final AppLocalizations l10n = context.l10n;
    return FutureBuilder<aw.WallpaperCapabilities>(
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
        return PrismSheetBody(
          title: l10n.coreSetWallpaper,
          message: supported(WallpaperTarget.both) ? l10n.coreBothSetsScreens : null,
          scrollable: true,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              _Header(thumbnailUrl: widget.thumbnailUrl, notes: widget.notes),
              PrismGroup(
                children: <Widget>[
                  PrismRow(
                    icon: Icons.home_rounded,
                    title: l10n.coreHomeScreen,
                    onTap: () => _select(WallpaperTarget.home),
                  ),
                  if (supported(WallpaperTarget.lock))
                    PrismRow(
                      icon: Icons.lock_rounded,
                      title: l10n.coreLockScreen,
                      onTap: () => _select(WallpaperTarget.lock),
                    ),
                  if (supported(WallpaperTarget.both))
                    PrismRow(
                      icon: Icons.layers_rounded,
                      title: l10n.coreBoth,
                      onTap: () => _select(WallpaperTarget.both),
                    ),
                ],
              ),
              if (widget.canAdjust) ...<Widget>[
                const SizedBox(height: PrismSpace.sm),
                PrismGroup(
                  children: <Widget>[
                    PrismRow(
                      icon: JamIcons.set_square,
                      title: l10n.coreAdjustPositionPreview,
                      subtitle: l10n.coreAdjustPositionPreviewBody,
                      onTap: () {
                        PrismHaptics.tap();
                        widget.onSelected(const SetWallpaperChoice.adjust());
                      },
                    ),
                    if (canPair)
                      PrismRow(
                        icon: JamIcons.picture,
                        title: l10n.coreDifferentLockWallpaper,
                        subtitle: l10n.coreThisGoesOnHome,
                        onTap: () {
                          PrismHaptics.tap();
                          widget.onSelected(SetWallpaperChoice.pair(fit: _fit));
                        },
                      ),
                  ],
                ),
              ],
              const SizedBox(height: PrismSpace.sm),
              Wrap(
                spacing: PrismSpace.xs,
                runSpacing: PrismSpace.xs,
                children: <Widget>[
                  for (final (WallpaperFit fit, String label) in <(WallpaperFit, String)>[
                    (WallpaperFit.fill, l10n.coreFillScreen),
                    (WallpaperFit.whole, l10n.coreFitWholeImage),
                  ])
                    PrismChip(
                      label: label,
                      selected: _fit == fit,
                      onTap: _cropFirst ? null : () => setState(() => _fit = fit),
                    ),
                ],
              ),
              const SizedBox(height: PrismSpace.sm),
              PrismGroup(
                children: <Widget>[
                  if (canCrop)
                    PrismSwitchRow(
                      icon: Icons.crop_rounded,
                      title: l10n.coreCropAndPosition,
                      subtitle: l10n.coreChooseSystemEditorArea,
                      value: _cropFirst,
                      onChanged: (value) => setState(() => _cropFirst = value),
                    ),
                  PrismSwitchRow(
                    icon: Icons.bookmark_border_rounded,
                    title: l10n.coreAlwaysUseThis,
                    subtitle: l10n.coreAlwaysUseThisBody,
                    value: _alwaysUse,
                    onChanged: (value) => setState(() => _alwaysUse = value),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.thumbnailUrl, required this.notes});

  final String? thumbnailUrl;
  final List<String> notes;

  @override
  Widget build(BuildContext context) {
    final String? thumb = thumbnailUrl;
    final bool hasThumb = thumb != null && thumb.isNotEmpty;
    if (!hasThumb && notes.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: PrismSpace.md),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          if (hasThumb) ...<Widget>[
            ClipRRect(
              borderRadius: BorderRadius.circular(PrismRadius.sm),
              child: SizedBox(width: 56, height: 96, child: _SheetThumbnail(thumb)),
            ),
            const SizedBox(width: PrismSpace.md),
          ],
          if (notes.isNotEmpty) Expanded(child: _NoteChips(notes: notes)),
        ],
      ),
    );
  }
}

class _NoteChips extends StatelessWidget {
  const _NoteChips({required this.notes});

  final List<String> notes;

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    return Wrap(
      spacing: PrismSpace.xs,
      runSpacing: PrismSpace.xxs,
      children: <Widget>[
        for (final String note in notes)
          DecoratedBox(
            decoration: BoxDecoration(
              color: scheme.error.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(PrismRadius.pill),
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  Icon(JamIcons.alert, size: 14, color: scheme.error),
                  const SizedBox(width: 6),
                  Flexible(
                    child: Text(note, style: PrismTextStyles.caption(context).copyWith(color: scheme.onSurface)),
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
