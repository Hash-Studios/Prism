import 'package:Prism/core/router/app_router.dart';
import 'package:Prism/core/state/app_state.dart' as app_state;
import 'package:Prism/features/in_app_notifications/biz/bloc/in_app_notifications_bloc.j.dart';
import 'package:Prism/global/svgAssets.dart';
import 'package:Prism/theme/jam_icons_icons.dart';
import 'package:auto_route/auto_route.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_svg/flutter_svg.dart';

/// Same chrome as the personalized feed tab: notifications, logo + menu affordance, profile.
class PrismTopAppBar extends StatelessWidget implements PreferredSizeWidget {
  const PrismTopAppBar({super.key, required this.onLogoTap});

  final VoidCallback onLogoTap;

  @override
  Size get preferredSize => const Size.fromHeight(56);

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: Theme.of(context).primaryColor,
      child: SafeArea(
        bottom: false,
        child: SizedBox(
          height: 56,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 18),
            child: Row(
              children: <Widget>[
                BlocBuilder<InAppNotificationsBloc, InAppNotificationsState>(
                  builder: (BuildContext context, InAppNotificationsState state) =>
                      _NotificationButton(hasUnread: state.unreadCount > 0),
                ),
                Expanded(
                  child: Center(
                    child: GestureDetector(
                      onTap: onLogoTap,
                      behavior: HitTestBehavior.opaque,
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: <Widget>[
                          _PrismLogo(),
                          SizedBox(width: 4),
                          Text(
                            'prism',
                            style: TextStyle(
                              fontFamily: 'Fraunces',
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                              color: Colors.white,
                              fontVariations: <FontVariation>[FontVariation('WONK', 1)],
                            ),
                          ),
                          SizedBox(width: 2),
                          Icon(Icons.expand_more_rounded, color: Colors.white, size: 16),
                        ],
                      ),
                    ),
                  ),
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

class _PrismLogo extends StatelessWidget {
  const _PrismLogo();

  @override
  Widget build(BuildContext context) {
    return SvgPicture.string(
      prismVector,
      width: 10,
      height: 12,
      colorFilter: const ColorFilter.mode(Colors.white, BlendMode.srcIn),
    );
  }
}

class _NotificationButton extends StatelessWidget {
  const _NotificationButton({this.hasUnread = false});

  final bool hasUnread;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Open notifications',
      button: true,
      hint: hasUnread ? 'Has unread items' : null,
      child: Material(
        type: MaterialType.transparency,
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: () => context.router.push(const NotificationRoute()),
          child: SizedBox(
            width: 44,
            height: 44,
            child: Stack(
              alignment: Alignment.center,
              children: [
                Positioned(
                  left: 14,
                  top: 14,
                  child: Icon(
                    JamIcons.bell_f,
                    size: 16,
                    color: Theme.of(context).colorScheme.secondary.withValues(alpha: 0.75),
                  ),
                ),
                if (hasUnread)
                  Positioned(
                    top: 13,
                    left: 24,
                    child: Container(
                      width: 6,
                      height: 6,
                      decoration: const BoxDecoration(
                        shape: BoxShape.circle,
                        color: Color(0xFFFF69A9),
                        boxShadow: [BoxShadow(color: Color(0x80E57697), blurRadius: 4, spreadRadius: 1)],
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ProfileAvatar extends StatelessWidget {
  const _ProfileAvatar();

  @override
  Widget build(BuildContext context) {
    final String photoUrl = app_state.prismUser.profilePhoto;
    return GestureDetector(
      onTap: () => context.router.push(ProfileRoute(profileIdentifier: app_state.prismUser.email)),
      child: Container(
        width: 40,
        height: 40,
        padding: const EdgeInsets.all(8),
        child: ClipOval(
          child: CachedNetworkImage(imageUrl: photoUrl, fit: BoxFit.cover),
        ),
      ),
    );
  }
}
