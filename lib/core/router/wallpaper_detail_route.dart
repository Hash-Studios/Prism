import 'dart:ui' show lerpDouble;

import 'package:Prism/core/motion/prism_motion.dart';
import 'package:Prism/theme/app_tokens.dart';
import 'package:auto_route/auto_route.dart';
import 'package:flutter/cupertino.dart' as cupertino;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

/// Matches [CustomRouteBuilder] without depending on the generated detail route or its arguments.
Route<T> wallpaperDetailRouteBuilder<T>(BuildContext context, Widget child, AutoRoutePage<T> page) =>
    _WallpaperDetailPageRoute<T>(
      page: page,
      child: child,
      isIOS: defaultTargetPlatform == TargetPlatform.iOS,
      duration: context.motion(PrismDurations.fast),
    );

/// The card Hero flies, and the page grows, on this curve. Sharing it keeps the page under the picture. Over 160 ms
/// it follows frames measured from the Pinterest closeup: about 10% of the way at 17 ms, 55% at 50 ms, 95% at 100 ms.
const Curve _zoomCurve = Cubic(0.45, 0.3, 0.1, 1);

/// Going back, the card Hero flies home on the flipped curve, so the page shrinks with the same timing it grew with.
const Curve _zoomOutCurve = FlippedCurve(_zoomCurve);

/// How dark the page behind gets while the detail grows over it.
const double _zoomDim = 0.3;

/// A straight path for every wallpaper Hero. A tile's Hero sets the path of the flight home, and the page shrinks
/// along a straight line, so a tile that kept the app's arc would leave the picture off the page.
RectTween wallpaperHeroRectTween(Rect? begin, Rect? end) => RectTween(begin: begin, end: end);

/// Where a page grows from and the card it grows into, in the coordinates of each route's page.
typedef _Zoom = ({Rect source, Rect target});

/// Where [hero] sits on the page of [route], without the route's transitions, as the Hero measures it.
Rect? _rectOn(ModalRoute<dynamic>? route, BuildContext hero) {
  final RenderObject? page = route?.subtreeContext?.findRenderObject();
  final RenderObject? box = hero.findRenderObject();
  if (page == null || box is! RenderBox || !box.hasSize) return null;
  return MatrixUtils.transformRect(box.getTransformTo(page), Offset.zero & box.size);
}

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

