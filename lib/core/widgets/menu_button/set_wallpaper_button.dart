import 'dart:async';

import 'package:Prism/core/di/injection.dart';
import 'package:Prism/core/haptics/prism_haptics.dart';
import 'package:Prism/core/persistence/data_sources/settings_local_data_source.dart';
import 'package:Prism/core/persistence/persistence_keys.dart';
import 'package:Prism/core/platform/wallpaper_service.dart';
import 'package:Prism/core/platform/wallpaper_set_feedback.dart';
import 'package:Prism/core/widgets/menu_button/circular_menu_button.dart';
import 'package:Prism/core/widgets/menu_button/primary_action_pill.dart';
import 'package:Prism/core/widgets/prism_sheet.dart';
import 'package:Prism/features/startup/services/notification_permission_prompt_service.dart';
import 'package:Prism/logger/logger.dart';
import 'package:Prism/theme/app_tokens.dart';
import 'package:Prism/theme/jam_icons_icons.dart';
import 'package:async_wallpaper/async_wallpaper.dart' as aw;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

/// What the user picked in the set sheet.
class SetWallpaperChoice {
  const SetWallpaperChoice(this.target, {this.fit = WallpaperFit.fill, this.useSystemCropper = false});

  final WallpaperTarget target;
  final WallpaperFit fit;
  final bool useSystemCropper;
}

/// True when the device can set [target]. Unknown capabilities count as supported.
bool isWallpaperTargetSupported(aw.WallpaperCapabilities capabilities, WallpaperTarget target) {
  if (!capabilities.supportsStaticWallpaper) return true;
  return switch (target) {
    WallpaperTarget.home => capabilities.supportsHomeWallpaper,
    WallpaperTarget.lock => capabilities.supportsLockWallpaper,
    WallpaperTarget.both => capabilities.supportsBothWallpapers,
  };
}

Future<SetWallpaperChoice?> showSetWallpaperSheet(BuildContext context) {
  return showPrismSheet<SetWallpaperChoice>(
    isScrollControlled: true,
    context: context,
    builder: (sheetContext) => SetOptionsPanel(onSelected: (choice) => Navigator.of(sheetContext).pop(choice)),
  );
}

// ignore: avoid_classes_with_only_static_members
class SetWallpaperFlow {
  /// The saved default target, or null when the user wants to be asked.
  static WallpaperTarget? defaultTarget() {
    try {
      if (!getIt.isRegistered<SettingsLocalDataSource>()) return null;
      final String saved = getIt<SettingsLocalDataSource>().get<String>(
        PersistenceKeys.defaultApplyTarget,
        defaultValue: 'ask',
      );
      for (final WallpaperTarget target in WallpaperTarget.values) {
        if (target.name == saved) return target;
      }
    } catch (error) {
      logger.w('SetWallpaperFlow: could not read default target', error: error);
    }
    return null;
  }

  /// Applies straight to the default target when one is saved, else opens the sheet.
  /// Returns null when the user closed the sheet.
  static Future<WallpaperSetResult?> run(
    BuildContext context, {
    required String url,
    String? thumbnailUrl,
    bool forceSheet = false,
    bool recordHistory = true,
    ValueChanged<bool>? onBusy,
  }) async {
    SetWallpaperChoice? choice;
    final WallpaperTarget? saved = forceSheet ? null : defaultTarget();
    if (saved != null) {
      final aw.WallpaperCapabilities capabilities = await aw.AsyncWallpaper.getCapabilities();
      if (isWallpaperTargetSupported(capabilities, saved)) choice = SetWallpaperChoice(saved);
    }
    if (!context.mounted) return null;
    choice ??= await showSetWallpaperSheet(context);
    if (choice == null || !context.mounted) return null;
    return apply(
      context,
      url: url,
      choice: choice,
      thumbnailUrl: thumbnailUrl,
      recordHistory: recordHistory,
      onBusy: onBusy,
    );
  }

  static Future<WallpaperSetResult?> apply(
    BuildContext context, {
    required String url,
    required SetWallpaperChoice choice,
    String? thumbnailUrl,
    bool recordHistory = true,
    ValueChanged<bool>? onBusy,
  }) async {
    if (!context.mounted) return null;
    onBusy?.call(true);
    final WallpaperSetResult result;
    try {
      result = await WallpaperService.setWallpaper(
        url,
        choice.target,
        fit: choice.fit,
        useSystemCropper: choice.useSystemCropper,
        thumbnailUrl: thumbnailUrl,
        recordHistory: recordHistory,
      );
    } finally {
      onBusy?.call(false);
    }
    if (!context.mounted) return result;
    reportWallpaperSetResult(
      context,
      result,
      target: choice.target,
      onRetry: () => unawaited(
        apply(
          context,
          url: url,
          choice: choice,
          thumbnailUrl: thumbnailUrl,
          recordHistory: recordHistory,
          onBusy: onBusy,
        ),
      ),
    );
    return result;
  }
}

class SetWallpaperButton extends StatefulWidget {
  final String? url;
  final String? thumbnailUrl;

  /// When true, may show the OS notification permission prompt once after a successful set (e.g. wallpaper detail).
  final bool promptNotificationPermissionOnSuccess;
  final VoidCallback? onSet;

  /// Text shown beside the circle. It sits inside the same tap target, so tapping it sets the wallpaper.
  final String? label;

  const SetWallpaperButton({
    super.key,
    required this.url,
    this.thumbnailUrl,
    this.promptNotificationPermissionOnSuccess = false,
    this.onSet,
    this.label,
  });

