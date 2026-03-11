import 'dart:io';

import 'package:Prism/analytics/analytics_service.dart';
import 'package:Prism/core/analytics/events/events.dart';
import 'package:Prism/core/purchases/paywall_orchestrator.dart';
import 'package:Prism/core/purchases/upload_quota.dart';
import 'package:Prism/core/router/app_router.dart';
import 'package:Prism/core/state/app_state.dart' as app_state;
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

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.of(context).size.width * 0.85;
    return Container(
      height: MediaQuery.of(context).size.height / 1.5 > 500 ? MediaQuery.of(context).size.height / 1.5 : 500,
      decoration: BoxDecoration(
        color: Theme.of(context).primaryColor,
        borderRadius: const BorderRadius.only(topLeft: Radius.circular(20), topRight: Radius.circular(20)),
      ),
      child: Column(
        children: <Widget>[
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Padding(
                padding: const EdgeInsets.all(12.0),
                child: Container(
                  height: 5,
                  width: 30,
                  decoration: BoxDecoration(
                    color: Theme.of(context).hintColor,
                    borderRadius: BorderRadius.circular(500),
                  ),
                ),
              ),
            ],
          ),
          const Spacer(),
          Text('Upload', style: Theme.of(context).textTheme.displayMedium),
          const Spacer(flex: 2),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              _UploadTypeCard(
                width: width,
                title: 'Wallpapers',
                imageAsset: 'assets/images/wallpaper.jpg',
                onTap: () async {
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
                },
              ),
              _UploadTypeCard(
                width: width,
                title: 'Setups',
                imageAsset: 'assets/images/setup.jpg',
                onTap: () async {
                  analytics.track(
                    const UploadActionSelectedEvent(
                      action: AnalyticsActionValue.uploadSetupSelected,
                      entrypoint: EntryPointValue.bottomNav,
                    ),
                  );
                  if (!app_state.prismUser.premium) {
                    Navigator.pop(context);
                    await PaywallOrchestrator.instance.present(
                      context,
                      placement: PaywallPlacement.blockedSetupCreate,
                      source: 'upload_setup_blocked',
                    );
                    return;
                  }
                  final router = context.router;
                  Navigator.pop(context);
                  router.push(const SetupGuidelinesRoute());
                },
              ),
            ],
          ),
          const Spacer(flex: 2),
          Padding(
            padding: const EdgeInsets.fromLTRB(0, 0, 0, 32),
            child: SizedBox(
              width: MediaQuery.of(context).size.width * 0.8,
              child: Text(
                'Please only upload high-quality original wallpapers and setups. Please do not upload wallpapers from other apps. You can also report wallpapers or setups by clicking the copyright button after opening them.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 13, color: Theme.of(context).colorScheme.secondary),
              ),
            ),
          ),
          const Spacer(),
        ],
      ),
    );
  }
}

class _UploadTypeCard extends StatelessWidget {
  final double width;
  final String title;
  final String imageAsset;
  final Future<void> Function() onTap;

  const _UploadTypeCard({required this.width, required this.title, required this.imageAsset, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Padding(
          padding: const EdgeInsets.all(8.0),
          child: GestureDetector(
            onTap: onTap,
            child: SizedBox(
              width: width / 2 - 20,
              height: width / 2 / 0.6625,
              child: Stack(
                alignment: Alignment.center,
                children: <Widget>[
                  Container(
                    width: width / 2 - 14,
                    height: width / 2 / 0.6625,
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.error.withValues(alpha: 0.2),
                      border: Border.all(color: Theme.of(context).colorScheme.error, width: 3),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(16),
                      child: Image.asset(imageAsset, fit: BoxFit.cover),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.only(top: 60.0),
                    child: Align(
                      alignment: Alignment.topCenter,
                      child: Container(
                        decoration: BoxDecoration(
                          border: Border.all(color: Theme.of(context).colorScheme.error),
                          color: Theme.of(context).colorScheme.error.withValues(alpha: 0.2),
                          shape: BoxShape.circle,
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Icon(JamIcons.plus, color: Theme.of(context).colorScheme.error, size: 40),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        Text(
          title,
          style: TextStyle(fontSize: 16, color: Theme.of(context).colorScheme.secondary, fontWeight: FontWeight.bold),
        ),
      ],
    );
  }
}
