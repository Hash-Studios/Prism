import 'package:Prism/core/motion/prism_motion.dart';
import 'package:auto_route/auto_route.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';

/// Matches [CustomRouteBuilder] without depending on the generated detail route or its arguments.
Route<T> wallpaperDetailRouteBuilder<T>(BuildContext context, Widget child, AutoRoutePage<T> page) =>
    _WallpaperDetailPageRoute<T>(
      page: page,
      child: child,
      isIOS: defaultTargetPlatform == TargetPlatform.iOS,
      duration: context.motion(PrismDurations.base),
    );

class _WallpaperDetailPageRoute<T> extends PageRouteBuilder<T> {
  _WallpaperDetailPageRoute({
    required AutoRoutePage<T> page,
    required Widget child,
    required this.isIOS,
    required Duration duration,
  }) : super(
         settings: page,
         maintainState: page.maintainState,
         fullscreenDialog: page.fullscreenDialog,
         allowSnapshotting: page.allowSnapshotting,
         opaque: page.opaque,
         transitionDuration: duration,
         reverseTransitionDuration: duration,
         pageBuilder: (_, _, _) => Semantics(scopesRoute: true, explicitChildNodes: true, child: child),
       );

  final bool isIOS;

  AutoRoutePage<T> get _page => settings as AutoRoutePage<T>;

  @override
  void install() {
    super.install();
    _page.routeData.setAnimation(animation);
  }

  @override
  bool get popGestureEnabled {
    if (!super.popGestureEnabled) return false;
    final router = _page.routeData.router;
    return router.isTopMost || !router.topMostRouter().canPop(ignoreParentRoutes: true, ignorePagelessRoutes: true);
  }

  @override
  Widget buildTransitions(
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    final bool reduceMotion = context.reduceMotion;
    final bool returning = isIOS && (popGestureInProgress || animation.status == AnimationStatus.reverse);
    final Widget body = FadeTransition(
      opacity: reduceMotion || returning
          ? kAlwaysCompleteAnimation
          : animation.drive(CurveTween(curve: PrismCurves.enter)),
      child: child,
    );
    if (!isIOS) return body;

    // Keep Flutter's native edge detector in the tree, but suppress its lateral entry motion.
    // The real route animation still drives Hero flights. Back swipes use the native slide.
    return CupertinoRouteTransitionMixin.buildPageTransitions<T>(
      this,
      context,
      returning && !reduceMotion ? animation : kAlwaysCompleteAnimation,
      reduceMotion ? kAlwaysDismissedAnimation : secondaryAnimation,
      body,
    );
  }
}
