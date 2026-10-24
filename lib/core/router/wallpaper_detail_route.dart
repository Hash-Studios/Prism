import 'dart:ui' show lerpDouble;

import 'package:Prism/core/motion/prism_motion.dart';
import 'package:Prism/theme/app_tokens.dart';
import 'package:auto_route/auto_route.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

/// Matches [CustomRouteBuilder] without depending on the generated detail route or its arguments.
Route<T> wallpaperDetailRouteBuilder<T>(BuildContext context, Widget child, AutoRoutePage<T> page) =>
    _WallpaperDetailPageRoute<T>(
      page: page,
      child: child,
      isIOS: defaultTargetPlatform == TargetPlatform.iOS,
      duration: context.motion(PrismDurations.base),
    );

/// The card Hero flies, and the page grows, on this curve. Sharing it keeps the page under the picture. A strong
/// ease-out: over 240 ms it follows the Pinterest opening, which covers about 70% of the way in the first 50 ms.
const Curve _zoomCurve = PrismCurves.enter;

/// How dark the page behind gets while the detail grows over it.
const double _zoomDim = 0.3;

/// Where a page grows from and the card it grows into, in the navigator's coordinates.
typedef _Zoom = ({Rect source, Rect target});

/// The image a tile's Hero shows. The same provider finds the tile's decoded pixels in the image cache.
ImageProvider? _pictureIn(BuildContext hero) {
  ImageProvider? picture;
  void visit(Element element) {
    if (picture != null) return;
    final Widget widget = element.widget;
    if (widget is Image) {
      picture = widget.image;
    } else {
      element.visitChildren(visit);
    }
  }

  // The flight builds its shuttle inside a build, where visitChildElements asserts. A pushed-from Hero keeps its
  // children for the whole flight, so they are safe to read.
  (hero as Element).visitChildren(visit);
  return picture;
}

/// The Hero for the wallpaper card on the detail screen. When a tile opens the detail, its flight tells the detail
/// route where it starts and where the card lands. The route then grows the whole page out of the tile with the
/// picture, as on the Pinterest closeup. Without a flight (reduce motion, a deep link) nothing changes.
class WallpaperDetailHero extends StatelessWidget {
  const WallpaperDetailHero({super.key, required this.tag, required this.radius, required this.image});

  final Object tag;

  /// Corner radius of the card. A flight widens it from a grid tile's radius.
  final double radius;
  final Widget image;

