import 'dart:async';

import 'package:Prism/analytics/analytics_service.dart';
import 'package:Prism/core/analytics/events/events.dart';
import 'package:Prism/core/di/injection.dart';
import 'package:Prism/core/haptics/prism_haptics.dart';
import 'package:Prism/core/router/app_router.dart';
import 'package:Prism/core/router/notification_route_mapper.dart';
import 'package:Prism/core/state/app_state.dart' as app_state;
import 'package:Prism/core/utils/status.dart';
import 'package:Prism/core/utils/url_launcher_compat.dart';
import 'package:Prism/core/widgets/glint/glint_state.dart';
import 'package:Prism/features/in_app_notifications/biz/bloc/in_app_notifications_bloc.j.dart';
import 'package:Prism/features/in_app_notifications/domain/entities/in_app_notification_entity.dart';
import 'package:Prism/features/in_app_notifications/domain/notification_grouping.dart';
import 'package:Prism/features/in_app_notifications/views/widgets/notification_settings_sheet.dart';
import 'package:Prism/theme/jam_icons_icons.dart';
import 'package:auto_route/auto_route.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// Shorter expanded-row text: names for followers/wall-live; day label for uniform WOTD bodies.
String? _compactLineForGroupedChild(InAppNotificationTitleGroup group, InAppNotificationEntity n) {
  switch (group.kind) {
    case NotificationKind.follower:
      final String? name = followerDisplayNameFromBody(n.body);
      if (name != null && name.isNotEmpty) {
        return name;
      }
      final String body = n.body.trim();
      if (body.isNotEmpty) {
        return body;
      }
      final String title = n.title.trim();
      return title.isEmpty ? null : title;
    case NotificationKind.wallLive || NotificationKind.wallApproved:
      final String? creator = wallLiveCreatorNameFromBody(n.body);
      return creator != null && creator.isNotEmpty ? creator : null;
    case NotificationKind.wallOfTheDay when notificationGroupHasUniformBody(group):
      return wallOfTheDayRowDayLabel(n.createdAt);
    case NotificationKind.wallOfTheDay || NotificationKind.generic:
      return null;
  }
}

@RoutePage()
class NotificationScreen extends StatelessWidget {
  const NotificationScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider<InAppNotificationsBloc>.value(
      value: getIt<InAppNotificationsBloc>(),
      child: const _NotificationScreenBody(),
    );
  }
}

class _NotificationScreenBody extends StatefulWidget {
  const _NotificationScreenBody();

  @override
  State<_NotificationScreenBody> createState() => _NotificationScreenBodyState();
}

class _NotificationScreenBodyState extends State<_NotificationScreenBody> {
  /// [InAppNotificationTitleGroup.key] values for expanded summary rows.
  final Set<String> _expandedNotificationGroups = <String>{};

