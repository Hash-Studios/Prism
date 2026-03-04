import 'package:Prism/analytics/analytics_service.dart';
import 'package:Prism/core/analytics/events/events.dart';
import 'package:Prism/core/coins/coins_service.dart';
import 'package:Prism/core/di/injection.dart';
import 'package:Prism/core/persistence/data_sources/settings_local_data_source.dart';
import 'package:Prism/core/router/app_router.dart';
import 'package:Prism/core/router/notification_route_mapper.dart';
import 'package:Prism/core/state/app_state.dart' as app_state;
import 'package:Prism/core/utils/url_launcher_compat.dart';
import 'package:Prism/features/category_feed/views/pages/home_screen.dart' as home;
import 'package:Prism/features/in_app_notifications/biz/bloc/in_app_notifications_bloc.j.dart';
import 'package:Prism/features/in_app_notifications/domain/entities/in_app_notification_entity.dart';
import 'package:Prism/notifications/topic_subscription.dart';
import 'package:Prism/theme/jam_icons_icons.dart';
import 'package:Prism/theme/toasts.dart' as toasts;
import 'package:animations/animations.dart';
import 'package:auto_route/auto_route.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';

@RoutePage()
class NotificationScreen extends StatelessWidget {
  const NotificationScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider<InAppNotificationsBloc>(
      create: (_) => getIt<InAppNotificationsBloc>(),
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
  @override
  void initState() {
    super.initState();
    context.read<InAppNotificationsBloc>().add(const InAppNotificationsEvent.started(syncRemote: true));
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<InAppNotificationsBloc, InAppNotificationsState>(
      builder: (context, state) {
        final notifications = state.items;
        return Scaffold(
          backgroundColor: Theme.of(context).primaryColor,
          appBar: AppBar(
            automaticallyImplyLeading: false,
            title: const Text('Notifications'),
            leading: IconButton(
              icon: const Icon(JamIcons.close),
              onPressed: () {
                context.router.maybePop();
              },
            ),
            actions: <Widget>[
              IconButton(
                tooltip: 'Notification Settings',
                icon: const Icon(JamIcons.settings_alt),
                onPressed: () {
                  analytics.track(
                    SettingsActionTappedEvent(
                      action: AnalyticsActionValue.notificationSettingsOpened,
                      isSignedIn: app_state.prismUser.loggedIn,
                      sourceContext: 'notification_screen',
                    ),
                  );
                  showModalBottomSheet(
                    isScrollControlled: true,
                    context: context,
                    builder: (_) => const NotificationSettingsSheet(),
                  );
                },
              ),
            ],
          ),
          body: notifications.isNotEmpty
              ? ListView.builder(
                  itemCount: notifications.length,
                  itemBuilder: (BuildContext context, int index) {
                    final currentNotification = notifications[index];
                    return Dismissible(
                      key: ValueKey<String>(currentNotification.id),
                      onDismissed: (_) {
                        analytics.track(
                          NotificationItemDismissedEvent(
                            type: _notificationTypeFor(currentNotification),
                            dismissMode: DismissModeValue.swipe,
                          ),
                        );
                        context.read<InAppNotificationsBloc>().add(
                          InAppNotificationsEvent.deleteRequested(id: currentNotification.id),
                        );
                      },
                      dismissThresholds: const {DismissDirection.startToEnd: 0.5, DismissDirection.endToStart: 0.5},
                      secondaryBackground: const ColoredBox(
                        color: Colors.red,
                        child: Align(
                          alignment: Alignment.centerRight,
                          child: Padding(padding: EdgeInsets.all(8.0), child: Icon(JamIcons.trash)),
                        ),
                      ),
                      background: const ColoredBox(
                        color: Colors.red,
                        child: Align(
                          alignment: Alignment.centerLeft,
                          child: Padding(padding: EdgeInsets.all(8.0), child: Icon(JamIcons.trash)),
                        ),
                      ),
                      child: NotificationCard(
                        notification: currentNotification,
                        onMarkRead: () {
                          context.read<InAppNotificationsBloc>().add(
                            InAppNotificationsEvent.markReadRequested(id: currentNotification.id),
                          );
                        },
                      ),
                    );
                  },
                )
              : Center(
                  child: Text('No new notifications', style: TextStyle(color: Theme.of(context).colorScheme.secondary)),
                ),
          floatingActionButton: notifications.isNotEmpty
              ? FloatingActionButton(
                  mini: true,
                  tooltip: 'Clear Notifications',
                  onPressed: () {
                    final AlertDialog deleteNotificationsPopUp = AlertDialog(
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      title: Text(
                        'Clear all notifications?',
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 16,
                          color: Theme.of(context).colorScheme.secondary,
                        ),
                      ),
                      actions: [
                        MaterialButton(
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(5)),
                          color: Theme.of(context).hintColor,
                          onPressed: () {
                            Navigator.of(context).pop();
                            analytics.track(NotificationClearAllConfirmedEvent(count: notifications.length));
                            context.read<InAppNotificationsBloc>().add(const InAppNotificationsEvent.clearRequested());
                          },
                          child: const Text('YES', style: TextStyle(fontSize: 16.0, color: Colors.white)),
                        ),
                        MaterialButton(
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(5)),
                          color: Theme.of(context).colorScheme.error,
                          onPressed: () {
                            Navigator.of(context).pop();
                          },
                          child: const Text('NO', style: TextStyle(fontSize: 16.0, color: Colors.white)),
                        ),
                      ],
                      backgroundColor: Theme.of(context).primaryColor,
                      actionsPadding: const EdgeInsets.fromLTRB(10, 0, 10, 0),
                    );

                    showModal(context: context, builder: (BuildContext context) => deleteNotificationsPopUp);
                  },
                  child: const Icon(JamIcons.trash),
                )
              : Container(),
        );
      },
    );
  }
}

