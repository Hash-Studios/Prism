import 'dart:async';

import 'package:Prism/analytics/analytics_service.dart';
import 'package:Prism/core/analytics/events/events.dart';
import 'package:Prism/core/haptics/prism_haptics.dart';
import 'package:Prism/core/router/deep_link_dispatcher.dart';
import 'package:Prism/core/router/notification_route_mapper.dart';
import 'package:Prism/core/utils/url_launcher_compat.dart';
import 'package:Prism/core/widgets/prism/prism_ui.dart';
import 'package:Prism/features/in_app_notifications/domain/entities/in_app_notification_entity.dart';
import 'package:Prism/features/in_app_notifications/domain/notification_copy.dart';
import 'package:Prism/features/in_app_notifications/domain/notification_grouping.dart';
import 'package:Prism/features/in_app_notifications/views/widgets/notification_visuals.dart';
import 'package:Prism/l10n/l10n.dart';
import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';

/// Left inset of the text column: page margin, icon tile and gap. Grouped children line up with it.
const double notificationTextInset = PrismSpace.page + 40 + PrismSpace.sm;

NotificationTypeValue notificationTypeFor(InAppNotificationEntity notification) {
  if (notification.url.trim().isNotEmpty) {
    return NotificationTypeValue.externalUrl;
  }
  if (notification.pageName.trim().isNotEmpty || (notification.route?.trim().isNotEmpty ?? false)) {
    return NotificationTypeValue.route;
  }
  return NotificationTypeValue.unknown;
}

String _destinationFor(InAppNotificationEntity notification) {
  if (notification.url.trim().isNotEmpty) {
    return notification.url;
  }
  final route = (notification.route ?? notification.pageName).trim();
  if (route.isNotEmpty) {
    return route;
  }
  return '';
}

/// One notification. A full row has a type icon, title, time, body and an optional image. A [compactInGroup] row
/// sits under an expanded group and shows one line and the time.
class NotificationRow extends StatelessWidget {
  const NotificationRow({
    super.key,
    required this.notification,
    this.onMarkRead,
    this.compactInGroup = false,
    this.compactBodyOverride,
  });

  final InAppNotificationEntity notification;
  final VoidCallback? onMarkRead;
  final bool compactInGroup;

  /// With [compactInGroup], replaces the body line (for example a follower name only).
  final String? compactBodyOverride;
  static const NotificationRouteMapper _routeMapper = NotificationRouteMapper();

  static bool _hasValidImageUrl(String? url) => Uri.tryParse(url?.trim() ?? '')?.host.isNotEmpty ?? false;

  Future<void> _onTap(BuildContext context) async {
    PrismHaptics.tap();
    onMarkRead?.call();
    analytics.track(
      NotificationItemOpenedEvent(
        type: notificationTypeFor(notification),
        destination: _destinationFor(notification),
        hasExternalUrl: notification.url.trim().isNotEmpty,
      ),
    );
    if (notification.url.trim().isNotEmpty) {
      await openPrismLink(context, notification.url);
      return;
    }
    final String route = (notification.route ?? notification.pageName).trim();
    await DeepLinkDispatcher.maybeOf(context.router)?.openActionLoader(
      () => _routeMapper.actionFromRoute(
        route: route,
        wallId: notification.wallId,
        profileIdentifier: notification.followerUid,
        sourceTag: 'notification.route_mapper',
        fallbackToInbox: false,
      ),
      rawUri: route,
      source: DeepLinkSourceValue.inApp,
      targetType: NotificationRouteMapper.targetTypeForRoute(route),
      hasPayload: route.isNotEmpty,
    );
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    final Locale locale = Localizations.localeOf(context);
    final localized = localizedNotificationCopy(notification, l10n);
    final String timeStr = notificationTimeLabel(
      notification.createdAt,
      l10n: l10n,
      locale: locale,
      includeDate: compactInGroup,
    );
    final String title = cleanNotificationTitle(localized.title);
    final String body = localized.body;
    final String semanticLine = compactInGroup ? (body.trim().isNotEmpty ? body.trim() : title) : '$title. $body';
    return Semantics(
      button: true,
      label: l10n.notifSemanticsRow(semanticLine, timeStr, notification.read ? l10n.notifRead : l10n.notifUnread),
      child: Material(
        type: MaterialType.transparency,
        child: InkWell(
          onTap: () => _onTap(context),
          child: ExcludeSemantics(child: compactInGroup ? _compact(context, timeStr) : _full(context, timeStr, title)),
        ),
      ),
    );
  }

  Widget _compact(BuildContext context, String timeStr) {
    final String trimmedOverride = compactBodyOverride?.trim() ?? '';
    final String displayBody = trimmedOverride.isNotEmpty
        ? trimmedOverride
        : (localizedNotificationCopy(notification, context.l10n).body.trim().isEmpty
              ? notification.title.trim()
              : localizedNotificationCopy(notification, context.l10n).body.trim());
    return Padding(
      padding: const EdgeInsets.fromLTRB(notificationTextInset, PrismSpace.xs, PrismSpace.page, PrismSpace.xs),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Expanded(
            child: Text(
              glueTrailingEmoji(displayBody),
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              style: PrismTextStyles.body(context),
            ),
          ),
          const SizedBox(width: PrismSpace.sm),
          Flexible(
            child: Text(timeStr, textAlign: TextAlign.end, style: PrismTextStyles.caption(context)),
          ),
          if (!notification.read) ...<Widget>[
            const SizedBox(width: PrismSpace.xs),
            const Padding(padding: EdgeInsets.only(top: 5), child: UnreadDot()),
          ],
        ],
      ),
    );
  }

  Widget _full(BuildContext context, String timeStr, String title) {
    final bool showImage = _hasValidImageUrl(notification.imageUrl);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: PrismSpace.page, vertical: PrismSpace.xs),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          NotificationIconTile(
            title: localizedNotificationCopy(notification, context.l10n).title,
            body: localizedNotificationCopy(notification, context.l10n).body,
            unread: !notification.read,
          ),
          const SizedBox(width: PrismSpace.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                NotificationTitleLine(title: title, time: timeStr, unread: !notification.read),
                if (localizedNotificationCopy(notification, context.l10n).body.trim().isNotEmpty) ...<Widget>[
                  const SizedBox(height: 2),
                  Text(
                    glueTrailingEmoji(localizedNotificationCopy(notification, context.l10n).body),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: PrismTextStyles.body(context),
                  ),
                ],
              ],
            ),
          ),
          if (showImage) ...<Widget>[
            const SizedBox(width: PrismSpace.sm),
            NotificationThumbs(urls: <String>[notification.imageUrl]),
          ],
        ],
      ),
    );
  }
}

/// The title of a notification with its time, and a reserved end slot, on one line.
class NotificationTitleLine extends StatelessWidget {
  const NotificationTitleLine({
    super.key,
    required this.title,
    required this.time,
    required this.unread,
    this.trailing,
  });

  final String title;
  final String time;
  final bool unread;

  /// Shown after the time, for example an expand chevron.
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Expanded(
          child: Text(
            title,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: PrismTextStyles.rowTitle(context).copyWith(fontWeight: unread ? FontWeight.w700 : FontWeight.w500),
          ),
        ),
        const SizedBox(width: PrismSpace.xs),
        Padding(
          padding: const EdgeInsets.only(top: 2),
          child: Text(time, style: PrismTextStyles.caption(context)),
        ),
        // A fixed end column keeps the time at the same place in every row. Only a group fills it, with its chevron.
        SizedBox(width: 24, child: trailing),
      ],
    );
  }
}