  @override
  void initState() {
    super.initState();
    context.read<InAppNotificationsBloc>().add(const InAppNotificationsEvent.started(syncRemote: true));
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<InAppNotificationsBloc, InAppNotificationsState>(
      builder: (context, state) {
        final theme = Theme.of(context);
        final colorScheme = theme.colorScheme;
        final notifications = state.items;
        final groups = groupInAppNotificationsByTitle(notifications);
        final bool initialLoading =
            (state.status == LoadStatus.initial || state.status == LoadStatus.loading) && notifications.isEmpty;

        Widget body;
        if (initialLoading) {
          body = const GlintState(kind: GlintStateKind.loading, title: 'Loading notifications');
        } else if (state.status == LoadStatus.failure && notifications.isEmpty) {
          body = GlintState(
            kind: GlintStateKind.error,
            title: "We couldn't load your notifications.",
            body: 'Check your connection and try again.',
            actionLabel: 'Try again',
            onAction: () {
              context.read<InAppNotificationsBloc>().add(const InAppNotificationsEvent.refreshRequested());
            },
          );
        } else {
          body = Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (state.status == LoadStatus.failure && state.failure != null)
                Material(
                  color: colorScheme.errorContainer,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            "Couldn't load new notifications. What you see below is saved on this device.",
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: colorScheme.onErrorContainer,
                              fontSize: 13,
                            ),
                          ),
                        ),
                        TextButton(
                          onPressed: () {
                            PrismHaptics.tap();
                            context.read<InAppNotificationsBloc>().add(
                              const InAppNotificationsEvent.refreshRequested(),
                            );
                          },
                          style: TextButton.styleFrom(foregroundColor: colorScheme.onErrorContainer),
                          child: const Text('Try again'),
                        ),
                      ],
                    ),
                  ),
                ),
              Expanded(
                child: notifications.isEmpty
                    ? const GlintState(
                        kind: GlintStateKind.nothingNew,
                        title: "You're all caught up",
                        body: 'Giveaways, updates, and alerts from Prism will show up here.',
                      )
                    : ListView.builder(
                        itemCount: groups.length,
                        itemBuilder: (BuildContext context, int index) {
                          final InAppNotificationTitleGroup group = groups[index];
                          if (group.isSingle) {
                            return _buildDismissibleNotificationTile(
                              context,
                              colorScheme: colorScheme,
                              notification: group.items.single,
                            );
                          }
                          return _buildDismissibleGroupTile(
                            context,
                            theme: theme,
                            colorScheme: colorScheme,
                            group: group,
                          );
                        },
                      ),
              ),
            ],
          );
        }

        return Scaffold(
          backgroundColor: theme.primaryColor,
          appBar: AppBar(
            automaticallyImplyLeading: false,
            elevation: 0,
            iconTheme: IconThemeData(color: colorScheme.secondary),
            title: Text('Notifications', style: theme.textTheme.displaySmall?.copyWith(color: colorScheme.secondary)),
            leading: IconButton(
              tooltip: 'Close',
              icon: const Icon(JamIcons.close),
              onPressed: () {
                context.router.maybePop();
              },
            ),
            actions: <Widget>[
              if (state.unreadCount > 0)
                IconButton(
                  tooltip: 'Mark all as read',
                  icon: const Icon(JamIcons.check),
                  onPressed: () {
                    PrismHaptics.tap();
                    context.read<InAppNotificationsBloc>().add(const InAppNotificationsEvent.markAllReadRequested());
                  },
                ),
              IconButton(
                tooltip: 'Notification preferences',
                icon: const Icon(JamIcons.settings_alt),
                onPressed: () {
                  analytics.track(
                    SettingsActionTappedEvent(
                      action: AnalyticsActionValue.notificationSettingsOpened,
                      isSignedIn: app_state.prismUser.loggedIn,
                      sourceContext: 'notification_screen',
                    ),
                  );
                  showNotificationSettingsSheet(context);
                },
              ),
            ],
          ),
          body: body,
          floatingActionButton: !initialLoading && notifications.isNotEmpty
              ? FloatingActionButton.small(
                  tooltip: 'Clear inbox',
                  backgroundColor: colorScheme.error,
                  foregroundColor: colorScheme.onError,
                  onPressed: () {
                    PrismHaptics.tap();
                    analytics.track(NotificationClearAllConfirmedEvent(count: notifications.length));
                    context.read<InAppNotificationsBloc>().add(const InAppNotificationsEvent.clearRequested());
                    _showUndoSnackBar(context, 'Inbox cleared', notifications);
                  },
                  child: const Icon(JamIcons.trash),
                )
              : null,
        );
      },
    );
  }

  void _showUndoSnackBar(BuildContext context, String message, List<InAppNotificationEntity> removed) {
    final InAppNotificationsBloc bloc = context.read<InAppNotificationsBloc>();
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(message),
          action: SnackBarAction(
            label: 'Undo',
            onPressed: () => bloc.add(InAppNotificationsEvent.restoreRequested(items: removed)),
          ),
        ),
      );
  }

  Widget _dismissBackground(ColorScheme colorScheme, Alignment alignment) {
    return ColoredBox(
      color: colorScheme.error,
      child: Align(
        alignment: alignment,
        child: Padding(
          padding: const EdgeInsets.all(8),
          child: Icon(JamIcons.trash, color: colorScheme.onError),
        ),
      ),
    );
  }

  Widget _buildDismissibleNotificationTile(
    BuildContext context, {
    required ColorScheme colorScheme,
    required InAppNotificationEntity notification,
    bool compactInGroup = false,
    String? compactBodyOverride,
  }) {
    return Dismissible(
      key: ValueKey<String>(notification.id),
      onDismissed: (_) {
        PrismHaptics.impact();
        analytics.track(
          NotificationItemDismissedEvent(type: _notificationTypeFor(notification), dismissMode: DismissModeValue.swipe),
        );
        context.read<InAppNotificationsBloc>().add(InAppNotificationsEvent.deleteRequested(id: notification.id));
        _showUndoSnackBar(context, 'Notification removed', <InAppNotificationEntity>[notification]);
      },
      dismissThresholds: const {DismissDirection.startToEnd: 0.5, DismissDirection.endToStart: 0.5},
      secondaryBackground: _dismissBackground(colorScheme, Alignment.centerRight),
      background: _dismissBackground(colorScheme, Alignment.centerLeft),
      child: _NotificationCard(
        notification: notification,
        compactInGroup: compactInGroup,
        compactBodyOverride: compactBodyOverride,
        onMarkRead: () {
          context.read<InAppNotificationsBloc>().add(InAppNotificationsEvent.markReadRequested(id: notification.id));
        },
      ),
    );
  }

  Widget _buildDismissibleGroupTile(
    BuildContext context, {
    required ThemeData theme,
    required ColorScheme colorScheme,
    required InAppNotificationTitleGroup group,
  }) {
    final bool expanded = _expandedNotificationGroups.contains(group.key);
    return Dismissible(
      key: ValueKey<String>('grp:${group.items.map((InAppNotificationEntity e) => e.id).join('|')}'),
      onDismissed: (_) {
        PrismHaptics.impact();
        context.read<InAppNotificationsBloc>().add(
          InAppNotificationsEvent.deleteManyRequested(
            ids: group.items.map((InAppNotificationEntity e) => e.id).toList(),
          ),
        );
        _showUndoSnackBar(context, '${group.items.length} notifications removed', group.items);
      },
      dismissThresholds: const {DismissDirection.startToEnd: 0.5, DismissDirection.endToStart: 0.5},
      secondaryBackground: _dismissBackground(colorScheme, Alignment.centerRight),
      background: _dismissBackground(colorScheme, Alignment.centerLeft),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          Semantics(
            button: true,
            expanded: expanded,
            label:
                '${group.displayTitle}. ${groupedListCountActionLine(group, expanded: expanded)}. ${expanded ? 'Expanded' : 'Collapsed'}. ${group.unreadCount > 0 ? 'Has unread. ' : ''}Activate to ${expanded ? 'collapse' : 'expand'}.',
            child: Material(
              color: theme.primaryColor,
              child: InkWell(
                onTap: () {
                  PrismHaptics.tap();
                  setState(() {
                    if (expanded) {
                      _expandedNotificationGroups.remove(group.key);
                    } else {
                      _expandedNotificationGroups.add(group.key);
                    }
                  });
                },
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      ExcludeSemantics(
                        child: CircleAvatar(
                          backgroundImage: const AssetImage('assets/images/prism.webp'),
                          backgroundColor: theme.primaryColor,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                if (group.unreadCount > 0) ...<Widget>[
                                  ExcludeSemantics(child: _UnreadDot(color: colorScheme.error)),
                                  const SizedBox(width: 6),
                                ],
                                Expanded(
                                  child: Text(
                                    group.displayTitle,
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    style: theme.textTheme.headlineMedium?.copyWith(
                                      color: colorScheme.secondary,
                                      fontWeight: group.unreadCount > 0 ? FontWeight.w700 : FontWeight.w500,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  notificationTimeLabel(group.items.first.createdAt),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: theme.textTheme.titleLarge?.copyWith(
                                    fontSize: 12,
                                    color: colorScheme.secondary.withValues(alpha: 0.8),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Text(
                              groupedListCountActionLine(group, expanded: expanded),
                              style: theme.textTheme.titleLarge?.copyWith(
                                fontSize: 12,
                                color: colorScheme.secondary.withValues(alpha: 0.85),
                              ),
                            ),
                            if (!expanded) ...[
                              const SizedBox(height: 4),
                              Text(
                                collapsedGroupSummaryLine(group),
                                maxLines: 3,
                                overflow: TextOverflow.ellipsis,
                                style: theme.textTheme.titleLarge?.copyWith(
                                  fontSize: 12,
                                  height: 1.25,
                                  color: colorScheme.secondary,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                      const SizedBox(width: 4),
                      Icon(
                        expanded ? JamIcons.chevron_up : JamIcons.chevron_down,
                        size: 20,
                        color: colorScheme.secondary.withValues(alpha: 0.75),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          if (expanded)
            Padding(
              padding: const EdgeInsetsDirectional.only(start: 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: group.items
                    .map(
                      (InAppNotificationEntity n) => _buildDismissibleNotificationTile(
                        context,
                        colorScheme: colorScheme,
                        notification: n,
                        compactInGroup: true,
                        compactBodyOverride: _compactLineForGroupedChild(group, n),
                      ),
                    )
                    .toList(growable: false),
              ),
            ),
        ],
      ),
    );
  }
}

class _UnreadDot extends StatelessWidget {
  const _UnreadDot({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: DecoratedBox(
        decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        child: const SizedBox.square(dimension: 8),
      ),
    );
  }
}

class _NotificationCard extends StatelessWidget {
  const _NotificationCard({
    required this.notification,
    this.onMarkRead,
    this.compactInGroup = false,
    this.compactBodyOverride,
  });

  final InAppNotificationEntity notification;
  final VoidCallback? onMarkRead;

  /// When true (child under an expanded title group): no avatar, title, or image—body + time only.
  final bool compactInGroup;

  /// When set with [compactInGroup], replaces the default body/title line (e.g. follower name only).
  final String? compactBodyOverride;
  static const NotificationRouteMapper _routeMapper = NotificationRouteMapper();

  static bool _hasValidImageUrl(String? url) => Uri.tryParse(url?.trim() ?? '')?.host.isNotEmpty ?? false;

  Future<void> _onTap(BuildContext context) async {
    PrismHaptics.tap();
    onMarkRead?.call();
    analytics.track(
      NotificationItemOpenedEvent(
        type: _notificationTypeFor(notification),
        destination: _destinationFor(notification),
        hasExternalUrl: notification.url.trim().isNotEmpty,
      ),
    );
    if (notification.url.trim().isNotEmpty) {
      await openPrismLink(context, notification.url);
      return;
    }
    final String route = (notification.route ?? notification.pageName).trim();
    final PageRouteInfo? mappedRoute = await _routeMapper.fromRoute(
      route: route,
      wallId: notification.wallId,
      profileIdentifier: notification.followerEmail,
      sourceTag: 'notification.route_mapper',
    );
    if (!context.mounted) return;
    context.router.navigate(mappedRoute ?? const NotificationRoute());
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final String timeStr = notificationTimeLabel(notification.createdAt);

    if (compactInGroup) {
      final String trimmedOverride = compactBodyOverride?.trim() ?? '';
      final String displayBody = trimmedOverride.isNotEmpty
          ? trimmedOverride
          : (notification.body.trim().isEmpty ? notification.title.trim() : notification.body.trim());
      final String semanticLine = notification.body.trim().isNotEmpty
          ? notification.body.trim()
          : (notification.title.trim().isNotEmpty ? notification.title.trim() : displayBody);
      return Semantics(
        button: true,
        label: '$semanticLine. $timeStr. ${notification.read ? 'Already read' : 'Not read yet'}',
        child: Material(
          color: theme.primaryColor,
          child: InkWell(
            onTap: () => _onTap(context),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (!notification.read) ...<Widget>[
                    ExcludeSemantics(child: _UnreadDot(color: colorScheme.error)),
                    const SizedBox(width: 6),
                  ],
                  Expanded(
                    child: Text(
                      displayBody,
                      maxLines: 4,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.titleLarge?.copyWith(
                        fontSize: 13,
                        height: 1.25,
                        color: colorScheme.secondary,
                        fontWeight: notification.read ? null : FontWeight.w700,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    timeStr,
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontSize: 12,
                      color: colorScheme.secondary.withValues(alpha: 0.75),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    final bool showImage = _hasValidImageUrl(notification.imageUrl);
    final double dpr = MediaQuery.devicePixelRatioOf(context);
    final int memCacheWidth = (MediaQuery.sizeOf(context).width * dpr).round().clamp(1, 4096);

    return Semantics(
      button: true,
      label:
          '${notification.title}. ${notification.body}. $timeStr. ${notification.read ? 'Already read' : 'Not read yet'}',
      child: Material(
        color: theme.primaryColor,
        child: InkWell(
          onTap: () => _onTap(context),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    ExcludeSemantics(
                      child: CircleAvatar(
                        backgroundImage: const AssetImage('assets/images/prism.webp'),
                        backgroundColor: theme.primaryColor,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: <Widget>[
                              if (!notification.read) ...<Widget>[
                                ExcludeSemantics(child: _UnreadDot(color: colorScheme.error)),
                                const SizedBox(width: 6),
                              ],
                              Expanded(
                                child: Text(
                                  notification.title,
                                  maxLines: 3,
                                  overflow: TextOverflow.ellipsis,
                                  style: theme.textTheme.headlineMedium?.copyWith(
                                    color: colorScheme.secondary,
                                    fontWeight: notification.read ? FontWeight.w500 : FontWeight.w700,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                timeStr,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: theme.textTheme.titleLarge?.copyWith(
                                  fontSize: 12,
                                  color: colorScheme.secondary.withValues(alpha: 0.8),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(
                            notification.body,
                            maxLines: 6,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.titleLarge?.copyWith(fontSize: 12, color: colorScheme.secondary),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                if (showImage) ...<Widget>[
                  const SizedBox(height: 10),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: SizedBox(
                      width: double.infinity,
                      height: MediaQuery.sizeOf(context).width * 9 / 16,
                      child: CachedNetworkImage(
                        imageUrl: notification.imageUrl,
                        fit: BoxFit.cover,
                        memCacheWidth: memCacheWidth,
                        placeholder: (_, _) =>
                            Center(child: CircularProgressIndicator(strokeWidth: 2, color: colorScheme.error)),
                        errorWidget: (_, _, _) => const SizedBox.shrink(),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

NotificationTypeValue _notificationTypeFor(InAppNotificationEntity notification) {
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
