import 'package:Prism/analytics/analytics_service.dart';
import 'package:Prism/core/analytics/events/events.dart';
import 'package:Prism/core/haptics/prism_haptics.dart';
import 'package:Prism/core/router/app_router.dart';
import 'package:Prism/core/state/app_state.dart' as app_state;
import 'package:Prism/core/utils/side_safe_column.dart';
import 'package:Prism/core/widgets/prism/prism_ui.dart';
import 'package:Prism/features/in_app_notifications/biz/bloc/in_app_notifications_bloc.j.dart';
import 'package:Prism/l10n/l10n.dart';
import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

void _openNotifications(BuildContext context, NotificationsEntrySourceValue source) {
  PrismHaptics.tap();
  analytics.track(NotificationsOpenedEvent(source: source));
  context.router.push(const NotificationRoute());
}

void _openProfile(BuildContext context) {
  PrismHaptics.tap();
  context.router.push(ProfileRoute(profileIdentifier: app_state.prismUser.id));
}

bool _hasUnread(BuildContext context) =>
    context.select<InAppNotificationsBloc, bool>((bloc) => bloc.state.unreadCount > 0);

/// The notifications button with its unread dot. [source] says which bar holds it.
class NotificationBell extends StatelessWidget {
  const NotificationBell({super.key, required this.source});

  final NotificationsEntrySourceValue source;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme cs = theme.colorScheme;
    final bool floating = source == NotificationsEntrySourceValue.bottom;
    final bool hasUnread = _hasUnread(context);
    void open() => _openNotifications(context, source);

    final Widget bell = Stack(
      alignment: Alignment.center,
      children: <Widget>[
        PrismIconButton(
          icon: Icons.notifications_none_rounded,
          tooltip: context.l10n.notifTitle,
          onPressed: open,
          color: floating ? cs.secondary : null,
        ),
        if (hasUnread)
          if (floating)
            PositionedDirectional(
              top: 10,
              end: 11,
              child: IgnorePointer(
                child: _UnreadDot(color: cs.primary, border: theme.primaryColor),
              ),
            )
          else
            Positioned(
              top: 10,
              right: 11,
              child: IgnorePointer(
                child: _UnreadDot(color: cs.primary, border: cs.surface),
              ),
            ),
      ],
    );
    return Semantics(
      label: context.l10n.wallpaperOpenNotifications,
      button: true,
      hint: hasUnread ? context.l10n.wallpaperUnreadItems : null,
      excludeSemantics: true,
      onTap: open,
      child: floating ? SizedBox.square(dimension: 44, child: _FloatingDisc(child: bell)) : bell,
    );
  }
}

/// The user's avatar. It opens their profile. [floating] draws it on a disc like the bottom bar pill.
class ProfileAvatarButton extends StatelessWidget {
  const ProfileAvatarButton({super.key, this.floating = false});

  final bool floating;

  @override
  Widget build(BuildContext context) {
    void open() => _openProfile(context);
    final Widget avatar = _AvatarTarget(onTap: open);

    return Semantics(
      button: true,
      label: context.l10n.wallpaperYourProfile,
      excludeSemantics: true,
      onTap: open,
      child: floating ? _FloatingDisc(child: avatar) : avatar,
    );
  }
}

/// The avatar for a bottom bar too narrow for a separate bell. It carries the unread dot and opens a sheet with the
/// profile and the notifications.
class AccountButton extends StatelessWidget {
  const AccountButton({super.key});

  Future<void> _openSheet(BuildContext context) {
    PrismHaptics.tap();
    final InAppNotificationsBloc bloc = context.read<InAppNotificationsBloc>();
    return showPrismSheet<void>(
      context,
      detents: const <PrismSheetDetent>[PrismSheetDetent.fit],
      builder: (sheetContext) => BlocProvider<InAppNotificationsBloc>.value(
        value: bloc,
        child: _AccountSheet(
          onProfile: () {
            Navigator.of(sheetContext).pop();
            _openProfile(context);
          },
          onNotifications: () {
            Navigator.of(sheetContext).pop();
            _openNotifications(context, NotificationsEntrySourceValue.bottom);
          },
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final bool hasUnread = _hasUnread(context);
    void open() => _openSheet(context);

    return Semantics(
      button: true,
      label: context.l10n.navAccount,
      hint: hasUnread ? context.l10n.wallpaperUnreadItems : null,
      excludeSemantics: true,
      onTap: open,
      child: Tooltip(
        message: context.l10n.navAccount,
        excludeFromSemantics: true,
        child: _FloatingDisc(
          child: Stack(
            alignment: Alignment.center,
            children: <Widget>[
              _AvatarTarget(onTap: open),
              if (hasUnread)
                PositionedDirectional(
                  top: 5,
                  end: 5,
                  child: IgnorePointer(
                    child: _UnreadDot(color: theme.colorScheme.primary, border: theme.primaryColor),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AccountSheet extends StatelessWidget {
  const _AccountSheet({required this.onProfile, required this.onNotifications});

  final VoidCallback onProfile;
  final VoidCallback onNotifications;

  @override
  Widget build(BuildContext context) {
    final ColorScheme cs = Theme.of(context).colorScheme;
    final int unread = context.select<InAppNotificationsBloc, int>((bloc) => bloc.state.unreadCount);
    return PrismSheetBody(
      title: context.l10n.navAccount,
      child: PrismGroup(
        children: <Widget>[
          PrismRow(
            leading: PrismAvatar(url: app_state.prismUser.profilePhoto, name: app_state.prismUser.name, size: 28),
            title: context.l10n.wallpaperYourProfile,
            onTap: onProfile,
          ),
          PrismRow(
            icon: Icons.notifications_none_rounded,
            title: context.l10n.notifTitle,
            subtitle: unread > 0 ? context.l10n.navUnreadCount(unread) : null,
            trailing: unread > 0 ? _UnreadDot(color: cs.primary, border: cs.surface) : null,
            onTap: onNotifications,
          ),
        ],
      ),
    );
  }
}

class _AvatarTarget extends StatelessWidget {
  const _AvatarTarget({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return PressScale(
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: SizedBox.square(
          dimension: 44,
          child: Center(
            child: PrismAvatar(url: app_state.prismUser.profilePhoto, name: app_state.prismUser.name, size: 32),
          ),
        ),
      ),
    );
  }
}

/// The bottom bar pill's colour. In the side rail it also takes the pill's shadow, so it reads over any wallpaper. The
/// docked bottom band is flat.
class _FloatingDisc extends StatelessWidget {
  const _FloatingDisc({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Theme.of(context).primaryColor,
        shape: BoxShape.circle,
        boxShadow: sideSafeColumnWidth(context) > 0
            ? <BoxShadow>[
                BoxShadow(color: Colors.black.withValues(alpha: 0.25), blurRadius: 4, offset: const Offset(0, 4)),
              ]
            : null,
      ),
      child: child,
    );
  }
}

class _UnreadDot extends StatelessWidget {
  const _UnreadDot({required this.color, required this.border});

  final Color color;
  final Color border;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 10,
      height: 10,
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
        border: Border.all(color: border, width: 2),
      ),
    );
  }
}
