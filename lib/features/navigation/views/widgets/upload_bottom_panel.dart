import 'dart:io';

import 'package:Prism/analytics/analytics_service.dart';
import 'package:Prism/core/analytics/events/events.dart';
import 'package:Prism/core/purchases/paywall_orchestrator.dart';
import 'package:Prism/core/purchases/upload_quota.dart';
import 'package:Prism/core/router/app_router.dart';
import 'package:Prism/core/state/app_state.dart' as app_state;
import 'package:Prism/core/widgets/prism/prism_ui.dart';
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
    if (!app_state.prismUser.premium && !UploadQuota.hasFreeUploadQuotaRemaining()) {
      toasts.success('Free users can upload ${UploadQuota.freeUploadsPerWeek} wallpapers per week.');
      if (mounted) {
        Navigator.of(context).pop();
        await PaywallOrchestrator.instance.present(
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
    router.push(AiTabRoute());
  }

  @override
  Widget build(BuildContext context) {
    final bool isPremium = app_state.prismUser.premium;
    final TextStyle caption = PrismTextStyles.caption(context);
    final Color chevron = Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.35);

    return PrismSheetBody(
      title: 'Create',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          PrismGroup(
            children: <Widget>[
              PrismRow(
                icon: Icons.photo_library_rounded,
                title: 'Upload a wallpaper',
                subtitle: 'From your gallery',
                onTap: _onWallpaperTap,
              ),
              PrismRow(
                icon: Icons.auto_awesome_rounded,
                title: 'AI wallpaper',
                subtitle: 'Describe a scene and generate a phone wallpaper',
                onTap: _onAiTap,
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    const PrismTag(label: 'New', tone: PrismTone.accent),
                    const SizedBox(width: PrismSpace.xxs),
                    Icon(Icons.chevron_right_rounded, size: 20, color: chevron),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: PrismSpace.md),
          if (!isPremium) ...<Widget>[
            Text(
              '${UploadQuota.remainingFreeUploadsThisWeek()} of ${UploadQuota.freeUploadsPerWeek} free uploads left this week',
              style: caption,
            ),
            const SizedBox(height: PrismSpace.xxs),
          ],
          Text('Only upload original, high-quality wallpapers. Do not upload content from other apps.', style: caption),
        ],
      ),
    );
  }
}
