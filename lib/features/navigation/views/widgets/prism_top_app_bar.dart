import 'package:Prism/core/router/app_router.dart';
import 'package:Prism/core/state/app_state.dart' as app_state;
import 'package:Prism/core/widgets/animated/press_scale.dart';
import 'package:Prism/core/widgets/prism/prism_bits.dart';
import 'package:Prism/core/widgets/prism/prism_button.dart';
import 'package:Prism/features/in_app_notifications/biz/bloc/in_app_notifications_bloc.j.dart';
import 'package:Prism/global/svg_assets.dart';
import 'package:Prism/theme/app_tokens.dart';
import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_svg/flutter_svg.dart';

/// The Home tab's top bar: notifications, the prism wordmark (opens Tune your feed), and the profile.
class PrismTopAppBar extends StatelessWidget implements PreferredSizeWidget {
  const PrismTopAppBar({super.key, required this.onLogoTap});

  final VoidCallback onLogoTap;

  @override
  Size get preferredSize => const Size.fromHeight(PrismAppBarSizes.height);

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: Theme.of(context).colorScheme.surface,
      child: SafeArea(
        bottom: false,
        child: SizedBox(
          height: PrismAppBarSizes.height,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: PrismSpace.xs),
            child: Row(
              children: <Widget>[
                BlocBuilder<InAppNotificationsBloc, InAppNotificationsState>(
                  builder: (BuildContext context, InAppNotificationsState state) =>
                      _NotificationButton(hasUnread: state.unreadCount > 0),
                ),
                Expanded(
                  child: Center(child: _Wordmark(onTap: onLogoTap)),
                ),
                const _ProfileAvatar(),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Wordmark extends StatelessWidget {
  const _Wordmark({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final Color ink = Theme.of(context).colorScheme.onSurface;
    return Semantics(
      button: true,
      label: 'Feed settings',
      excludeSemantics: true,
      onTap: onTap,
      child: PressScale(
        scale: 0.97,
        child: GestureDetector(
          onTap: onTap,
          behavior: HitTestBehavior.opaque,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 44),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: PrismSpace.xs),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  SvgPicture.string(
                    prismVector,
                    width: 11,
                    height: 13,
                    colorFilter: ColorFilter.mode(ink, BlendMode.srcIn),
                  ),
                  const SizedBox(width: 6),
                  Text('prism', style: PrismTextStyles.brandName.copyWith(fontSize: 18, color: ink)),
                  const SizedBox(width: 2),
                  Icon(PrismIcons.dropdownCaret, color: ink.withValues(alpha: 0.6), size: 18),
                ],
              ),
            ),
          ),
        ),
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
    void open() => context.router.push(const NotificationRoute());
    return Semantics(
      label: 'Open notifications',
      button: true,
      hint: hasUnread ? 'Has unread items' : null,
      excludeSemantics: true,
      onTap: open,
      child: Stack(
        alignment: Alignment.center,
        children: <Widget>[
          PrismIconButton(icon: Icons.notifications_none_rounded, tooltip: 'Notifications', onPressed: open),
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
    void openProfile() => context.router.push(ProfileRoute(profileIdentifier: app_state.prismUser.email));
    return Semantics(
      button: true,
      label: 'Your profile',
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
