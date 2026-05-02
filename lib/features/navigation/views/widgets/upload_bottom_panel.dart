import 'dart:io';

import 'package:Prism/analytics/analytics_service.dart';
import 'package:Prism/core/analytics/events/events.dart';
import 'package:Prism/core/purchases/paywall_orchestrator.dart';
import 'package:Prism/core/purchases/upload_quota.dart';
import 'package:Prism/core/router/app_router.dart';
import 'package:Prism/core/state/app_state.dart' as app_state;
import 'package:Prism/features/ai_wallpaper/views/widgets/ai_sheet_chrome.dart';
import 'package:Prism/theme/jam_icons_icons.dart';
import 'package:Prism/theme/toasts.dart' as toasts;
import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

class UploadBottomPanel extends StatefulWidget {
  const UploadBottomPanel({super.key});

  @override
  State<UploadBottomPanel> createState() => _UploadBottomPanelState();
}

class _UploadBottomPanelState extends State<UploadBottomPanel> {
  final ImagePicker _picker = ImagePicker();

  Future<void> _pickWallpaperImage() async {
    final pickedFile = await _picker.pickImage(source: ImageSource.gallery);
    if (!mounted || pickedFile == null) {
      return;
    }
    final wallpaper = File(pickedFile.path);
    final router = context.router;
    Navigator.pop(context);
    router.push(EditWallRoute(image: wallpaper));
  }

  Future<void> _onWallpaperTap() async {
    analytics.track(
      const UploadActionSelectedEvent(
        action: AnalyticsActionValue.uploadWallpaperSelected,
        entrypoint: EntryPointValue.bottomNav,
      ),
    );
    if (app_state.prismUser.premium != true && !UploadQuota.hasFreeUploadQuotaRemaining()) {
      toasts.codeSend('Free users can upload ${UploadQuota.freeUploadsPerWeek} wallpapers per week.');
      if (mounted) {
        Navigator.of(context).pop();
        await PaywallOrchestrator.instance.present(
          context,
          placement: PaywallPlacement.uploadLimitReached,
          source: 'upload_wallpaper_limit_reached',
        );
      }
      return;
    }
    await _pickWallpaperImage();
  }

  void _onAiTap() {
    analytics.track(
      const UploadActionSelectedEvent(
        action: AnalyticsActionValue.uploadAiSelected,
        entrypoint: EntryPointValue.bottomNav,
      ),
    );
    final router = context.router;
    Navigator.pop(context);
    router.push(const AiTabRoute());
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final ColorScheme scheme = theme.colorScheme;
    final secondary = scheme.secondary;
    final accentColor = scheme.error;
    final Color aiAccent = scheme.primary;
    final bool isPremium = app_state.prismUser.premium;
    final int remainingUploads = UploadQuota.remainingFreeUploadsThisWeek();
    final bool quotaLow = !isPremium && remainingUploads <= 1;

    return SafeArea(
      child: Padding(
        padding: AiSheetChrome.bodyPadding,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            const AiSheetDragHandle(),
            const SizedBox(height: 16),
            Text('Create', style: theme.textTheme.displayMedium),
            const SizedBox(height: 4),
            Text(
              'What would you like to create?',
              style: theme.textTheme.bodySmall?.copyWith(color: secondary.withValues(alpha: 0.65)),
            ),
            const SizedBox(height: 20),
            _PressScaleWrapper(
              child: _CreateActionTile(
                icon: JamIcons.pictures_f,
                iconColor: accentColor,
                title: 'Wallpapers',
                subtitle: quotaLow
                    ? '$remainingUploads free upload${remainingUploads == 1 ? '' : 's'} left this week'
                    : 'From your gallery',
                onTap: _onWallpaperTap,
              ),
            ),
            _TileDivider(color: secondary),
            _PressScaleWrapper(
              child: _CreateActionTile(
                icon: Icons.auto_awesome_rounded,
                iconColor: aiAccent,
                title: 'AI wallpaper',
                subtitle: 'Describe a scene and generate a phone wallpaper',
                badge: 'NEW',
                badgeColor: aiAccent,
                onTap: _onAiTap,
              ),
            ),
            const SizedBox(height: 20),
            Text(
              'Please only upload high-quality original wallpapers. Do not upload content from other apps.',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodySmall?.copyWith(fontSize: 11, color: secondary.withValues(alpha: 0.4)),
            ),
          ],
        ),
      ),
    );
  }
}

class _PressScaleWrapper extends StatefulWidget {
  const _PressScaleWrapper({required this.child});

  final Widget child;

  @override
  State<_PressScaleWrapper> createState() => _PressScaleWrapperState();
}

class _PressScaleWrapperState extends State<_PressScaleWrapper> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final bool motion = !MediaQuery.of(context).disableAnimations;
    return Listener(
      behavior: HitTestBehavior.translucent,
      onPointerDown: (_) => setState(() => _pressed = true),
      onPointerUp: (_) => setState(() => _pressed = false),
      onPointerCancel: (_) => setState(() => _pressed = false),
      child: AnimatedScale(
        scale: _pressed && motion ? 0.98 : 1.0,
        duration: motion ? const Duration(milliseconds: 100) : Duration.zero,
        curve: Curves.easeOutCubic,
        child: widget.child,
      ),
    );
  }
}

class _TileDivider extends StatelessWidget {
  final Color color;
  const _TileDivider({required this.color});

  @override
  Widget build(BuildContext context) {
    return Divider(height: 1, thickness: 0.5, color: color.withValues(alpha: 0.12), indent: 64);
  }
}

class _CreateActionTile extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String title;
  final String subtitle;
  final String? badge;
  final Color? badgeColor;
  final VoidCallback onTap;

  const _CreateActionTile({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.badge,
    this.badgeColor,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final secondary = theme.colorScheme.secondary;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Row(
            children: <Widget>[
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: iconColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: iconColor, size: 22),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Row(
                      children: <Widget>[
                        Text(
                          title,
                          style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700, color: secondary),
                        ),
                        if (badge != null) ...<Widget>[
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: (badgeColor ?? iconColor).withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(4),
                              border: Border.all(color: (badgeColor ?? iconColor).withValues(alpha: 0.5), width: 0.5),
                            ),
                            child: Text(
                              badge!,
                              style: theme.textTheme.labelSmall?.copyWith(
                                fontSize: 10,
                                fontWeight: FontWeight.w800,
                                color: badgeColor ?? iconColor,
                                letterSpacing: 0.4,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: secondary.withValues(alpha: 0.55),
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right_rounded, color: secondary.withValues(alpha: 0.35), size: 20),
            ],
          ),
        ),
      ),
    );
  }
}
