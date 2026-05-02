import 'package:Prism/analytics/analytics_service.dart';
import 'package:Prism/core/analytics/events/events.dart';
import 'package:Prism/core/state/app_state.dart' as app_state;
import 'package:Prism/core/widgets/popup/signInPopUp.dart';
import 'package:Prism/features/navigation/views/widgets/upload_bottom_panel.dart';
import 'package:flutter/material.dart';

class PrismFab extends StatefulWidget {
  const PrismFab({super.key});

  @override
  State<PrismFab> createState() => _PrismFabState();
}

class _PrismFabState extends State<PrismFab> with SingleTickerProviderStateMixin {
  late final AnimationController _rotationController;

  @override
  void initState() {
    super.initState();
    _rotationController = AnimationController(vsync: this, duration: const Duration(seconds: 5))..repeat();
  }

  @override
  void dispose() {
    _rotationController.dispose();
    super.dispose();
  }

  void _openUploadSheet() {
    if (!mounted) return;
    showModalBottomSheet<void>(
      isScrollControlled: true,
      backgroundColor: Theme.of(context).primaryColor,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      context: context,
      builder: (context) => const UploadBottomPanel(),
    );
  }

  void _onPressed() {
    analytics.track(
      const UploadActionSelectedEvent(
        action: AnalyticsActionValue.uploadSheetOpened,
        entrypoint: EntryPointValue.bottomNav,
      ),
    );
    if (!app_state.prismUser.loggedIn) {
      googleSignInPopUp(context, () {
        if (mounted) _openUploadSheet();
      });
      return;
    }
    _openUploadSheet();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: _onPressed,
      child: SizedBox(
        width: 56,
        height: 56,
        child: Stack(
          fit: StackFit.expand,
          children: [
            Image.asset('assets/images/button_bottom_layer.webp'),
            RotationTransition(
              turns: _rotationController,
              child: Image.asset('assets/images/button_middle_layer.webp'),
            ),
            Image.asset('assets/images/button_top_layer.webp'),
            RotationTransition(
              turns: _rotationController,
              child: Image.asset('assets/images/button_topmost_layer.webp'),
            ),
          ],
        ),
      ),
    );
  }
}
