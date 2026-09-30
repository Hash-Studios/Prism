import 'dart:async';

import 'package:Prism/analytics/analytics_service.dart';
import 'package:Prism/core/analytics/events/events.dart';
import 'package:Prism/core/di/injection.dart';
import 'package:Prism/core/state/app_state.dart' as app_state;
import 'package:Prism/core/utils/status.dart';
import 'package:Prism/core/widgets/prism/prism_ui.dart';
import 'package:Prism/features/in_app_notifications/biz/bloc/in_app_notifications_bloc.j.dart';
import 'package:Prism/features/in_app_notifications/domain/entities/in_app_notification_entity.dart';
import 'package:Prism/features/in_app_notifications/domain/notification_grouping.dart';
import 'package:Prism/features/in_app_notifications/views/widgets/notification_row.dart';
import 'package:Prism/features/in_app_notifications/views/widgets/notification_settings_sheet.dart';
import 'package:Prism/features/in_app_notifications/views/widgets/notification_visuals.dart';
import 'package:auto_route/auto_route.dart';
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

  void _refresh() {
    context.read<InAppNotificationsBloc>().add(const InAppNotificationsEvent.refreshRequested());
  }

  void _openPreferences() {
    analytics.track(
      SettingsActionTappedEvent(
        action: AnalyticsActionValue.notificationSettingsOpened,
        isSignedIn: app_state.prismUser.loggedIn,
        sourceContext: 'notification_screen',
      ),
    );
    showPrismSheet<void>(context: context, isScrollControlled: true, builder: (_) => const NotificationSettingsSheet());
  }

  Future<void> _clearInbox(int count) async {
    final bool confirmed = await showPrismConfirm(
      context,
      title: 'Clear your inbox?',
      message: "You'll remove every notification from this list on this device. This can't be undone.",
      confirmLabel: 'Clear inbox',
      destructive: true,
    );
    if (!confirmed || !mounted) return;
    analytics.track(NotificationClearAllConfirmedEvent(count: count));
    context.read<InAppNotificationsBloc>().add(const InAppNotificationsEvent.clearRequested());
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<InAppNotificationsBloc, InAppNotificationsState>(
      builder: (context, state) {
        final notifications = state.items;
        final bool initialLoading =
            (state.status == LoadStatus.initial || state.status == LoadStatus.loading) && notifications.isEmpty;
        return PrismPage(
          title: 'Notifications',
          actions: <Widget>[
            PrismIconButton(icon: Icons.tune_rounded, tooltip: 'Notification preferences', onPressed: _openPreferences),
            if (!initialLoading && notifications.isNotEmpty)
              PrismIconButton(
                icon: Icons.delete_sweep_rounded,
                tooltip: 'Clear inbox',
                onPressed: () => _clearInbox(notifications.length),
              ),
          ],
          body: _body(context, state, initialLoading),
        );
      },
    );
  }

  Widget _body(BuildContext context, InAppNotificationsState state, bool initialLoading) {
    final notifications = state.items;
    if (initialLoading) return PrismSkeleton.rows();
    if (state.status == LoadStatus.failure && notifications.isEmpty) {
      return GlintState(
        kind: GlintStateKind.error,
        title: "We couldn't load your notifications",
        body: 'Check your connection and try again.',
        actionLabel: 'Try again',
        onAction: _refresh,
      );
    }
    if (notifications.isEmpty) {
      return const GlintState(
        kind: GlintStateKind.nothingNew,
        title: 'No notifications',
        body: 'New followers, approvals and the Wall of the Day show up here.',
      );
    }
    final List<InAppNotificationTitleGroup> groups = groupInAppNotificationsByTitle(notifications);
    final List<Object> entries = <Object>[];
    String? lastDay;
    for (final InAppNotificationTitleGroup group in groups) {
      final String day = wallOfTheDayRowDayLabel(group.items.first.createdAt);
      if (day != lastDay) {
        entries.add(day);
        lastDay = day;
      }
      entries.add(group);
    }
    final bool stale = state.status == LoadStatus.failure && state.failure != null;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        if (stale) _StaleBanner(onRetry: _refresh),
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.only(bottom: PrismSpace.xxxl),
            itemCount: entries.length,
            itemBuilder: (BuildContext context, int index) {
              final Object entry = entries[index];
              if (entry is String) {
                return PrismSectionHeader(
                  title: entry,
                  small: true,
                  padding: EdgeInsets.fromLTRB(
                    PrismSpace.page,
                    index == 0 ? PrismSpace.xs : PrismSpace.lg,
                    PrismSpace.page,
                    PrismSpace.xxs,
                  ),
                );
              }
              final InAppNotificationTitleGroup group = entry as InAppNotificationTitleGroup;
              return group.isSingle
                  ? _dismissibleNotification(context, group.items.single)
                  : _dismissibleGroup(context, group);
            },
          ),
        ),
      ],
    );
  }

  Widget _dismissBackground(ColorScheme cs, Alignment alignment) {
    return ColoredBox(
      color: cs.error,
      child: Align(
        alignment: alignment,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: PrismSpace.page),
          child: Icon(Icons.delete_rounded, color: cs.onError),
        ),
      ),
    );
  }

  Widget _dismissibleNotification(
    BuildContext context,
    InAppNotificationEntity notification, {
    bool compactInGroup = false,
    String? compactBodyOverride,
  }) {
    final ColorScheme cs = Theme.of(context).colorScheme;
    return Dismissible(
      key: ValueKey<String>(notification.id),
      confirmDismiss: (DismissDirection direction) => showPrismConfirm(
        context,
        title: 'Remove from inbox?',
        message: 'This notification will be removed from your list on this device.',
        confirmLabel: 'Remove',
        destructive: true,
      ),
      onDismissed: (_) {
        analytics.track(
          NotificationItemDismissedEvent(type: notificationTypeFor(notification), dismissMode: DismissModeValue.swipe),
        );
        context.read<InAppNotificationsBloc>().add(InAppNotificationsEvent.deleteRequested(id: notification.id));
      },
      dismissThresholds: const {DismissDirection.startToEnd: 0.5, DismissDirection.endToStart: 0.5},
      secondaryBackground: _dismissBackground(cs, Alignment.centerRight),
      background: _dismissBackground(cs, Alignment.centerLeft),
      child: NotificationRow(
        notification: notification,
        compactInGroup: compactInGroup,
        compactBodyOverride: compactBodyOverride,
        onMarkRead: () {
          context.read<InAppNotificationsBloc>().add(InAppNotificationsEvent.markReadRequested(id: notification.id));
        },
      ),
    );
  }

  Widget _dismissibleGroup(BuildContext context, InAppNotificationTitleGroup group) {
    final ColorScheme cs = Theme.of(context).colorScheme;
    final bool expanded = _expandedNotificationGroups.contains(group.key);
    final String title = cleanNotificationTitle(group.displayTitle);
    final InAppNotificationEntity first = group.items.first;
    return Dismissible(
      key: ValueKey<String>('grp:${group.items.map((InAppNotificationEntity e) => e.id).join('|')}'),
      confirmDismiss: (DismissDirection direction) => showPrismConfirm(
        context,
        title: 'Remove this summary?',
        message: 'All ${group.items.length} notifications in this group will be removed from your list on this device.',
        confirmLabel: 'Remove',
        destructive: true,
      ),
      onDismissed: (_) {
        context.read<InAppNotificationsBloc>().add(
          InAppNotificationsEvent.deleteManyRequested(
            ids: group.items.map((InAppNotificationEntity e) => e.id).toList(),
          ),
        );
      },
      dismissThresholds: const {DismissDirection.startToEnd: 0.5, DismissDirection.endToStart: 0.5},
      secondaryBackground: _dismissBackground(cs, Alignment.centerRight),
      background: _dismissBackground(cs, Alignment.centerLeft),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Semantics(
            button: true,
            expanded: expanded,
            label:
                '$title. ${groupedListCountActionLine(group, expanded: expanded)}. ${expanded ? 'Expanded' : 'Collapsed'}. ${group.unreadCount > 0 ? 'Has unread. ' : ''}Activate to ${expanded ? 'collapse' : 'expand'}.',
            child: Material(
              type: MaterialType.transparency,
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
                child: ExcludeSemantics(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: PrismSpace.page, vertical: PrismSpace.xs),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        NotificationIconTile(title: group.displayTitle, body: first.body),
                        const SizedBox(width: PrismSpace.sm),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: <Widget>[
                              NotificationTitleLine(
                                title: title,
                                time: notificationTimeLabel(first.createdAt),
                                unread: group.unreadCount > 0,
                                trailing: Padding(
                                  padding: const EdgeInsets.only(left: PrismSpace.xxs),
                                  child: AnimatedRotation(
                                    turns: expanded ? 0.5 : 0,
                                    duration: context.motion(PrismDurations.fast),
                                    curve: PrismCurves.move,
                                    child: Icon(
                                      Icons.expand_more_rounded,
                                      size: 20,
                                      color: cs.onSurface.withValues(alpha: 0.6),
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                groupedListCountActionLine(group, expanded: expanded),
                                style: PrismTextStyles.caption(context),
                              ),
                              if (!expanded) ...<Widget>[
                                const SizedBox(height: PrismSpace.xxs),
                                Text(
                                  collapsedGroupSummaryLine(group),
                                  maxLines: 3,
                                  overflow: TextOverflow.ellipsis,
                                  style: PrismTextStyles.body(context),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
          AnimatedSwitcher(
            duration: context.motion(PrismDurations.fast),
            child: expanded
                ? Column(
                    key: ValueKey<String>('open:${group.key}'),
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: group.items
                        .map(
                          (InAppNotificationEntity n) => _dismissibleNotification(
                            context,
                            n,
                            compactInGroup: true,
                            compactBodyOverride: _compactLineForGroupedChild(group, n),
                          ),
                        )
                        .toList(growable: false),
                  )
                : SizedBox.shrink(key: ValueKey<String>('closed:${group.key}')),
          ),
        ],
      ),
    );
  }
}

class _StaleBanner extends StatelessWidget {
  const _StaleBanner({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final ColorScheme cs = Theme.of(context).colorScheme;
    return Container(
      margin: const EdgeInsets.fromLTRB(PrismSpace.page, PrismSpace.xs, PrismSpace.page, PrismSpace.xs),
      padding: const EdgeInsets.fromLTRB(PrismSpace.md, PrismSpace.xs, PrismSpace.xs, PrismSpace.xs),
      decoration: BoxDecoration(color: cs.errorContainer, borderRadius: BorderRadius.circular(PrismRadius.md)),
      child: Row(
        children: <Widget>[
          Expanded(
            child: Text(
              "Couldn't load new notifications. What you see below is saved on this device.",
              style: PrismTextStyles.body(context).copyWith(color: cs.onErrorContainer),
            ),
          ),
          const SizedBox(width: PrismSpace.xs),
          PrismButton(
            label: 'Try again',
            variant: PrismButtonVariant.ghost,
            size: PrismButtonSize.compact,
            onPressed: onRetry,
          ),
        ],
      ),
    );
  }
}