/// The Hero for the wallpaper card on the detail screen. When a tile opens the detail, or the detail goes back to its
/// tile, the flight tells the detail route where the tile and the card are. The route then grows the whole page out of
/// the tile with the picture, and shrinks it back the same way, as on the Pinterest closeup. Without a flight (reduce
/// motion, a deep link, a card that changed wallpaper) nothing changes.
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
      createRectTween: wallpaperHeroRectTween,
      flightShuttleBuilder: (_, animation, direction, fromHero, toHero) {
        if (direction == HeroFlightDirection.push) {
          detailRoute?._startZoom(tile: fromHero, card: toHero, out: false);
        } else {
          detailRoute?._startZoom(tile: toHero, card: fromHero, out: true);
        }
        // The picture fills the flight, so it morphs between the tile and the card.
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

/// The Material mixin only makes the route a type that auto_route's Android pages agree to transition to, so they take
/// [delegatedTransition]. This class overrides the mixin's timing and transitions.
class _WallpaperDetailPageRoute<T> extends PageRoute<T> with MaterialRouteTransitionMixin<T> {
  _WallpaperDetailPageRoute({
    required AutoRoutePage<T> page,
    required this.child,
    required this.isIOS,
    required this.duration,
  }) : super(settings: page, fullscreenDialog: page.fullscreenDialog, allowSnapshotting: page.allowSnapshotting);

  final Widget child;
  final bool isIOS;
  final Duration duration;

  @override
  Widget buildContent(BuildContext context) => child;

  @override
  Duration get transitionDuration => duration;

  @override
  Duration get reverseTransitionDuration => duration;

  @override
  bool get maintainState => _page.maintainState;

  @override
  bool get opaque => _page.opaque;

  @override
  bool canTransitionTo(TransitionRoute<dynamic> nextRoute) => nextRoute is PageRoute && !nextRoute.fullscreenDialog;

  /// Whether the opening finished. A back before that reverses the fade instead of sliding.
  bool _hasEntered = false;

  /// Set when the card Hero starts a flight in or home, cleared when the transition settles.
  _Zoom? _zoom;

  /// Whether [_zoom] came from a flight home. A back that turns an opening around keeps the opening's curve.
  bool _zoomingOut = false;

  /// The picture on the tile the card flew in from. Kept while the page is open.
  ImageProvider? _tilePicture;

  /// The route under this one. Its page holds the tile, and it zooms with the card.
  ModalRoute<dynamic>? _behind;

  AutoRoutePage<T> get _page => settings as AutoRoutePage<T>;

  @override
  void install() {
    super.install();
    _page.routeData.setAnimation(animation);
    controller!.addStatusListener((status) {
      if (status == AnimationStatus.completed) _hasEntered = true;
    });
    animation!.addStatusListener((status) {
      if (status.isAnimating) return;
      _zoom = null;
      _zoomingOut = false;
    });
  }

  @override
  void didChangePrevious(Route<dynamic>? previousRoute) {
    _behind = previousRoute is ModalRoute<dynamic> ? previousRoute : null;
    super.didChangePrevious(previousRoute);
  }

  /// Keeps the tile's picture, and measures the tile and the card the way the Hero does, each on its own page.
  void _startZoom({required BuildContext tile, required BuildContext card, required bool out}) {
    _tilePicture ??= _pictureIn(tile);
    final Rect? source = _rectOn(_behind, tile);
    final Rect? target = _rectOn(this, card);
    if (source == null || target == null || source.isEmpty || !source.isFinite || target.isEmpty || !target.isFinite) {
      return;
    }
    _zoom = (source: source, target: target);
    _zoomingOut = out;
  }

  /// The zoom to show now. A swipe back and reduce motion never zoom.
  _Zoom? _zoomFor(BuildContext context) => context.reduceMotion || popGestureInProgress ? null : _zoom;

  Curve get _curve => _zoomingOut ? _zoomOutCurve : _zoomCurve;

  @override
  DelegatedTransitionBuilder? get delegatedTransition => _zoomBehind;

  /// Zooms the page behind with the card, as the Pinterest feed does: the page scales and moves so its tile stays
  /// under the card, toward the screen on the way in and back to its place on the way out.
  Widget _zoomBehind(
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    bool allowSnapshotting,
    Widget? child,
  ) {
    final _Zoom? zoom = _zoomFor(context);
    Matrix4 transform = Matrix4.identity();
    if (zoom != null) {
      final Rect card = Rect.lerp(zoom.source, zoom.target, _curve.transform(secondaryAnimation.value))!;
      final double scale = card.width / zoom.source.width;
      final Offset shift = card.topLeft - zoom.source.topLeft * scale;
      transform = Matrix4.translationValues(shift.dx, shift.dy, 0)..scaleByDouble(scale, scale, 1, 1);
    }

    Widget content = child ?? const SizedBox.shrink();
    if (isIOS) {
      // Delegation replaces Cupertino's secondary transition. Restore its native parallax for a back that slides
      // natively. An opening without a tile fades in over a page that stays still.
      final bool slidingBack =
          popGestureInProgress || (_hasEntered && secondaryAnimation.status == AnimationStatus.reverse);
      content = cupertino.CupertinoPageTransition(
        primaryRouteAnimation: kAlwaysCompleteAnimation,
        secondaryRouteAnimation: zoom == null && slidingBack && !context.reduceMotion
            ? secondaryAnimation
            : kAlwaysDismissedAnimation,
        linearTransition: popGestureInProgress,
        child: content,
      );
    }
    return Transform(transform: transform, child: content);
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
    // Back shrinks the page into its tile. A swipe, or a back with no tile to go to, slides natively.
    final bool returning =
        isIOS &&
        (popGestureInProgress || (_hasEntered && animation.status == AnimationStatus.reverse && _zoom == null));
    final _Zoom? zoom = returning ? null : _zoomFor(context);
    // One widget shape for every case, so the page is never re-parented when a zoom ends.
    final Widget body = _DetailTransition(
      animation: animation,
      zoom: zoom,
      curve: _curve,
      fade: zoom != null || reduceMotion || returning
          ? kAlwaysCompleteAnimation
          : animation.drive(CurveTween(curve: PrismCurves.enter)),
      child: child,
    );
    if (!isIOS) return body;

    // Keep Flutter's native edge detector in the tree, but suppress its lateral entry motion.
    // The real route animation still drives Hero flights. Back swipes use the native slide.
    return cupertino.CupertinoRouteTransitionMixin.buildPageTransitions<T>(
      this,
      context,
      returning && !reduceMotion ? animation : kAlwaysCompleteAnimation,
      reduceMotion ? kAlwaysDismissedAnimation : secondaryAnimation,
      body,
    );
  }
}

/// Fades the page in or, when the card Hero flies between a tile and the card, grows the page out of that tile or
/// shrinks it back. The page scales and moves with the flight's left edge, top edge and width, so its card sits under
/// the flying picture, and shows through a rounded window between the tile and the screen while the page behind dims.
/// Without a zoom every transform here is the identity.
class _DetailTransition extends AnimatedWidget {
  const _DetailTransition({
    required Animation<double> animation,
    required this.zoom,
    required this.curve,
    required this.fade,
    required this.child,
  }) : super(listenable: animation);

  final _Zoom? zoom;

  /// The card Hero's curve for this flight.
  final Curve curve;
  final Animation<double> fade;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final _Zoom? zoom = this.zoom;
    final double t = zoom == null ? 1 : curve.transform((listenable as Animation<double>).value);
    final bool blockBackground = zoom != null || (listenable as Animation<double>).status.isAnimating;
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
            // Keep taps off the page behind for both the zoom and its fade fallback, including while the route pops.
            IgnorePointer(
              ignoring: !blockBackground,
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
