import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:prism/pages/home_page.dart';
import 'package:prism/pages/loading_page.dart';
import 'package:prism/pages/notifications_page.dart';
import 'package:prism/pages/profile_page.dart';
import 'package:prism/pages/setups_page.dart';
import 'package:prism/pages/walls_page.dart';
import 'package:prism/router/transition_route_builders.dart';

part 'app_router.gr.dart';

@AdaptiveAutoRouter(
  replaceInRouteName: 'Page,Route',
  routes: <AutoRoute>[
    RedirectRoute(path: '/home-page', redirectTo: '/'),
    CustomRoute(
      page: LoadingPage,
      initial: true,
      customRouteBuilder: slideTransitionRouteBuilder,
    ),
    CustomRoute(
      page: HomePage,
      customRouteBuilder: slideTransitionRouteBuilder,
      children: [
        MaterialRoute(
          page: WallsPage,
          initial: true,
        ),
        MaterialRoute(
          page: SetupsPage,
        ),
        MaterialRoute(
          page: NotificationsPage,
        ),
        MaterialRoute(
          page: ProfilePage,
        ),
      ],
    ),
  ],
)
class AppRouter extends _$AppRouter {}
