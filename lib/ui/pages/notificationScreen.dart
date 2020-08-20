import 'package:flutter/material.dart';
import 'package:Prism/routes/router.dart';
import 'package:Prism/data/notifications/model/notificationModel.dart';
import 'package:Prism/theme/jam_icons_icons.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:hive/hive.dart';

class NotificationScreen extends StatefulWidget {
  @override
  _NotificationScreenState createState() => _NotificationScreenState();
}

class _NotificationScreenState extends State<NotificationScreen> {
  List notifications;
  @override
  void initState() {
    Box<List> box = Hive.box('notifications');
    if (box.get('notifications') == [] || box.get('notifications') == null) {
      notifications = [];
    } else {
      notifications = box.get('notifications');
    }
    notifications = new List.from(notifications.reversed);
    super.initState();
  }

  Future<bool> onWillPop() async {
    if (navStack.length > 1) navStack.removeLast();
    print(navStack);
    return true;
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: onWillPop,
      child: Scaffold(
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
                        Box<List> box = Hive.box('notifications');
                        box.put('notifications', notifications);
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
                      child:
                          NotificationCard(notification: notifications[index]),
                      key: UniqueKey(),
                      // direction: DismissDirection.endToStart,
                    );
                  },
                )
              : Center(child: Text('No new notifications')),
        ),
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
              backgroundImage: NetworkImage(notification.imageUrl ??
                  "https://thelifedesigncourse.com/wp-content/uploads/2019/05/orange-waves-background-fluid-gradient-vector-21996148.jpg"),
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
                    imageUrl: notification.imageUrl ??
                        "https://thelifedesigncourse.com/wp-content/uploads/2019/05/orange-waves-background-fluid-gradient-vector-21996148.jpg",
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
