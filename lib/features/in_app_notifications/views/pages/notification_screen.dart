import 'package:Prism/analytics/analytics_service.dart';
import 'package:Prism/core/analytics/events/events.dart';
import 'package:Prism/core/coins/coins_service.dart';
import 'package:Prism/core/router/app_router.dart';
import 'package:Prism/core/router/notification_route_mapper.dart';
import 'package:Prism/core/utils/url_launcher_compat.dart';
import 'package:Prism/data/notifications/model/inAppNotifModel.dart';
import 'package:Prism/features/category_feed/views/pages/home_screen.dart' as home;
import 'package:Prism/core/state/app_state.dart' as app_state;
import 'package:Prism/main.dart' as main;
import 'package:Prism/notifications/topic_subscription.dart';
import 'package:Prism/theme/jam_icons_icons.dart';
import 'package:Prism/theme/toasts.dart' as toasts;
import 'package:animations/animations.dart';
import 'package:auto_route/auto_route.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hive_io/hive_io.dart';
import 'package:intl/intl.dart';

@RoutePage()
class NotificationScreen extends StatefulWidget {
  @override
  _NotificationScreenState createState() => _NotificationScreenState();
}

class _NotificationScreenState extends State<NotificationScreen> {
  List<InAppNotif> notifications = [];
  final Box<InAppNotif> box = Hive.box('inAppNotifs');
  @override
  void initState() {
    notifications = box.values.toList();
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).primaryColor,
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: const Text("Notifications"),
        leading: IconButton(
          icon: const Icon(JamIcons.close),
          onPressed: () {
            context.router.maybePop();
          },
        ),
        actions: <Widget>[
          IconButton(
            tooltip: "Notification Settings",
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
                builder: (context) => NotificationSettingsSheet(),
              );
            },
          ),
        ],
      ),
      body: Container(
        child: notifications.isNotEmpty
            ? ListView.builder(
                itemCount: notifications.length,
                itemBuilder: (BuildContext context, int index) {
                  final InAppNotif currentNotification = notifications[index];
                  return Dismissible(
                    onDismissed: (DismissDirection direction) {
                      analytics.track(
                        NotificationItemDismissedEvent(
                          type: _notificationTypeFor(currentNotification),
                          dismissMode: DismissModeValue.swipe,
                        ),
                      );
                      setState(() {
                        notifications.removeAt(index);
                        box.deleteAt(index);
                      });
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
                    key: UniqueKey(),
                    child: NotificationCard(
                      notification: currentNotification,
                      onMarkRead: () {
                        box.put(
                          box.keys.toList()[index],
                          InAppNotif(
                            pageName: notifications[index].pageName,
                            title: notifications[index].title,
                            body: notifications[index].body,
                            imageUrl: notifications[index].imageUrl,
                            arguments: notifications[index].arguments,
                            url: notifications[index].url,
                            createdAt: notifications[index].createdAt,
                            read: true,
                            route: notifications[index].route,
                            wallId: notifications[index].wallId,
                          ),
                        );
                      },
                    ),
                  );
                },
              )
            : Center(
                child: Text('No new notifications', style: TextStyle(color: Theme.of(context).colorScheme.secondary)),
              ),
      ),
      floatingActionButton: notifications.isNotEmpty
          ? FloatingActionButton(
              mini: true,
              tooltip: "Clear Notifications",
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
                        setState(() {
                          notifications.clear();
                          box.clear();
                        });
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
  }
}

class NotificationCard extends StatelessWidget {
  const NotificationCard({required this.notification, this.onMarkRead});

  final InAppNotif? notification;
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
    var dateString = "";

    final diff = now.difference(dtInLocal);

    if (now.day == dtInLocal.day) {
      final todayFormat = DateFormat("h:mm a");
      dateString += todayFormat.format(dtInLocal);
    } else if ((diff.inDays) == 1 || (diff.inSeconds < 86400 && now.day != dtInLocal.day)) {
      final yesterdayFormat = DateFormat("h:mm a");
      dateString += "Yesterday, ${yesterdayFormat.format(dtInLocal)}";
    } else if (now.year == dtInLocal.year && diff.inDays > 1) {
      final monthFormat = DateFormat("MMM d");
      dateString += monthFormat.format(dtInLocal);
    } else {
      final yearFormat = DateFormat("MMM d y");
      dateString += yearFormat.format(dtInLocal);
    }

