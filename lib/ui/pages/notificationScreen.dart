import 'package:flutter/material.dart';
import 'package:Prism/routes/router.dart';
import 'package:Prism/data/notifications/model/notificationModel.dart';
import 'package:Prism/theme/jam_icons_icons.dart';
import 'package:cached_network_image/cached_network_image.dart';

class NotificationScreen extends StatefulWidget {
  @override
  _NotificationScreenState createState() => _NotificationScreenState();
}

class _NotificationScreenState extends State<NotificationScreen> {
  final List<NotifData> notifications = sampleNotificationData;
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).primaryColor,
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: Text("Notifications"),
        leading: IconButton(
          icon: Icon(JamIcons.close),
          onPressed: () {
            if (navStack.length > 1) navStack.removeLast();
            print(navStack);
            Navigator.pop(context);
          },
        ),
      ),
      body: Container(
        child: notifications.length > 0
            ? ListView.builder(
                itemCount: notifications.length,
                itemBuilder: (BuildContext context, int index) {
                  return Dismissible(
                    onDismissed: (DismissDirection direction) {
                      setState(() {
                        notifications.removeAt(index);
                      });
                    },
                    dismissThresholds: {
                      DismissDirection.startToEnd: 0.5,
                      DismissDirection.endToStart: 0.5
                    },
                    secondaryBackground: Container(
                      child: Align(
                        alignment: Alignment.centerRight,
                        child: Padding(
                          padding: const EdgeInsets.all(8.0),
                          child: Icon(JamIcons.trash),
                        ),
                      ),
                      color: Colors.red,
                    ),
                    background: Container(
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: Padding(
                          padding: const EdgeInsets.all(8.0),
                          child: Icon(JamIcons.trash),
                        ),
                      ),
                      color: Colors.red,
                    ),
                    child: NotificationCard(notification: notifications[index]),
                    key: UniqueKey(),
                    // direction: DismissDirection.endToStart,
                  );
                },
              )
            : Center(child: Text('No new notifications')),
      ),
    );
  }
}

class NotificationCard extends StatelessWidget {
  final NotifData notification;

  NotificationCard({this.notification});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Column(
        children: <Widget>[
          ExpansionTile(
            leading: CircleAvatar(
              backgroundImage: NetworkImage(notification.imageUrl),
            ),
            backgroundColor: Theme.of(context).primaryColor,
            title: Text(
              notification.title,
              style: TextStyle(
                  color: Theme.of(context).accentColor,
                  fontWeight: FontWeight.w500,
                  fontFamily: "Proxima Nova"),
            ),
            subtitle: Text(
              notification.desc,
              style:
                  TextStyle(fontSize: 12, color: Theme.of(context).accentColor),
            ),
            children: <Widget>[
              InkWell(
                child: Ink(
                  child: CachedNetworkImage(
                    imageUrl: notification.imageUrl,
                    fit: BoxFit.cover,
                  ),
                ),
                onTap: () {
                  Navigator.pushNamed(context, notification.pageName,
                      arguments: notification.arguments);
                },
              )
            ],
          )
        ],
      ),
    );
  }
}
