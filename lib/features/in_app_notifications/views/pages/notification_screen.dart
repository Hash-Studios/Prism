import 'package:Prism/analytics/analytics_service.dart';
import 'package:Prism/core/analytics/events/events.dart';
import 'package:Prism/core/coins/coins_service.dart';
import 'package:Prism/core/di/injection.dart';
import 'package:Prism/core/persistence/data_sources/settings_local_data_source.dart';
import 'package:Prism/core/router/app_router.dart';
import 'package:Prism/core/router/notification_route_mapper.dart';
import 'package:Prism/core/state/app_state.dart' as app_state;
import 'package:Prism/core/utils/status.dart';
import 'package:Prism/core/utils/url_launcher_compat.dart';
import 'package:Prism/features/in_app_notifications/biz/bloc/in_app_notifications_bloc.j.dart';
import 'package:Prism/features/in_app_notifications/domain/entities/in_app_notification_entity.dart';
import 'package:Prism/features/in_app_notifications/domain/notification_grouping.dart';
import 'package:Prism/notifications/topic_subscription.dart';
import 'package:Prism/theme/jam_icons_icons.dart';
import 'package:Prism/theme/toasts.dart' as toasts;
import 'package:auto_route/auto_route.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';

/// Shorter expanded-row text: names for followers/wall-live; day label for uniform WOTD bodies.
String? _compactLineForGroupedChild(InAppNotificationTitleGroup group, InAppNotificationEntity n) {
  if (notificationGroupLooksLikeFollowers(group)) {
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
  }
  if (notificationGroupLooksLikeWallApprovedLive(group)) {
    final String? creator = wallLiveCreatorNameFromBody(n.body);
    if (creator != null && creator.isNotEmpty) {
      return creator;
    }
    return null;
  }
  if (notificationGroupLooksLikeWallOfTheDay(group) && notificationGroupHasUniformBody(group)) {
    return wallOfTheDayRowDayLabel(n.createdAt);
  }
  return null;
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
        final bool initialLoading =
            (state.status == LoadStatus.initial || state.status == LoadStatus.loading) && notifications.isEmpty;

        Widget body;
        if (initialLoading) {
          body = Center(
            child: Semantics(
              label: 'Loading notifications',
              child: CircularProgressIndicator(color: colorScheme.error),
            ),
          );
        } else if (state.status == LoadStatus.failure && notifications.isEmpty) {
          body = Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    "We couldn't load your notifications.",
                    textAlign: TextAlign.center,
                    style: theme.textTheme.headlineSmall?.copyWith(
                      color: colorScheme.secondary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Check your connection and try again.',
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodyMedium?.copyWith(color: colorScheme.secondary.withValues(alpha: 0.85)),
                  ),
                  const SizedBox(height: 20),
                  TextButton(
                    onPressed: () {
                      context.read<InAppNotificationsBloc>().add(const InAppNotificationsEvent.refreshRequested());
                    },
                    style: TextButton.styleFrom(foregroundColor: colorScheme.error),
                    child: const Text('Try again'),
                  ),
                ],
              ),
            ),
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
                    ? Center(
                        child: Padding(
                          padding: const EdgeInsets.all(24),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                "You're all caught up",
                                textAlign: TextAlign.center,
                                style: theme.textTheme.headlineSmall?.copyWith(
                                  color: colorScheme.secondary,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'Giveaways, updates, and alerts from Prism will show up here.',
                                textAlign: TextAlign.center,
                                style: theme.textTheme.bodyMedium?.copyWith(
                                  color: colorScheme.secondary.withValues(alpha: 0.85),
                                ),
                              ),
                            ],
                          ),
                        ),
                      )
                    : Builder(
                        builder: (BuildContext listContext) {
                          final groups = groupInAppNotificationsByTitle(notifications);
                          return ListView.builder(
                            itemCount: groups.length,
                            itemBuilder: (BuildContext context, int index) {
                              final InAppNotificationTitleGroup group = groups[index];
                              if (group.isSingle) {
                                return _buildDismissibleNotificationTile(
                                  context,
                                  theme: theme,
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
            title: Text(
              'Notifications',
              style: theme.textTheme.displaySmall?.copyWith(color: colorScheme.secondary),
            ),
            leading: IconButton(
              tooltip: 'Close',
              icon: const Icon(JamIcons.close),
              onPressed: () {
                context.router.maybePop();
              },
            ),
            actions: <Widget>[
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
                  showModalBottomSheet<void>(
                    context: context,
                    isScrollControlled: true,
                    backgroundColor: Theme.of(context).primaryColor,
                    shape: const RoundedRectangleBorder(
                      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
                    ),
                    builder: (_) => const NotificationSettingsSheet(),
                  );
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
                    showDialog<void>(
                      context: context,
                      builder: (BuildContext ctx) {
                        final t = Theme.of(ctx);
                        final cs = t.colorScheme;
                        return AlertDialog(
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          backgroundColor: t.primaryColor,
                          title: Text(
                            'Clear your inbox?',
                            style: t.textTheme.headlineSmall?.copyWith(
                              color: cs.secondary,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          content: Text(
                            "You'll remove every notification from this list on this device. This can't be undone.",
                            style: t.textTheme.bodyMedium?.copyWith(color: cs.secondary.withValues(alpha: 0.9)),
                          ),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.of(ctx).pop(),
                              child: Text('Cancel', style: TextStyle(color: cs.secondary)),
                            ),
                            TextButton(
                              onPressed: () {
                                Navigator.of(ctx).pop();
                                analytics.track(NotificationClearAllConfirmedEvent(count: notifications.length));
                                context.read<InAppNotificationsBloc>().add(
                                  const InAppNotificationsEvent.clearRequested(),
                                );
                              },
                              child: Text('Clear inbox', style: TextStyle(color: cs.error, fontWeight: FontWeight.w600)),
                            ),
                          ],
                          actionsPadding: const EdgeInsets.fromLTRB(10, 0, 10, 0),
                        );
                      },
                    );
                  },
                  child: const Icon(JamIcons.trash),
                )
              : null,
        );
      },
    );
  }

  Future<bool> _confirmRemoveFromInbox(
    BuildContext context, {
    required String title,
    required String content,
  }) async {
    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext ctx) {
        final ThemeData t = Theme.of(ctx);
        final ColorScheme cs = t.colorScheme;
        return AlertDialog(
          backgroundColor: t.primaryColor,
          title: Text(
            title,
            style: t.textTheme.headlineSmall?.copyWith(color: cs.secondary, fontWeight: FontWeight.w600),
          ),
          content: Text(
            content,
            style: t.textTheme.bodyMedium?.copyWith(color: cs.secondary.withValues(alpha: 0.9)),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: Text('Cancel', style: TextStyle(color: cs.secondary)),
            ),
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(true),
              child: Text('Remove', style: TextStyle(color: cs.error, fontWeight: FontWeight.w600)),
            ),
          ],
        );
      },
    );
    return confirmed ?? false;
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
    required ThemeData theme,
    required ColorScheme colorScheme,
    required InAppNotificationEntity notification,
    bool compactInGroup = false,
    String? compactBodyOverride,
  }) {
    return Dismissible(
      key: ValueKey<String>(notification.id),
      confirmDismiss: (DismissDirection direction) async => _confirmRemoveFromInbox(
        context,
        title: 'Remove from inbox?',
        content: 'This notification will be removed from your list on this device.',
      ),
      onDismissed: (_) {
        analytics.track(
          NotificationItemDismissedEvent(
            type: _notificationTypeFor(notification),
            dismissMode: DismissModeValue.swipe,
          ),
        );
        context.read<InAppNotificationsBloc>().add(InAppNotificationsEvent.deleteRequested(id: notification.id));
      },
      dismissThresholds: const {DismissDirection.startToEnd: 0.5, DismissDirection.endToStart: 0.5},
      secondaryBackground: _dismissBackground(colorScheme, Alignment.centerRight),
      background: _dismissBackground(colorScheme, Alignment.centerLeft),
      child: NotificationCard(
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
      confirmDismiss: (DismissDirection direction) async => _confirmRemoveFromInbox(
        context,
        title: 'Remove this summary?',
        content:
            'All ${group.items.length} notifications in this group will be removed from your list on this device.',
      ),
      onDismissed: (_) {
        context.read<InAppNotificationsBloc>().add(
          InAppNotificationsEvent.deleteManyRequested(ids: group.items.map((InAppNotificationEntity e) => e.id).toList()),
        );
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
                                Expanded(
                                  child: Text(
                                    group.displayTitle,
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    style: theme.textTheme.headlineMedium?.copyWith(color: colorScheme.secondary),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  NotificationCard.stringForDatetime(group.items.first.createdAt),
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
                        theme: theme,
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

class NotificationCard extends StatelessWidget {
  const NotificationCard({
    super.key,
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

  static bool _hasValidImageUrl(String? url) {
    if (url == null || url.trim().isEmpty) return false;
    try {
      final uri = Uri.parse(url.trim());
      return uri.host.isNotEmpty;
    } catch (_) {
      return false;
    }
  }

  static String stringForDatetime(DateTime dt) {
    final dtInLocal = dt.toLocal();
    final now = DateTime.now().toLocal();
    var dateString = '';

    final diff = now.difference(dtInLocal);

    if (now.day == dtInLocal.day) {
      final todayFormat = DateFormat('h:mm a');
      dateString += todayFormat.format(dtInLocal);
    } else if ((diff.inDays) == 1 || (diff.inSeconds < 86400 && now.day != dtInLocal.day)) {
      final yesterdayFormat = DateFormat('h:mm a');
      dateString += 'Yesterday, ${yesterdayFormat.format(dtInLocal)}';
    } else if (now.year == dtInLocal.year && diff.inDays > 1) {
      final monthFormat = DateFormat('MMM d');
      dateString += monthFormat.format(dtInLocal);
    } else {
      final yearFormat = DateFormat('MMM d y');
      dateString += yearFormat.format(dtInLocal);
    }

    return dateString;
  }

  Future<void> _onTap(BuildContext context) async {
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
    if (mappedRoute != null) {
      context.router.navigate(mappedRoute);
      return;
    }
    context.router.navigate(const NotFoundRoute());
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final String timeStr = stringForDatetime(notification.createdAt);

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
        label:
            '$semanticLine. $timeStr. ${notification.read ? 'Already read' : 'Not read yet'}',
        child: Material(
          color: theme.primaryColor,
          child: InkWell(
            onTap: () => _onTap(context),
            onLongPress: () => HapticFeedback.lightImpact(),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Text(
                      displayBody,
                      maxLines: 4,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.titleLarge?.copyWith(
                        fontSize: 13,
                        height: 1.25,
                        color: colorScheme.secondary,
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
          onLongPress: () => HapticFeedback.lightImpact(),
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
                              Expanded(
                                child: Text(
                                  notification.title,
                                  maxLines: 3,
                                  overflow: TextOverflow.ellipsis,
                                  style: theme.textTheme.headlineMedium?.copyWith(color: colorScheme.secondary),
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
                            style: theme.textTheme.titleLarge?.copyWith(
                              fontSize: 12,
                              color: colorScheme.secondary,
                            ),
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
                        placeholder: (_, __) => Center(
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: colorScheme.error,
                          ),
                        ),
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
  if (notification.pageName.trim().isNotEmpty || (notification.route?.trim().isNotEmpty == true)) {
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

class NotificationSettingsSheet extends StatefulWidget {
  const NotificationSettingsSheet({super.key});

  @override
  State<NotificationSettingsSheet> createState() => _NotificationSettingsSheetState();
}

class _NotificationSettingsSheetState extends State<NotificationSettingsSheet> {
  final SettingsLocalDataSource _settingsLocal = getIt<SettingsLocalDataSource>();
  bool? followersSubscriber;
  bool? postsSubscriber;
  bool? inappSubscriber;
  bool? recommendationsSubscriber;
  bool? streakReminderSubscriber;

  /// Matches list tile title styling used in [SettingsScreen].
  TextStyle get _listTileTitleStyle => TextStyle(
    color: Theme.of(context).colorScheme.secondary,
    fontWeight: FontWeight.w500,
    fontFamily: 'Proxima Nova',
  );

  TextStyle _listTileSubtitleStyle() => const TextStyle(fontSize: 12).copyWith(
    color: Theme.of(context).colorScheme.secondary.withValues(alpha: 0.78),
  );

  @override
  void initState() {
    super.initState();
    followersSubscriber = _settingsLocal.get<bool>('followersSubscriber', defaultValue: true);
    postsSubscriber = _settingsLocal.get<bool>('postsSubscriber', defaultValue: true);
    inappSubscriber = _settingsLocal.get<bool>('inappSubscriber', defaultValue: true);
    recommendationsSubscriber = _settingsLocal.get<bool>('recommendationsSubscriber', defaultValue: true);
    streakReminderSubscriber = _settingsLocal.get<bool>('streakReminderSubscriber', defaultValue: true);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final bottomInset = MediaQuery.paddingOf(context).bottom;
    final sheetHeight = MediaQuery.sizeOf(context).height / 2.3 > 380 ? MediaQuery.sizeOf(context).height / 2.3 : 380.0;

    return Padding(
      padding: EdgeInsets.only(bottom: bottomInset),
      child: SizedBox(
        height: sheetHeight,
        child: ListView(
          physics: const ClampingScrollPhysics(),
          children: [
            Center(
              child: Container(
                height: 4,
                width: 36,
                margin: const EdgeInsets.only(top: 8, bottom: 12),
                decoration: BoxDecoration(
                  color: theme.hintColor,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: Text('Notification preferences', style: theme.textTheme.titleMedium),
            ),
            _buildFollowersToggle(context),
            _buildPostsToggle(context),
            _buildInAppToggle(context),
            _buildRecommendationsToggle(context),
            _buildStreakToggle(context),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Widget _buildFollowersToggle(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return SwitchListTile(
      activeThumbColor: cs.error,
      secondary: Icon(JamIcons.user_plus, color: cs.secondary),
      value: followersSubscriber ?? true,
      title: Text('Followers', style: _listTileTitleStyle),
      subtitle: Text('Alerts when someone new follows you.', style: _listTileSubtitleStyle()),
      onChanged: (bool value) async {
        if (app_state.prismUser.loggedIn) {
          await _settingsLocal.set('followersSubscriber', value);
          setState(() => followersSubscriber = value);
          analytics.track(
            NotificationPreferenceChangedEvent(preference: NotificationPreferenceValue.followers, value: value),
          );
          if (value) {
            await subscribeToTopicSafely(
              FirebaseMessaging.instance,
              app_state.prismUser.email.split('@')[0],
              sourceTag: 'notification.settings.followers.enable',
            );
          } else {
            await unsubscribeFromTopicSafely(
              FirebaseMessaging.instance,
              app_state.prismUser.email.split('@')[0],
              sourceTag: 'notification.settings.followers.disable',
            );
            await _settingsLocal.set('postsSubscriber', false);
            setState(() => postsSubscriber = false);
            analytics.track(
              const NotificationPreferenceChangedEvent(preference: NotificationPreferenceValue.posts, value: false),
            );
            await unsubscribeFromTopicSafely(
              FirebaseMessaging.instance,
              'posts',
              sourceTag: 'notification.settings.posts.disable_from_followers',
            );
          }
        } else {
          analytics.track(
            const NotificationActionBlockedEvent(
              action: AnalyticsActionValue.notificationSettingsOpened,
              reason: AnalyticsReasonValue.notSignedIn,
            ),
          );
          toasts.error('Sign in to change this setting.');
        }
      },
    );
  }

  Widget _buildPostsToggle(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return SwitchListTile(
      activeThumbColor: cs.error,
      secondary: Icon(JamIcons.pictures, color: cs.secondary),
      value: postsSubscriber ?? true,
      title: Text('Posts', style: _listTileTitleStyle),
      subtitle: Text('Alerts when creators you follow share new work.', style: _listTileSubtitleStyle()),
      onChanged: (followersSubscriber ?? true)
          ? (bool value) async {
              if (app_state.prismUser.loggedIn) {
                await _settingsLocal.set('postsSubscriber', value);
                setState(() => postsSubscriber = value);
                analytics.track(
                  NotificationPreferenceChangedEvent(preference: NotificationPreferenceValue.posts, value: value),
                );
                if (value) {
                  await subscribeToTopicSafely(
                    FirebaseMessaging.instance,
                    'posts',
                    sourceTag: 'notification.settings.posts.enable',
                  );
                } else {
                  await unsubscribeFromTopicSafely(
                    FirebaseMessaging.instance,
                    'posts',
                    sourceTag: 'notification.settings.posts.disable',
                  );
                }
              } else {
                analytics.track(
                  const NotificationActionBlockedEvent(
                    action: AnalyticsActionValue.notificationSettingsOpened,
                    reason: AnalyticsReasonValue.notSignedIn,
                  ),
                );
                toasts.error('Sign in to change this setting.');
              }
            }
          : null,
    );
  }

  Widget _buildInAppToggle(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return SwitchListTile(
      activeThumbColor: cs.error,
      secondary: Icon(JamIcons.picture, color: cs.secondary),
      value: inappSubscriber ?? true,
      title: Text('Prism updates', style: _listTileTitleStyle),
      subtitle: Text('Giveaways, contests, and news inside the app.', style: _listTileSubtitleStyle()),
      onChanged: (bool value) async {
        await _settingsLocal.set('inappSubscriber', value);
        setState(() => inappSubscriber = value);
        analytics.track(
          NotificationPreferenceChangedEvent(preference: NotificationPreferenceValue.inApp, value: value),
        );
      },
    );
  }

  Widget _buildRecommendationsToggle(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return SwitchListTile(
      activeThumbColor: cs.error,
      secondary: Icon(JamIcons.lightbulb, color: cs.secondary),
      value: recommendationsSubscriber ?? true,
      title: Text('Recommendations', style: _listTileTitleStyle),
      subtitle: Text('Tips and wallpaper picks from Prism.', style: _listTileSubtitleStyle()),
      onChanged: (bool value) async {
        await _settingsLocal.set('recommendationsSubscriber', value);
        setState(() => recommendationsSubscriber = value);
        analytics.track(
          NotificationPreferenceChangedEvent(preference: NotificationPreferenceValue.recommendations, value: value),
        );
        if (value) {
          await subscribeToTopicSafely(
            FirebaseMessaging.instance,
            'recommendations',
            sourceTag: 'notification.settings.recommendations.enable',
          );
        } else {
          await unsubscribeFromTopicSafely(
            FirebaseMessaging.instance,
            'recommendations',
            sourceTag: 'notification.settings.recommendations.disable',
          );
        }
      },
    );
  }

  Widget _buildStreakToggle(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return SwitchListTile(
      activeThumbColor: cs.error,
      secondary: Icon(Icons.local_fire_department_rounded, color: cs.secondary),
      value: streakReminderSubscriber ?? true,
      title: Text('Streak reminders', style: _listTileTitleStyle),
      subtitle: Text(
        'Evening heads-up around 8 PM if your login streak is about to break.',
        style: _listTileSubtitleStyle(),
      ),
      onChanged: (bool value) async {
        if (app_state.prismUser.loggedIn) {
          await _settingsLocal.set('streakReminderSubscriber', value);
          setState(() => streakReminderSubscriber = value);
          analytics.track(
            NotificationPreferenceChangedEvent(preference: NotificationPreferenceValue.streakReminders, value: value),
          );
          await CoinsService.instance.setStreakReminderPreference(
            value,
            sourceTag: 'notification.settings.streak_reminders',
          );
        } else {
          analytics.track(
            const NotificationActionBlockedEvent(
              action: AnalyticsActionValue.notificationSettingsOpened,
              reason: AnalyticsReasonValue.notSignedIn,
            ),
          );
          toasts.error('Sign in to change this setting.');
        }
      },
    );
  }
}
