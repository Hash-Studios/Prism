import 'package:Prism/analytics/analytics_service.dart';
import 'package:Prism/core/analytics/events/events.dart';
import 'package:Prism/core/haptics/prism_haptics.dart';
import 'package:Prism/core/motion/prism_motion.dart';
import 'package:Prism/core/state/app_state.dart' as app_state;
import 'package:Prism/core/widgets/animated/press_scale.dart';
import 'package:Prism/core/widgets/popup/sign_in_pop_up.dart';
import 'package:Prism/core/widgets/prism_sheet.dart';
import 'package:Prism/features/navigation/views/widgets/nav_glass.dart';
import 'package:Prism/features/navigation/views/widgets/upload_bottom_panel.dart';
import 'package:Prism/l10n/l10n.dart';
import 'package:flutter/material.dart';

/// The round create button: a glass disc like the tab pill, with a plus inside the rainbow brand ring. The ring turns
/// once over five seconds.
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
    _rotationController = AnimationController(vsync: this, duration: const Duration(seconds: 5));
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Stop the controller so hidden time does not count toward the turn.
    final bool spin = TickerMode.valuesOf(context).enabled && !context.reduceMotion;
    if (spin && !_rotationController.isAnimating && !_rotationController.isCompleted) {
      _rotationController.forward();
    } else if (!spin && _rotationController.isAnimating) {
      _rotationController.stop();
    }
  }

  @override
  void dispose() {
    _rotationController.dispose();
    super.dispose();
  }

  void _openUploadSheet() {
    if (!mounted) return;
    showPrismSheet<void>(context, builder: (context) => const UploadBottomPanel());
  }

  void _onPressed() {
    PrismHaptics.tap();
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
    return Semantics(
      button: true,
      label: context.l10n.wallpaperUploadAction,
      excludeSemantics: true,
      onTap: _onPressed,
      child: PressScale(
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: _onPressed,
          child: SizedBox(
            width: 56,
            height: 56,
            child: NavGlass(
              circle: true,
              child: Stack(
                fit: StackFit.expand,
                children: <Widget>[
                  ClipPath(
                    clipper: const _RingClipper(),
                    child: RepaintBoundary(
                      child: RotationTransition(
                        turns: _rotationController,
                        child: Stack(
                          fit: StackFit.expand,
                          children: <Widget>[
                            Image.asset('assets/images/button_middle_layer.webp'),
                            Image.asset('assets/images/button_topmost_layer.webp'),
                          ],
                        ),
                      ),
                    ),
                  ),
                  Icon(Icons.add_rounded, size: 26, color: Theme.of(context).colorScheme.secondary),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Keeps the outer band of the rainbow art, so the brand ring frames a glass centre. The art's disc ends 24.5 pt from
/// the centre of the 56 pt button.
class _RingClipper extends CustomClipper<Path> {
  const _RingClipper();

  static const double innerRadius = 21;

  @override
  Path getClip(Size size) {
    final Offset center = size.center(Offset.zero);
    return Path()
      ..fillType = PathFillType.evenOdd
      ..addOval(Rect.fromCircle(center: center, radius: size.shortestSide / 2))
      ..addOval(Rect.fromCircle(center: center, radius: innerRadius));
  }

  @override
  bool shouldReclip(_RingClipper oldClipper) => false;
}