  @override
  Widget build(BuildContext context) {
    final ModalRoute<Object?>? route = ModalRoute.of(context);
    final _WallpaperDetailPageRoute<Object?>? detailRoute = route is _WallpaperDetailPageRoute<Object?> ? route : null;
    // The card decodes its own copy of the picture, which takes a few frames. Until it fades in, the tile's decoded
    // picture shows under it. Read when built: the flight finds it, and the card builds again when the flight lands.
    Widget picture() {
      final ImageProvider? tile = detailRoute?._tilePicture;
      if (tile == null) return image;
      return Stack(
        fit: StackFit.expand,
        children: [
          Image(image: tile, fit: BoxFit.cover, excludeFromSemantics: true),
          image,
        ],
      );
    }

    return Hero(
      tag: tag,
      curve: _zoomCurve,
      // A straight path, so the page can follow the same rectangle.
      createRectTween: (begin, end) => RectTween(begin: begin, end: end),
      flightShuttleBuilder: (_, animation, direction, fromHero, toHero) {
        // Going back, the tile's own picture flies home.
        if (direction == HeroFlightDirection.pop) return (toHero.widget as Hero).child;
        detailRoute?._startZoom(fromHero, toHero);
        // The picture fills the flight, so it starts as the tile and morphs into the card.
        return AnimatedBuilder(
          animation: animation,
          child: picture(),
          builder: (_, child) => ClipRRect(
            borderRadius: BorderRadius.circular(lerpDouble(PrismRadius.sm, radius, animation.value)!),
            child: child,
          ),
        );
      },
      child: ClipRRect(
        borderRadius: BorderRadius.circular(radius),
        child: Builder(builder: (_) => picture()),
      ),
    );
  }
}

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

  /// Set when the card Hero starts its flight in, cleared when the transition settles. Later pops do not zoom.
  _Zoom? _zoom;

  /// The picture on the tile the card flew in from. Kept while the page is open.
  ImageProvider? _tilePicture;

  AutoRoutePage<T> get _page => settings as AutoRoutePage<T>;

  @override
  void install() {
    super.install();
    _page.routeData.setAnimation(animation);
    animation!.addStatusListener((status) {
      if (!status.isAnimating) _zoom = null;
    });
  }

  /// Keeps the tile's picture, and measures the tile and the card the way the Hero does, in the navigator's
  /// coordinates.
  void _startZoom(BuildContext fromHero, BuildContext toHero) {
    _tilePicture = _pictureIn(fromHero);
    final RenderObject? navigator = this.navigator?.context.findRenderObject();
    Rect? rectOf(BuildContext hero) {
      final RenderObject? box = hero.findRenderObject();
      if (navigator == null || box is! RenderBox || !box.hasSize) return null;
      return MatrixUtils.transformRect(box.getTransformTo(navigator), Offset.zero & box.size);
    }

    final Rect? source = rectOf(fromHero);
    final Rect? target = rectOf(toHero);
    if (source == null || target == null || !source.isFinite || target.isEmpty || !target.isFinite) return;
    _zoom = (source: source, target: target);
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
    // Back during the opening shrinks the page back into its tile; back after it, or a swipe, slides natively.
    final bool returning =
        isIOS && (popGestureInProgress || (animation.status == AnimationStatus.reverse && _zoom == null));
    final _Zoom? zoom = reduceMotion || returning ? null : _zoom;
    // One widget shape for every case, so the page is never re-parented when a zoom ends.
    final Widget body = _DetailTransition(
      animation: animation,
      zoom: zoom,
      fade: zoom != null || reduceMotion || returning
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

/// Fades the page in or, when the card Hero flies in from a tile, grows the page out of that tile. The page scales
/// and moves with the flight's left edge, top edge and width, so its card sits under the flying picture, and shows
/// through a rounded window that widens from the tile to the screen while the page behind dims. Without a zoom every
/// transform here is the identity.
class _DetailTransition extends AnimatedWidget {
  const _DetailTransition({
    required Animation<double> animation,
    required this.zoom,
    required this.fade,
    required this.child,
  }) : super(listenable: animation);

  final _Zoom? zoom;
  final Animation<double> fade;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final _Zoom? zoom = this.zoom;
    final double t = zoom == null ? 1 : _zoomCurve.transform((listenable as Animation<double>).value);
    final Color scrim = Theme.of(context).colorScheme.scrim;
    return LayoutBuilder(
      builder: (context, box) {
        final Rect screen = Offset.zero & box.biggest;
        final Rect card = zoom == null ? screen : Rect.lerp(zoom.source, zoom.target, t)!;
        final double scale = zoom == null ? 1 : card.width / zoom.target.width;
        final Rect window = zoom == null ? screen : Rect.lerp(zoom.source, screen, t)!;
        return Stack(
          fit: StackFit.expand,
          children: [
            // While the page grows, the dim takes every tap outside its window, so the page behind cannot open
            // another route.
            IgnorePointer(
              ignoring: zoom == null,
              child: ColoredBox(color: scrim.withValues(alpha: zoom == null ? 0 : _zoomDim * t)),
            ),
            ClipRRect(
              clipper: _WindowClipper(
                RRect.fromRectAndRadius(window, Radius.circular(zoom == null ? 0 : lerpDouble(PrismRadius.sm, 0, t)!)),
              ),
              clipBehavior: zoom == null ? Clip.none : Clip.antiAlias,
              child: Transform.translate(
                offset: zoom == null ? Offset.zero : card.topLeft - zoom.target.topLeft * scale,
                child: Transform.scale(
                  scale: scale,
                  alignment: Alignment.topLeft,
                  child: FadeTransition(opacity: fade, child: child),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _WindowClipper extends CustomClipper<RRect> {
  const _WindowClipper(this.window);

  final RRect window;

  @override
  RRect getClip(Size size) => window;

  @override
  bool shouldReclip(_WindowClipper oldClipper) => oldClipper.window != window;
}
