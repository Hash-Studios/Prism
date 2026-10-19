import 'package:Prism/core/haptics/prism_haptics.dart';
import 'package:Prism/core/router/app_router.dart';
import 'package:Prism/core/state/app_state.dart' as app_state;
import 'package:Prism/core/widgets/animated/press_scale.dart';
import 'package:Prism/core/widgets/prism/prism_bits.dart';
import 'package:Prism/core/widgets/prism/prism_button.dart';
import 'package:Prism/features/in_app_notifications/biz/bloc/in_app_notifications_bloc.j.dart';
import 'package:Prism/global/svg_assets.dart';
import 'package:Prism/l10n/l10n.dart';
import 'package:Prism/theme/app_tokens.dart';
import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_svg/flutter_svg.dart';

/// The Home tab's top bar, in the style of X: the profile on the left, the prism wordmark in the centre and the
/// notifications on the right. The feed screen puts it in the floating header.
class PrismTopAppBar extends StatelessWidget {
  const PrismTopAppBar({super.key});

  static const double height = 52;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: height,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: PrismSpace.xs),
        child: Stack(
          alignment: Alignment.center,
          children: <Widget>[
            const Align(alignment: AlignmentDirectional.centerStart, child: _ProfileAvatar()),
            const _Wordmark(),
            Align(
              alignment: AlignmentDirectional.centerEnd,
              child: BlocBuilder<InAppNotificationsBloc, InAppNotificationsState>(
                builder: (BuildContext context, InAppNotificationsState state) =>
                    _NotificationButton(hasUnread: state.unreadCount > 0),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Wordmark extends StatelessWidget {
  const _Wordmark();

  @override
  Widget build(BuildContext context) {
    final Color ink = Theme.of(context).colorScheme.onSurface;
    return Semantics(
      header: true,
      label: context.l10n.wallpaperHomeAppName,
      excludeSemantics: true,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          SvgPicture.string(prismVector, width: 11, height: 13, colorFilter: ColorFilter.mode(ink, BlendMode.srcIn)),
          const SizedBox(width: 6),
          Text(
            context.l10n.appTitle.toLowerCase(),
            style: PrismTextStyles.brandName.copyWith(fontSize: 18, color: ink),
          ),
        ],
      ),
    );
  }
}

class _NotificationButton extends StatelessWidget {
  const _NotificationButton({this.hasUnread = false});

  final bool hasUnread;

  @override
  Widget build(BuildContext context) {
    final ColorScheme cs = Theme.of(context).colorScheme;
    void open() {
      PrismHaptics.tap();
      context.router.push(const NotificationRoute());
    }

    return Semantics(
      label: context.l10n.wallpaperOpenNotifications,
      button: true,
      hint: hasUnread ? context.l10n.wallpaperUnreadItems : null,
      excludeSemantics: true,
      onTap: open,
      child: Stack(
        alignment: Alignment.center,
        children: <Widget>[
          PrismIconButton(icon: Icons.notifications_none_rounded, tooltip: context.l10n.notifTitle, onPressed: open),
          if (hasUnread)
            Positioned(
              top: 10,
              right: 11,
              child: IgnorePointer(
                child: Container(
                  width: 10,
                  height: 10,
                  decoration: BoxDecoration(
                    color: cs.primary,
                    shape: BoxShape.circle,
                    border: Border.all(color: cs.surface, width: 2),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _ProfileAvatar extends StatelessWidget {
  const _ProfileAvatar();

  @override
  Widget build(BuildContext context) {
    void openProfile() {
      PrismHaptics.tap();
      context.router.push(ProfileRoute(profileIdentifier: app_state.prismUser.email));
    }

    return Semantics(
      button: true,
      label: context.l10n.wallpaperYourProfile,
      excludeSemantics: true,
      onTap: openProfile,
      child: PressScale(
        child: GestureDetector(
          onTap: openProfile,
          behavior: HitTestBehavior.opaque,
          child: SizedBox.square(
            dimension: 44,
            child: Center(
              child: PrismAvatar(url: app_state.prismUser.profilePhoto, name: app_state.prismUser.name, size: 32),
            ),
          ),
        ),
      ),
    );
  }
}
