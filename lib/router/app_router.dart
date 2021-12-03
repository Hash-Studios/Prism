import 'package:auto_route/annotations.dart';
import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:prism/pages/home_page.dart';
import 'package:prism/router/transition_route_builders.dart';

part 'app_router.gr.dart';

@AdaptiveAutoRouter(
  replaceInRouteName: 'Page,Route',
  routes: <AutoRoute>[
    RedirectRoute(path: '/home-page', redirectTo: '/'),
    // CustomRoute(
    //   page: LoadingPage,
    //   initial: true,
    //   customRouteBuilder: slideTransitionRouteBuilder,
    // ),
    CustomRoute(
      initial: true,
      page: HomePage,
      customRouteBuilder: slideTransitionRouteBuilder,
      // children: [
      //   CustomRoute(
      //     page: CollectionsPage,
      //     customRouteBuilder: slideTransitionRouteBuilder,
      //     initial: true,
      //   ),
      //   CustomRoute(
      //     page: FavouritePage,
      //     customRouteBuilder: slideTransitionRouteBuilder,
      //   ),
      //   CustomRoute(
      //     page: ProfilePage,
      //     customRouteBuilder: slideTransitionRouteBuilder,
      //   ),
      // ],
    ),
  ],
)
class AppRouter extends _$AppRouter {}
