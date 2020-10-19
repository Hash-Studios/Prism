import 'dart:io';
import 'package:Prism/routes/routing_constants.dart';
import 'package:Prism/theme/jam_icons_icons.dart';
import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:Prism/theme/config.dart' as config;

class DownloadList extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return ExpansionTile(
        leading: Icon(
          JamIcons.download,
        ),
        title: new Text(
          "Downloads",
          style: TextStyle(
              color: Theme.of(context).accentColor,
              fontWeight: FontWeight.w500,
              fontFamily: "Proxima Nova"),
        ),
        subtitle: Text(
          "View or clear downloads",
          style: TextStyle(fontSize: 12, color: Theme.of(context).accentColor),
        ),
        children: [
          ListTile(
            onTap: () {
              Navigator.pushNamed(context, DownloadRoute);
            },
            leading: Icon(JamIcons.download),
            title: Text(
              "My Downloads",
              style: TextStyle(
                  color: Theme.of(context).accentColor,
                  fontWeight: FontWeight.w500,
                  fontFamily: "Proxima Nova"),
            ),
            subtitle: Text(
              "See all your downloaded wallpapers",
              style: TextStyle(fontSize: 12),
            ),
            trailing: Icon(JamIcons.chevron_right),
          ),
          ListTile(
              leading: Icon(
                JamIcons.database,
              ),
              title: new Text(
                "Clear Downloads",
                style: TextStyle(
                    color: Theme.of(context).accentColor,
                    fontWeight: FontWeight.w500,
                    fontFamily: "Proxima Nova"),
              ),
              subtitle: Text(
                "Clear downloaded wallpapers",
                style: TextStyle(fontSize: 12),
              ),
              onTap: () async {
                showDialog(
                  context: context,
                  child: AlertDialog(
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.all(
                        Radius.circular(20),
                      ),
                    ),
                    content: Container(
                      height: 50,
                      width: 250,
                      child: Center(
                        child: Text(
                          "Do you want remove all your downloads?",
                          style: Theme.of(context).textTheme.headline4,
                        ),
                      ),
                    ),
                    actions: <Widget>[
                      FlatButton(
                        shape: StadiumBorder(),
                        onPressed: () async {
                          Navigator.of(context).pop();
                          final dir = Directory("storage/emulated/0/Prism/");
                          var status = await Permission.storage.status;
                          if (!status.isGranted) {
                            await Permission.storage.request();
                          }
                          try {
                            dir.deleteSync(recursive: true);
                            Fluttertoast.showToast(
                                msg: "Deleted all downloads!",
                                toastLength: Toast.LENGTH_LONG,
                                timeInSecForIosWeb: 1,
                                textColor: Colors.white,
                                backgroundColor: Colors.green[400],
                                fontSize: 16.0);
                          } catch (e) {
                            Fluttertoast.showToast(
                                msg: "No downloads!",
                                toastLength: Toast.LENGTH_LONG,
                                timeInSecForIosWeb: 1,
                                textColor: Colors.white,
                                backgroundColor: Colors.red[400],
                                fontSize: 16.0);
                          }
                        },
                        child: Text(
                          'YES',
                          style: TextStyle(
                            fontSize: 16.0,
                            color: config.Colors().mainAccentColor(1),
                          ),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.only(right: 8.0),
                        child: FlatButton(
                          shape: StadiumBorder(),
                          color: config.Colors().mainAccentColor(1),
                          onPressed: () {
                            Navigator.of(context).pop();
                          },
                          child: Text(
                            'NO',
                            style: TextStyle(
                              fontSize: 16.0,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              }),
        ]);
  }
}
