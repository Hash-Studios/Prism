import 'package:Prism/data/favourites/provider/favouriteProvider.dart';
import 'package:Prism/theme/jam_icons_icons.dart';
import 'package:flutter/material.dart';
import 'package:Prism/main.dart' as main;
import 'package:Prism/global/globals.dart' as globals;
import 'package:Prism/theme/toasts.dart' as toasts;
import 'package:provider/provider.dart';

class UserList extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Column(
      children: <Widget>[
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: Align(
            alignment: Alignment.centerLeft,
            child: Text(
              'User',
              style: TextStyle(
                fontSize: 14,
                color: Theme.of(context).accentColor,
              ),
            ),
          ),
        ),
        main.prefs.get("isLoggedin") == false
            ? ListTile(
                onTap: () {
                  Dialog loaderDialog = Dialog(
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20)),
                    child: Container(
                      decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(20),
                          color: Theme.of(context).primaryColor),
                      width: MediaQuery.of(context).size.width * .7,
                      height: MediaQuery.of(context).size.height * .3,
                      child: Center(
                        child: CircularProgressIndicator(),
                      ),
                    ),
                  );
                  if (!main.prefs.get("isLoggedin")) {
                    showDialog(
                        barrierDismissible: false,
                        context: context,
                        builder: (BuildContext context) => loaderDialog);
                    globals.gAuth.signInWithGoogle().then((value) {
                      toasts.codeSend("Login Successful!");
                      main.prefs.put("isLoggedin", true);
                      Navigator.pop(context);
                      main.RestartWidget.restartApp(context);
                    }).catchError((e) {
                      print(e);
                      Navigator.pop(context);
                      main.prefs.put("isLoggedin", false);
                      toasts.error("Something went wrong, please try again!");
                    });
                  } else {
                    main.RestartWidget.restartApp(context);
                  }
                },
                leading: Icon(JamIcons.log_in),
                title: Text(
                  "Log in",
                  style: TextStyle(
                      color: Theme.of(context).accentColor,
                      fontWeight: FontWeight.w500,
                      fontFamily: "Proxima Nova"),
                ),
                subtitle: Text(
                  "Log in to sync data across devices",
                  style: TextStyle(fontSize: 12),
                ),
              )
            : Container(),
        main.prefs.get("isLoggedin")
            ? Column(
                children: [
                  ListTile(
                      leading: Icon(
                        JamIcons.heart,
                      ),
                      title: new Text(
                        "Clear favourites",
                        style: TextStyle(
                            color: Theme.of(context).accentColor,
                            fontWeight: FontWeight.w500,
                            fontFamily: "Proxima Nova"),
                      ),
                      subtitle: Text(
                        "Remove all favourites",
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
                                  "Do you want remove all your favourites?",
                                  style: Theme.of(context).textTheme.headline4,
                                ),
                              ),
                            ),
                            actions: <Widget>[
                              FlatButton(
                                shape: StadiumBorder(),
                                onPressed: () {
                                  Navigator.of(context).pop();
                                  toasts.error("Cleared all favourites!");
                                  Provider.of<FavouriteProvider>(context,
                                          listen: false)
                                      .deleteData();
                                },
                                child: Text(
                                  'YES',
                                  style: TextStyle(
                                    fontSize: 16.0,
                                    color: Color(0xFFE57697),
                                  ),
                                ),
                              ),
                              Padding(
                                padding: const EdgeInsets.only(right: 8.0),
                                child: FlatButton(
                                  shape: StadiumBorder(),
                                  color: Color(0xFFE57697),
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
                  ListTile(
                      leading: Icon(
                        JamIcons.log_out,
                      ),
                      title: new Text(
                        "Logout",
                        style: TextStyle(
                            color: Theme.of(context).accentColor,
                            fontWeight: FontWeight.w500,
                            fontFamily: "Proxima Nova"),
                      ),
                      subtitle: Text(
                        main.prefs.get("email"),
                        style: TextStyle(fontSize: 12),
                      ),
                      onTap: () {
                        globals.gAuth.signOutGoogle();
                        toasts.codeSend("Log out Successful!");
                        main.RestartWidget.restartApp(context);
                      }),
                ],
              )
            : Container(),
      ],
    );
  }
}
