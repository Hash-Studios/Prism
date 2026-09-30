import 'dart:async';
import 'dart:math' as math;

import 'package:Prism/analytics/analytics_service.dart';
import 'package:Prism/core/analytics/events/events.dart';
import 'package:Prism/core/di/injection.dart';
import 'package:Prism/core/persistence/data_sources/settings_local_data_source.dart';
import 'package:Prism/core/purchases/paywall_orchestrator.dart';
import 'package:Prism/core/router/app_router.dart';
import 'package:Prism/core/state/app_state.dart' as app_state;
import 'package:Prism/core/state/auth_runtime.dart';
import 'package:Prism/core/widgets/prism/prism_ui.dart';
import 'package:Prism/data/share/create_dynamic_link.dart';
import 'package:Prism/features/onboarding_v2/src/common/onboarding_v2_keys.dart';
import 'package:Prism/main.dart' as main;
import 'package:Prism/theme/toasts.dart' as toasts;
import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';

/// The end drawer of the signed-in user's own profile: Pro status, their content, account links and log out.
class ProfileDrawer extends StatelessWidget {
  const ProfileDrawer({super.key});

  void _trackDrawerAction(AnalyticsActionValue action, {required String sourceContext}) {
    unawaited(
      analytics.track(
        SurfaceActionTappedEvent(
          surface: AnalyticsSurfaceValue.profileDrawer,
          action: action,
          sourceContext: sourceContext,
          itemType: ItemTypeValue.user,
          itemId: app_state.prismUser.id,
        ),
      ),
    );
  }

  /// Closes the drawer, then opens [route].
  void _go(BuildContext context, PageRouteInfo route) {
    final StackRouter router = context.router;
    Navigator.pop(context);
    unawaited(router.push(route));
  }

  Future<void> _logOut(BuildContext context) async {
    _trackDrawerAction(AnalyticsActionValue.drawerLogoutTapped, sourceContext: 'profile_drawer_logout');
    final bool confirmed = await showPrismConfirm(
      context,
      title: 'Log out of Prism?',
      message: 'You can sign back in any time.',
      confirmLabel: 'Log out',
    );
    if (!confirmed || !context.mounted) return;
    // Finish signing out before the restart, or the restarted app still sees the old
    // session and stays on the splash screen. The restart closes this drawer.
    if (!await globalGoogleAuth.signOutGoogle()) {
      toasts.error('Could not log out. Please try again.');
      return;
    }
    toasts.success('Logged out');
    await resetOnboardingLocalState(getIt<SettingsLocalDataSource>());
    if (context.mounted) {
      main.RestartWidget.restartApp(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    final ColorScheme cs = Theme.of(context).colorScheme;
    final bool premium = app_state.prismUser.premium;
    return Drawer(
      backgroundColor: cs.surface,
      width: math.min(340, MediaQuery.sizeOf(context).width * 0.84),
      child: ListView(
        padding: EdgeInsets.fromLTRB(
          PrismSpace.page,
          MediaQuery.paddingOf(context).top + PrismSpace.md,
          PrismSpace.page,
          MediaQuery.paddingOf(context).bottom + PrismSpace.xl,
        ),
        children: <Widget>[
          PrismCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Row(
                  children: <Widget>[
                    Icon(Icons.workspace_premium_rounded, size: 22, color: cs.primary),
                    const SizedBox(width: PrismSpace.xs),
                    Text('Prism Pro', style: PrismTextStyles.cardTitle(context)),
                  ],
                ),
                const SizedBox(height: PrismSpace.xxs),
                Text(
                  premium
                      ? 'You have every premium wallpaper, free downloads and free filters.'
                      : 'Unlock premium wallpapers, free downloads and free filters.',
                  style: PrismTextStyles.body(context),
                ),
                if (!premium) ...<Widget>[
                  const SizedBox(height: PrismSpace.md),
                  PrismButton(
                    label: 'Get Pro',
                    size: PrismButtonSize.compact,
                    onPressed: () {
                      Navigator.pop(context);
                      unawaited(
                        PaywallOrchestrator.instance.presentOrRequireSignIn(
                          context,
                          placement: PaywallPlacement.mainUpsell,
                          source: 'profile_drawer',
                        ),
                      );
                    },
                  ),
                ],
              ],
            ),
          ),
          const PrismSectionHeader(title: 'Your content', small: true),
          PrismGroup(
            children: <Widget>[
              PrismRow(
                icon: Icons.favorite_border_rounded,
                title: 'Favourites',
                onTap: () {
                  _trackDrawerAction(
                    AnalyticsActionValue.drawerFavWallsTapped,
                    sourceContext: 'profile_drawer_fav_walls',
                  );
                  _go(context, const FavouriteWallpaperRoute());
                },
              ),
              PrismRow(
                icon: Icons.download_rounded,
                title: 'Downloads',
                onTap: () {
                  _trackDrawerAction(
                    AnalyticsActionValue.drawerDownloadsTapped,
                    sourceContext: 'profile_drawer_downloads',
                  );
                  _go(context, const DownloadRoute());
                },
              ),
            ],
          ),
          const PrismSectionHeader(title: 'Account', small: true),
          PrismGroup(
            children: <Widget>[
              PrismRow(
                icon: Icons.ios_share_rounded,
                title: 'Share profile',
                onTap: () {
                  _trackDrawerAction(
                    AnalyticsActionValue.drawerSharePrismTapped,
                    sourceContext: 'profile_drawer_share_profile',
                  );
                  unawaited(
                    createUserDynamicLink(
                      app_state.prismUser.name,
                      app_state.prismUser.username,
                      app_state.prismUser.email,
                      app_state.prismUser.bio,
                      app_state.prismUser.profilePhoto,
                      context: context,
                    ),
                  );
                },
              ),
              PrismRow(
                icon: Icons.settings_outlined,
                title: 'Settings',
                onTap: () {
                  _trackDrawerAction(
                    AnalyticsActionValue.notificationSettingsOpened,
                    sourceContext: 'profile_drawer_settings',
                  );
                  _go(context, const SettingsRoute());
                },
              ),
              PrismRow(
                icon: Icons.info_outline_rounded,
                title: 'About',
                onTap: () {
                  _trackDrawerAction(AnalyticsActionValue.actionChipTapped, sourceContext: 'profile_drawer_about');
                  _go(context, const AboutRoute());
                },
              ),
            ],
          ),
          const SizedBox(height: PrismSpace.md),
          PrismGroup(
            children: <Widget>[
              PrismRow(
                icon: Icons.logout_rounded,
                title: 'Log out',
                showChevron: false,
                onTap: () => unawaited(_logOut(context)),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
