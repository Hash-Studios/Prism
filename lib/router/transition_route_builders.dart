import 'dart:ui';

import 'package:animations/animations.dart';
import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:sprung/sprung.dart';

Route<T> sharedAxisZTransitionRouteBuilder<T>(
    BuildContext context, Widget child, CustomPage<T> page) {
  return PageRouteBuilder(
    settings: page,
    pageBuilder: (context, animation1, animation2) => SharedAxisTransition(
      animation: animation1,
      secondaryAnimation: animation2,
      transitionType: SharedAxisTransitionType.scaled,
      fillColor: Theme.of(context).backgroundColor,
      child: child,
    ),
  );
}

Route<T> slideTransitionRouteBuilder<T>(
    BuildContext context, Widget child, CustomPage<T> page) {
  final spring =
      Sprung.custom(mass: 1, damping: 18, stiffness: 120, velocity: 0);
  return PageRouteBuilder(
    transitionDuration: const Duration(milliseconds: 1000),
    settings: page,
    transitionsBuilder: (context, animation, secondaryAnimation, child) {
      return Stack(
        children: [
          FadeTransition(
            opacity: Tween<double>(
              begin: 0,
              end: 1,
            ).chain(CurveTween(curve: spring)).animate(animation),
            child: Container(
              width: double.infinity,
              height: double.infinity,
              color: Theme.of(context).backgroundColor,
            ),
          ),
          FadeTransition(
            opacity: Tween<double>(
              begin: 0,
              end: 1,
            ).chain(CurveTween(curve: spring)).animate(animation),
            child: FadeTransition(
              opacity: Tween<double>(
                begin: 1,
                end: 0,
              ).chain(CurveTween(curve: spring)).animate(secondaryAnimation),
              child: SlideTransition(
                position: Tween<Offset>(
                  begin: const Offset(1.0, 0.0),
                  end: Offset.zero,
                ).chain(CurveTween(curve: spring)).animate(animation),
                child: SlideTransition(
                    position: Tween<Offset>(
                      begin: Offset.zero,
                      end: const Offset(-1.0, 0.0),
                    )
                        .chain(CurveTween(curve: spring))
                        .animate(secondaryAnimation),
                    child: child),
              ),
            ),
          ),
        ],
      );
    },
    pageBuilder: (context, animation1, animation2) => child,
  );
}

Widget blurDialogTransitionBuilder(
    context, animation, secondaryAnimation, child) {
  return AnimatedBuilder(
    animation: animation,
    builder: (context, child) => BackdropFilter(
      filter: ImageFilter.blur(
          sigmaX: animation.value * 10, sigmaY: animation.value * 10),
      child: child,
    ),
    child: ScaleTransition(
      scale: CurvedAnimation(
        parent: animation,
        curve: Sprung(),
        reverseCurve: Sprung.overDamped.flipped,
      ),
      child: FadeTransition(
        opacity: CurvedAnimation(
          parent: animation,
          curve: Sprung(),
          reverseCurve: Sprung.overDamped.flipped,
        ),
        child: child,
      ),
    ),
  );
}

Route<T> blurDialogTransitionRouteBuilder<T>(
    BuildContext context, Widget child, CustomPage<T> page) {
  return PageRouteBuilder(
    fullscreenDialog: true,
    barrierColor: Colors.black54,
    transitionsBuilder: blurDialogTransitionBuilder,
    opaque: false,
    pageBuilder: (_, __, ___) => child,
    settings: page,
  );
}
