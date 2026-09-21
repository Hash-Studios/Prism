import 'dart:async';
import 'dart:math' as math;

import 'package:Prism/analytics/analytics_service.dart';
import 'package:Prism/core/analytics/events/events.dart';
import 'package:Prism/core/di/injection.dart';
import 'package:Prism/core/persistence/data_sources/settings_local_data_source.dart';
import 'package:Prism/core/router/app_router.dart';
import 'package:Prism/core/state/app_state.dart' as app_state;
import 'package:Prism/core/widgets/popup/enter_code_panel.dart';
import 'package:Prism/data/share/create_dynamic_link.dart';
import 'package:Prism/main.dart' as main;
import 'package:Prism/theme/jam_icons_icons.dart';
import 'package:Prism/theme/toasts.dart' as toasts;
import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';

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

  // ── Builder helpers ──────────────────────────────────────────────────────

  Widget _header(BuildContext context) {
    return SizedBox(
      // DrawerHeader pads for the status bar itself; Dynamic Island insets left too little room at 130.
      height: math.max(130, MediaQuery.paddingOf(context).top + 80),
      child: DrawerHeader(
        margin: EdgeInsets.zero,
        padding: EdgeInsets.zero,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 20, 16, 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                app_state.prismUser.premium == true ? 'Prism Pro' : 'Prism',
                style: Theme.of(
                  context,
                ).textTheme.displaySmall!.copyWith(color: Theme.of(context).colorScheme.secondary),
              ),
              const SizedBox(height: 2),
              Text(
                app_state.prismUser.premium == true
                    ? 'Exclusive premium walls & setups!'
                    : 'Exclusive wallpapers & setups!',
                style: Theme.of(
                  context,
                ).textTheme.bodyMedium!.copyWith(color: Theme.of(context).colorScheme.secondary.withValues(alpha: 0.7)),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _sectionHeader(String text, BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 0, 0),
      child: Text(
        text,
        style: Theme.of(context).textTheme.displaySmall!.copyWith(
          fontSize: 11,
          letterSpacing: 0.8,
          color: Theme.of(context).colorScheme.secondary.withValues(alpha: 0.4),
        ),
      ),
    );
  }

  Widget _item({
    required IconData icon,
    required String text,
    required BuildContext context,
    GestureTapCallback? onTap,
  }) {
    return ListTile(
      dense: true,
      visualDensity: VisualDensity.adaptivePlatformDensity,
      leading: Icon(icon, color: Theme.of(context).colorScheme.secondary),
      trailing: Icon(JamIcons.chevron_right, color: Theme.of(context).colorScheme.secondary),
      title: Text(
        text,
        style: Theme.of(
          context,
        ).textTheme.bodySmall!.copyWith(fontFamily: 'Proxima Nova', color: Theme.of(context).colorScheme.secondary),
      ),
      onTap: onTap,
    );
  }

  Widget _footer(BuildContext context) {
    final color = Theme.of(context).colorScheme.secondary.withValues(alpha: 0.6);
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 4, 8, 40),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          TextButton.icon(
            icon: Icon(JamIcons.cog, color: color, size: 18),
            label: Text('Settings', style: TextStyle(color: color, fontSize: 12)),
            onPressed: () {
              _trackDrawerAction(
                AnalyticsActionValue.notificationSettingsOpened,
                sourceContext: 'profile_drawer_settings',
              );
              Navigator.pop(context);
              context.router.push(const SettingsRoute());
            },
          ),
          TextButton.icon(
            icon: Icon(JamIcons.info, color: color, size: 18),
            label: Text('About', style: TextStyle(color: color, fontSize: 12)),
            onPressed: () {
              _trackDrawerAction(AnalyticsActionValue.actionChipTapped, sourceContext: 'profile_drawer_about');
              Navigator.pop(context);
              context.router.push(const AboutRoute());
            },
          ),
        ],
      ),
    );
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Drawer(
      child: ColoredBox(
        color: Theme.of(context).primaryColor,
        child: ListView(
          padding: EdgeInsets.zero,
          children: <Widget>[
            _header(context),

            // ── YOUR CONTENT ───────────────────────────────────────────────
            _sectionHeader('YOUR CONTENT', context),
            _item(
              icon: JamIcons.picture,
              text: 'Favourite Wallpapers',
              context: context,
              onTap: () {
                _trackDrawerAction(
                  AnalyticsActionValue.drawerFavWallsTapped,
                  sourceContext: 'profile_drawer_fav_walls',
                );
                Navigator.pop(context);
                context.router.push(const FavouriteWallpaperRoute());
              },
            ),
            _item(
              icon: JamIcons.instant_picture,
              text: 'Favourite Setups',
              context: context,
              onTap: () {
                _trackDrawerAction(
                  AnalyticsActionValue.drawerFavSetupsTapped,
                  sourceContext: 'profile_drawer_fav_setups',
                );
                Navigator.pop(context);
                context.router.push(const FavouriteSetupRoute());
              },
            ),
            _item(
              icon: JamIcons.download,
              text: 'Downloaded Walls',
              context: context,
              onTap: () {
                _trackDrawerAction(
                  AnalyticsActionValue.drawerDownloadsTapped,
                  sourceContext: 'profile_drawer_downloads',
                );
                Navigator.pop(context);
                context.router.push(const DownloadRoute());
              },
            ),

            const Divider(),

            // ── ACCOUNT ────────────────────────────────────────────────────
            _sectionHeader('ACCOUNT', context),
            _item(
              icon: JamIcons.share_alt,
              text: 'Share your Profile',
              context: context,
              onTap: () {
                _trackDrawerAction(
                  AnalyticsActionValue.drawerSharePrismTapped,
                  sourceContext: 'profile_drawer_share_profile',
                );
                createUserDynamicLink(
                  app_state.prismUser.name,
                  app_state.prismUser.username,
                  app_state.prismUser.email,
                  app_state.prismUser.bio,
                  app_state.prismUser.profilePhoto,
                  context: context,
                );
              },
            ),
            _item(
              icon: JamIcons.log_out,
              text: 'Log out',
              context: context,
              onTap: () async {
                _trackDrawerAction(AnalyticsActionValue.drawerLogoutTapped, sourceContext: 'profile_drawer_logout');
                Navigator.pop(context);
                app_state.gAuth.signOutGoogle();
                toasts.codeSend('Log out Successful!');
                final settingsLocal = getIt<SettingsLocalDataSource>();
                await settingsLocal.set('onboarded_v2_new', false);
                await settingsLocal.set('onboarding_v2_interests', '');
                await settingsLocal.set('onboarding_v2_followed_creators', '');
                if (context.mounted) {
                  main.RestartWidget.restartApp(context);
                }
              },
            ),

            const Divider(),

            // ── MORE ───────────────────────────────────────────────────────
            _sectionHeader('MORE', context),
            _item(
              icon: JamIcons.coin,
              text: 'Enter Code',
              context: context,
              onTap: () {
                _trackDrawerAction(
                  AnalyticsActionValue.drawerEnterCodeTapped,
                  sourceContext: 'profile_drawer_enter_code',
                );
                Navigator.pop(context);
                showModalBottomSheet(
                  isScrollControlled: true,
                  context: context,
                  builder: (_) => const EnterCodePanel(),
                );
              },
            ),
            const Divider(),

            _footer(context),
          ],
        ),
      ),
    );
  }
}