class NotificationCard extends StatelessWidget {
  const NotificationCard({super.key, required this.notification, this.onMarkRead});

  final InAppNotificationEntity notification;
  final VoidCallback? onMarkRead;
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
    final bool showImage = _hasValidImageUrl(notification.imageUrl);
    final String timeStr = stringForDatetime(notification.createdAt);

    return Material(
      color: Theme.of(context).primaryColor,
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
                  CircleAvatar(
                    backgroundImage: const AssetImage('assets/images/prism.png'),
                    backgroundColor: Theme.of(context).primaryColor,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Row(
                          children: <Widget>[
                            Expanded(
                              child: Text(
                                notification.title,
                                style: TextStyle(
                                  color: Theme.of(context).colorScheme.secondary,
                                  fontWeight: FontWeight.w500,
                                  fontFamily: 'Proxima Nova',
                                ),
                              ),
                            ),
                            Text(
                              timeStr,
                              style: TextStyle(
                                fontSize: 12,
                                color: Theme.of(context).colorScheme.secondary.withValues(alpha: 0.8),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          notification.body,
                          style: TextStyle(fontSize: 12, color: Theme.of(context).colorScheme.secondary),
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
                    height: MediaQuery.of(context).size.width * 9 / 16,
                    child: CachedNetworkImage(
                      imageUrl: notification.imageUrl,
                      fit: BoxFit.cover,
                      placeholder: (_, _) => const Center(child: CircularProgressIndicator(strokeWidth: 2)),
                      errorWidget: (_, _, _) => const SizedBox.shrink(),
                    ),
                  ),
                ),
              ],
            ],
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
    return ClipRRect(
      borderRadius: const BorderRadius.only(topLeft: Radius.circular(20), topRight: Radius.circular(20)),
      child: Container(
        height: MediaQuery.of(context).size.height / 2.3 > 380 ? MediaQuery.of(context).size.height / 2.3 : 380,
        decoration: BoxDecoration(
          color: Theme.of(context).primaryColor,
          borderRadius: const BorderRadius.only(topLeft: Radius.circular(20), topRight: Radius.circular(20)),
        ),
        child: ListView(
          physics: const BouncingScrollPhysics(),
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: <Widget>[
                Padding(
                  padding: const EdgeInsets.all(12.0),
                  child: Container(
                    height: 5,
                    width: 30,
                    decoration: BoxDecoration(
                      color: Theme.of(context).hintColor,
                      borderRadius: BorderRadius.circular(500),
                    ),
                  ),
                ),
              ],
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Notification Settings',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: Theme.of(context).colorScheme.error == Colors.black
                        ? Colors.grey
                        : Theme.of(context).colorScheme.error,
                  ),
                ),
              ),
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
    return SwitchListTile(
      activeThumbColor: Theme.of(context).colorScheme.error,
      secondary: const Icon(JamIcons.user_plus),
      value: followersSubscriber ?? true,
      title: Text(
        'Followers',
        style: TextStyle(
          color: Theme.of(context).colorScheme.secondary,
          fontWeight: FontWeight.w500,
          fontFamily: 'Proxima Nova',
        ),
      ),
      subtitle: const Text('Get notifications for new followers.', style: TextStyle(fontSize: 12)),
      onChanged: (bool value) async {
        if (app_state.prismUser.loggedIn) {
          await _settingsLocal.set('followersSubscriber', value);
          setState(() => followersSubscriber = value);
          analytics.track(
            NotificationPreferenceChangedEvent(preference: NotificationPreferenceValue.followers, value: value),
          );
          if (value) {
            await subscribeToTopicSafely(
              home.f,
              app_state.prismUser.email.split('@')[0],
              sourceTag: 'notification.settings.followers.enable',
            );
          } else {
            await unsubscribeFromTopicSafely(
              home.f,
              app_state.prismUser.email.split('@')[0],
              sourceTag: 'notification.settings.followers.disable',
            );
            await _settingsLocal.set('postsSubscriber', false);
            setState(() => postsSubscriber = false);
            analytics.track(
              const NotificationPreferenceChangedEvent(preference: NotificationPreferenceValue.posts, value: false),
            );
            await unsubscribeFromTopicSafely(
              home.f,
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
          toasts.error('Please login to change this setting.');
        }
      },
    );
  }

  Widget _buildPostsToggle(BuildContext context) {
    return SwitchListTile(
      activeThumbColor: Theme.of(context).colorScheme.error,
      secondary: const Icon(JamIcons.pictures),
      value: postsSubscriber ?? true,
      title: Text(
        'Posts',
        style: TextStyle(
          color: Theme.of(context).colorScheme.secondary,
          fontWeight: FontWeight.w500,
          fontFamily: 'Proxima Nova',
        ),
      ),
      subtitle: const Text('Get notifications for posts from the artists you follow.', style: TextStyle(fontSize: 12)),
      onChanged: (followersSubscriber ?? true)
          ? (bool value) async {
              if (app_state.prismUser.loggedIn) {
                await _settingsLocal.set('postsSubscriber', value);
                setState(() => postsSubscriber = value);
                analytics.track(
                  NotificationPreferenceChangedEvent(preference: NotificationPreferenceValue.posts, value: value),
                );
                if (value) {
                  await subscribeToTopicSafely(home.f, 'posts', sourceTag: 'notification.settings.posts.enable');
                } else {
                  await unsubscribeFromTopicSafely(home.f, 'posts', sourceTag: 'notification.settings.posts.disable');
                }
              } else {
                analytics.track(
                  const NotificationActionBlockedEvent(
                    action: AnalyticsActionValue.notificationSettingsOpened,
                    reason: AnalyticsReasonValue.notSignedIn,
                  ),
                );
                toasts.error('Please login to change this setting.');
              }
            }
          : null,
    );
  }

  Widget _buildInAppToggle(BuildContext context) {
    return SwitchListTile(
      activeThumbColor: Theme.of(context).colorScheme.error,
      secondary: const Icon(JamIcons.picture),
      value: inappSubscriber ?? true,
      title: Text(
        'In-App',
        style: TextStyle(
          color: Theme.of(context).colorScheme.secondary,
          fontWeight: FontWeight.w500,
          fontFamily: 'Proxima Nova',
        ),
      ),
      subtitle: const Text(
        'Get in app notifications for giveaways, contests and reviews.',
        style: TextStyle(fontSize: 12),
      ),
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
    return SwitchListTile(
      activeThumbColor: Theme.of(context).colorScheme.error,
      secondary: const Icon(JamIcons.lightbulb),
      value: recommendationsSubscriber ?? true,
      title: Text(
        'Recommendations',
        style: TextStyle(
          color: Theme.of(context).colorScheme.secondary,
          fontWeight: FontWeight.w500,
          fontFamily: 'Proxima Nova',
        ),
      ),
      subtitle: const Text('Get recommendations from Prism.', style: TextStyle(fontSize: 12)),
      onChanged: (bool value) async {
        await _settingsLocal.set('recommendationsSubscriber', value);
        setState(() => recommendationsSubscriber = value);
        analytics.track(
          NotificationPreferenceChangedEvent(preference: NotificationPreferenceValue.recommendations, value: value),
        );
        if (value) {
          await subscribeToTopicSafely(
            home.f,
            'recommendations',
            sourceTag: 'notification.settings.recommendations.enable',
          );
        } else {
          await unsubscribeFromTopicSafely(
            home.f,
            'recommendations',
            sourceTag: 'notification.settings.recommendations.disable',
          );
        }
      },
    );
  }

  Widget _buildStreakToggle(BuildContext context) {
    return SwitchListTile(
      activeThumbColor: Theme.of(context).colorScheme.error,
      secondary: const Icon(Icons.local_fire_department_rounded),
      value: streakReminderSubscriber ?? true,
      title: Text(
        'Streak reminders',
        style: TextStyle(
          color: Theme.of(context).colorScheme.secondary,
          fontWeight: FontWeight.w500,
          fontFamily: 'Proxima Nova',
        ),
      ),
      subtitle: const Text('Get an 8 PM reminder if your login streak is at risk.', style: TextStyle(fontSize: 12)),
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
          toasts.error('Please login to change this setting.');
        }
      },
    );
  }
}