    return dateString;
  }

  Future<void> _onTap(BuildContext context) async {
    final InAppNotif n = notification!;
    onMarkRead?.call();
    analytics.track(
      NotificationItemOpenedEvent(
        type: _notificationTypeFor(n),
        destination: _destinationFor(n),
        hasExternalUrl: (n.url ?? "").isNotEmpty,
      ),
    );
    if ((n.url ?? "").trim().isNotEmpty) {
      await openPrismLink(context, n.url!);
      return;
    }
    final String route = (n.route ?? n.pageName ?? "").trim();
    final PageRouteInfo? mappedRoute = await _routeMapper.fromRoute(
      route: route,
      wallId: n.wallId,
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
    final bool showImage = _hasValidImageUrl(notification!.imageUrl);
    final String timeStr = notification!.createdAt != null ? stringForDatetime(notification!.createdAt!) : "";

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
                    backgroundImage: const AssetImage("assets/images/prism.png"),
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
                                notification!.title ?? "",
                                style: TextStyle(
                                  color: Theme.of(context).colorScheme.secondary,
                                  fontWeight: FontWeight.w500,
                                  fontFamily: "Proxima Nova",
                                ),
                              ),
                            ),
                            if (timeStr.isNotEmpty)
                              Text(
                                timeStr,
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Theme.of(context).colorScheme.secondary.withOpacity(0.8),
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          notification!.body ?? "",
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
                      imageUrl: notification!.imageUrl!,
                      fit: BoxFit.cover,
                      placeholder: (_, __) => const Center(child: CircularProgressIndicator(strokeWidth: 2)),
                      errorWidget: (_, __, ___) => const SizedBox.shrink(),
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

NotificationTypeValue _notificationTypeFor(InAppNotif notification) {
  if ((notification.url ?? "").isNotEmpty) {
    return NotificationTypeValue.externalUrl;
  }
  if ((notification.pageName ?? "").isNotEmpty) {
    return NotificationTypeValue.route;
  }
  return NotificationTypeValue.unknown;
}

String _destinationFor(InAppNotif notification) {
  if ((notification.url ?? "").isNotEmpty) {
    return notification.url!;
  }
  if ((notification.pageName ?? "").isNotEmpty) {
    return notification.pageName!;
  }
  return "";
}

class NotificationSettingsSheet extends StatefulWidget {
  @override
  _NotificationSettingsSheetState createState() => _NotificationSettingsSheetState();
}

class _NotificationSettingsSheetState extends State<NotificationSettingsSheet> {
  bool? followersSubscriber;
  bool? postsSubscriber;
  bool? inappSubscriber;
  bool? recommendationsSubscriber;
  bool? streakReminderSubscriber;
  @override
  void initState() {
    super.initState();
    followersSubscriber = main.prefs.get("followersSubscriber", defaultValue: true) as bool?;
    postsSubscriber = main.prefs.get("postsSubscriber", defaultValue: true) as bool?;
    inappSubscriber = main.prefs.get("inappSubscriber", defaultValue: true) as bool?;
    recommendationsSubscriber = main.prefs.get("recommendationsSubscriber", defaultValue: true) as bool?;
    streakReminderSubscriber = main.prefs.get("streakReminderSubscriber", defaultValue: true) as bool?;
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
              mainAxisSize: MainAxisSize.min,
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
            SwitchListTile(
              activeThumbColor: Theme.of(context).colorScheme.error,
              secondary: const Icon(JamIcons.user_plus),
              value: followersSubscriber!,
              title: Text(
                "Followers",
                style: TextStyle(
                  color: Theme.of(context).colorScheme.secondary,
                  fontWeight: FontWeight.w500,
                  fontFamily: "Proxima Nova",
                ),
              ),
              subtitle: const Text("Get notifications for new followers.", style: TextStyle(fontSize: 12)),
              onChanged: (bool value) async {
                if (app_state.prismUser.loggedIn == true) {
                  main.prefs.put("followersSubscriber", value);
                  setState(() {
                    followersSubscriber = value;
                  });
                  analytics.track(
                    NotificationPreferenceChangedEvent(preference: NotificationPreferenceValue.followers, value: value),
                  );
                  if (value) {
                    await subscribeToTopicSafely(
                      home.f,
                      app_state.prismUser.email.split("@")[0],
                      sourceTag: 'notification.settings.followers.enable',
                    );
                  } else {
                    await unsubscribeFromTopicSafely(
                      home.f,
                      app_state.prismUser.email.split("@")[0],
                      sourceTag: 'notification.settings.followers.disable',
                    );
                    main.prefs.put("postsSubscriber", value);
                    setState(() {
                      postsSubscriber = value;
                    });
                    analytics.track(
                      NotificationPreferenceChangedEvent(preference: NotificationPreferenceValue.posts, value: value),
                    );
                    await unsubscribeFromTopicSafely(
                      home.f,
                      'posts',
                      sourceTag: 'notification.settings.posts.disable_from_followers',
                    );
                  }
                } else {
                  analytics.track(
                    NotificationActionBlockedEvent(
                      action: AnalyticsActionValue.notificationSettingsOpened,
                      reason: AnalyticsReasonValue.notSignedIn,
                    ),
                  );
                  toasts.error("Please login to change this setting.");
                }
              },
            ),
            SwitchListTile(
              activeThumbColor: Theme.of(context).colorScheme.error,
              secondary: const Icon(JamIcons.pictures),
              value: postsSubscriber!,
              title: Text(
                "Posts",
                style: TextStyle(
                  color: Theme.of(context).colorScheme.secondary,
                  fontWeight: FontWeight.w500,
                  fontFamily: "Proxima Nova",
                ),
              ),
              subtitle: const Text(
                "Get notifications for posts from the artists you follow.",
                style: TextStyle(fontSize: 12),
              ),
              onChanged: followersSubscriber!
                  ? (bool value) async {
                      if (app_state.prismUser.loggedIn == true) {
                        main.prefs.put("postsSubscriber", value);
                        setState(() {
                          postsSubscriber = value;
                        });
                        analytics.track(
                          NotificationPreferenceChangedEvent(
                            preference: NotificationPreferenceValue.posts,
                            value: value,
                          ),
                        );
                        if (value) {
                          await subscribeToTopicSafely(
                            home.f,
                            'posts',
                            sourceTag: 'notification.settings.posts.enable',
                          );
                        } else {
                          await unsubscribeFromTopicSafely(
                            home.f,
                            'posts',
                            sourceTag: 'notification.settings.posts.disable',
                          );
                        }
                      } else {
                        analytics.track(
                          NotificationActionBlockedEvent(
                            action: AnalyticsActionValue.notificationSettingsOpened,
                            reason: AnalyticsReasonValue.notSignedIn,
                          ),
                        );
                        toasts.error("Please login to change this setting.");
                      }
                    }
                  : null,
            ),
            SwitchListTile(
              activeThumbColor: Theme.of(context).colorScheme.error,
              secondary: const Icon(JamIcons.picture),
              value: inappSubscriber!,
              title: Text(
                "In-App",
                style: TextStyle(
                  color: Theme.of(context).colorScheme.secondary,
                  fontWeight: FontWeight.w500,
                  fontFamily: "Proxima Nova",
                ),
              ),
              subtitle: const Text(
                "Get in app notifications for giveaways, contests and reviews.",
                style: TextStyle(fontSize: 12),
              ),
              onChanged: (bool value) async {
                main.prefs.put("inappSubscriber", value);
                setState(() {
                  inappSubscriber = value;
                });
                analytics.track(
                  NotificationPreferenceChangedEvent(preference: NotificationPreferenceValue.inApp, value: value),
                );
              },
            ),
            SwitchListTile(
              activeThumbColor: Theme.of(context).colorScheme.error,
              secondary: const Icon(JamIcons.lightbulb),
              value: recommendationsSubscriber!,
              title: Text(
                "Recommendations",
                style: TextStyle(
                  color: Theme.of(context).colorScheme.secondary,
                  fontWeight: FontWeight.w500,
                  fontFamily: "Proxima Nova",
                ),
              ),
              subtitle: const Text("Get recommendations from Prism.", style: TextStyle(fontSize: 12)),
              onChanged: (bool value) async {
                main.prefs.put("recommendationsSubscriber", value);
                setState(() {
                  recommendationsSubscriber = value;
                });
                analytics.track(
                  NotificationPreferenceChangedEvent(
                    preference: NotificationPreferenceValue.recommendations,
                    value: value,
                  ),
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
            ),
            SwitchListTile(
              activeThumbColor: Theme.of(context).colorScheme.error,
              secondary: const Icon(Icons.local_fire_department_rounded),
              value: streakReminderSubscriber ?? true,
              title: Text(
                "Streak reminders",
                style: TextStyle(
                  color: Theme.of(context).colorScheme.secondary,
                  fontWeight: FontWeight.w500,
                  fontFamily: "Proxima Nova",
                ),
              ),
              subtitle: const Text(
                "Get an 8 PM reminder if your login streak is at risk.",
                style: TextStyle(fontSize: 12),
              ),
              onChanged: (bool value) async {
                if (app_state.prismUser.loggedIn == true) {
                  main.prefs.put("streakReminderSubscriber", value);
                  setState(() {
                    streakReminderSubscriber = value;
                  });
                  analytics.track(
                    NotificationPreferenceChangedEvent(
                      preference: NotificationPreferenceValue.streakReminders,
                      value: value,
                    ),
                  );
                  await CoinsService.instance.setStreakReminderPreference(
                    value,
                    sourceTag: 'notification.settings.streak_reminders',
                  );
                } else {
                  analytics.track(
                    NotificationActionBlockedEvent(
                      action: AnalyticsActionValue.notificationSettingsOpened,
                      reason: AnalyticsReasonValue.notSignedIn,
                    ),
                  );
                  toasts.error("Please login to change this setting.");
                }
              },
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }
}