  @override
  _SetWallpaperButtonState createState() => _SetWallpaperButtonState();
}

class _SetWallpaperButtonState extends State<SetWallpaperButton> {
  bool isLoading = false;

  Future<void> _maybePromptNotificationPermission() async {
    if (!widget.promptNotificationPermissionOnSuccess || !mounted) return;
    try {
      await NotificationPermissionPromptService.instance.maybePromptAfterValueAction(
        context,
        sourceTag: 'notifications.permission_after_set_wallpaper',
      );
    } catch (e, st) {
      logger.w('_maybePromptNotificationPermission: maybePromptAfterValueAction failed', error: e, stackTrace: st);
    }
  }

  Future<void> _start({bool forceSheet = false}) async {
    final String? url = widget.url;
    if (isLoading || url == null) return;
    PrismHaptics.tap();
    WallpaperSetResult? result;
    try {
      result = await SetWallpaperFlow.run(
        context,
        url: url,
        thumbnailUrl: widget.thumbnailUrl,
        forceSheet: forceSheet,
        onBusy: (busy) {
          if (mounted) setState(() => isLoading = busy);
        },
      );
    } catch (e, st) {
      logger.e('Set wallpaper failed', error: e, stackTrace: st);
    }
    if (result?.isSuccess ?? false) {
      if (!mounted) return;
      widget.onSet?.call();
      await _maybePromptNotificationPermission();
    }
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final WallpaperTarget? saved = SetWallpaperFlow.defaultTarget();
    final String semanticLabel = saved == null ? 'Set as wallpaper' : 'Set as wallpaper on ${_targetLabel(saved)}';
    final String? label = widget.label;
    final Widget button = label == null
        ? CircularMenuButton(
            label: semanticLabel,
            isLoading: isLoading,
            child: Icon(JamIcons.picture, color: theme.colorScheme.secondary, size: 20),
          )
        : PrimaryActionPill(icon: JamIcons.picture, label: label, semanticLabel: semanticLabel, isLoading: isLoading);
    final Widget circle = Stack(
      clipBehavior: Clip.none,
      children: <Widget>[
        button,
        if (saved != null)
          Positioned(
            right: -2,
            bottom: -2,
            child: Semantics(
              button: true,
              label: 'Change where wallpaper is set',
              child: GestureDetector(
                onTap: () => _start(forceSheet: true),
                child: CircleAvatar(
                  radius: 10,
                  backgroundColor: theme.colorScheme.primary,
                  child: Icon(Icons.tune, size: 12, color: theme.colorScheme.onPrimary),
                ),
              ),
            ),
          ),
      ],
    );
    return GestureDetector(
      behavior: label == null ? HitTestBehavior.deferToChild : HitTestBehavior.opaque,
      onTap: _start,
      onLongPress: () => _start(forceSheet: true),
      child: circle,
    );
  }
}

String _targetLabel(WallpaperTarget target) => switch (target) {
  WallpaperTarget.home => 'home screen',
  WallpaperTarget.lock => 'lock screen',
  WallpaperTarget.both => 'both screens',
};

class SetOptionsPanel extends StatefulWidget {
  final ValueChanged<SetWallpaperChoice> onSelected;
  const SetOptionsPanel({super.key, required this.onSelected});

  @override
  _SetOptionsPanelState createState() => _SetOptionsPanelState();
}

class _SetOptionsPanelState extends State<SetOptionsPanel> {
  WallpaperFit _fit = WallpaperFit.fill;
  bool _cropFirst = false;
  late final Future<aw.WallpaperCapabilities> _capabilities = aw.AsyncWallpaper.getCapabilities();

  void _select(WallpaperTarget target) {
    PrismHaptics.tap();
    widget.onSelected(SetWallpaperChoice(target, fit: _fit, useSystemCropper: _cropFirst));
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme scheme = theme.colorScheme;
    final bool canCrop = !kIsWeb && defaultTargetPlatform == TargetPlatform.android;
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
                  Text('Set Wallpaper as', textAlign: TextAlign.center, style: theme.textTheme.displayMedium),
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
                        (states) => states.contains(WidgetState.selected) ? scheme.onError : scheme.secondary,
                      ),
                      textStyle: WidgetStateProperty.resolveWith(
                        (states) => TextStyle(
                          fontFamily: PrismFonts.proximaNova,
                          fontWeight: states.contains(WidgetState.selected) ? FontWeight.bold : FontWeight.normal,
                        ),
                      ),
                    ),
                    onSelectionChanged: _cropFirst
                        ? null
                        : (selection) {
                            PrismHaptics.selection();
                            setState(() => _fit = selection.first);
                          },
                  ),
                  if (canCrop)
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text(
                        'Crop and position...',
                        style: TextStyle(
                          color: scheme.secondary,
                          fontFamily: PrismFonts.proximaNova,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      subtitle: Text(
                        'Choose the exact area in the system editor.',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: scheme.secondary.withValues(alpha: 0.7),
                          fontSize: 14,
                        ),
                      ),
                      value: _cropFirst,
                      onChanged: (value) {
                        PrismHaptics.selection();
                        setState(() => _cropFirst = value);
                      },
                    ),
                  const SizedBox(height: 4),
                  Text(
                    'Both sets it on your home screen and lock screen.',
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodySmall?.copyWith(color: scheme.secondary),
                  ),
                ],
              );
            },
          ),
        ),
      ),
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
