import 'package:Prism/auth/google_auth.dart';
import 'package:Prism/features/favourite_setups/views/favourite_setups_bloc_adapter.dart';
import 'package:Prism/features/favourite_walls/views/favourite_walls_bloc_adapter.dart';
import 'package:Prism/global/globals.dart' as globals;
import 'package:Prism/logger/logger.dart';
import 'package:Prism/main.dart' as main;
import 'package:Prism/theme/jam_icons_icons.dart';
import 'package:Prism/theme/toasts.dart' as toasts;
import 'package:animations/animations.dart';
import 'package:flutter/material.dart';

class UserList extends StatelessWidget {
  final bool expanded;
  const UserList({required this.expanded});
  @override
  Widget build(BuildContext context) {
    if (globals.prismUser.loggedIn == false) {
      return ListTile(
        onTap: () {
          final Dialog loaderDialog = Dialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            child: Container(
              decoration: BoxDecoration(borderRadius: BorderRadius.circular(10), color: Theme.of(context).primaryColor),
              width: MediaQuery.of(context).size.width * .7,
              height: MediaQuery.of(context).size.height * .3,
              child: const Center(child: CircularProgressIndicator()),
            ),
          );
          if (globals.prismUser.loggedIn == false) {
            showDialog(barrierDismissible: false, context: context, builder: (BuildContext context) => loaderDialog);
            globals.gAuth.signInWithGoogle().then((value) {
              if (!context.mounted) {
                return;
              }
              if (value == GoogleAuth.signInCancelledResult) {
                Navigator.pop(context);
                globals.prismUser.loggedIn = false;
                main.prefs.put(main.userHiveKey, globals.prismUser);
                toasts.codeSend("Sign in cancelled.");
                return;
              }
              toasts.codeSend("Login Successful!");
              globals.prismUser.loggedIn = true;
              main.prefs.put(main.userHiveKey, globals.prismUser);
              Navigator.pop(context);
              main.RestartWidget.restartApp(context);
            }).catchError((e) {
              if (!context.mounted) {
                return;
              }
              logger.d(e.toString());
              Navigator.pop(context);
              globals.prismUser.loggedIn = false;
              main.prefs.put(main.userHiveKey, globals.prismUser);
              toasts.error("Something went wrong, please try again!");
            });
          } else {
            main.RestartWidget.restartApp(context);
          }
        },
        leading: const Icon(JamIcons.log_in),
        title: Text(
          "Sign in",
          style: TextStyle(
            color: Theme.of(context).colorScheme.secondary,
            fontWeight: FontWeight.w500,
            fontFamily: "Proxima Nova",
          ),
        ),
        subtitle: const Text("Sign in to sync data across devices", style: TextStyle(fontSize: 12)),
      );
    } else {
      return ExpansionTile(
        initiallyExpanded: expanded,
        leading: const Icon(JamIcons.user_circle),
        title: Text(
          "User",
          style: TextStyle(
            color: Theme.of(context).colorScheme.secondary,
            fontWeight: FontWeight.w500,
            fontFamily: "Proxima Nova",
          ),
        ),
        subtitle: Text(
          globals.prismUser.loggedIn == true ? "Clear favorites or logout" : "Login with Google",
          style: TextStyle(fontSize: 12, color: Theme.of(context).colorScheme.secondary),
        ),
        children: <Widget>[
          if (globals.prismUser.loggedIn == true)
            Column(
              children: [
                ListTile(
                  leading: const Icon(JamIcons.heart),
                  title: Text(
                    "Clear favourite walls",
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.secondary,
                      fontWeight: FontWeight.w500,
                      fontFamily: "Proxima Nova",
                    ),
                  ),
                  subtitle: const Text("Remove all favourite wallpapers", style: TextStyle(fontSize: 12)),
                  onTap: () async {
                    showModal(
                      context: context,
                      builder: (context) => AlertDialog(
                        shape: const RoundedRectangleBorder(borderRadius: BorderRadius.all(Radius.circular(10))),
                        content: SizedBox(
                          height: 50,
                          width: 250,
                          child: Center(
                            child: Text(
                              "Do you want remove all your favourite wallpapers?",
                              style: Theme.of(context).textTheme.headlineMedium,
                            ),
                          ),
                        ),
                        actions: <Widget>[
                          MaterialButton(
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(5)),
                            onPressed: () {
                              Navigator.of(context).pop();
                              toasts.error("Cleared all favourite wallpapers!");
                              context.favouriteWallsAdapter(listen: false).deleteData();
                            },
                            child: Text(
                              'YES',
                              style: TextStyle(fontSize: 16.0, color: Theme.of(context).colorScheme.error),
                            ),
                          ),
                          Padding(
                            padding: const EdgeInsets.only(right: 8.0),
                            child: MaterialButton(
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(5)),
                              color: Theme.of(context).colorScheme.error,
                              onPressed: () {
                                Navigator.of(context).pop();
                              },
                              child: const Text('NO', style: TextStyle(fontSize: 16.0, color: Colors.white)),
                            ),
                          ),
                        ],
                        backgroundColor: Theme.of(context).primaryColor,
                      ),
                    );
                  },
                ),
                ListTile(
                  leading: const Icon(JamIcons.heart),
                  title: Text(
                    "Clear favourite setups",
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.secondary,
                      fontWeight: FontWeight.w500,
                      fontFamily: "Proxima Nova",
                    ),
                  ),
                  subtitle: const Text("Remove all favourite setups", style: TextStyle(fontSize: 12)),
                  onTap: () async {
                    showModal(
                      context: context,
                      builder: (context) => AlertDialog(
                        shape: const RoundedRectangleBorder(borderRadius: BorderRadius.all(Radius.circular(10))),
                        content: SizedBox(
                          height: 50,
                          width: 250,
                          child: Center(
                            child: Text(
                              "Do you want remove all your favourite setups?",
                              style: Theme.of(context).textTheme.headlineMedium,
                            ),
                          ),
                        ),
                        actions: <Widget>[
                          MaterialButton(
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(5)),
                            onPressed: () {
                              Navigator.of(context).pop();
                              toasts.error("Cleared all favourite setups!");
                              context.favouriteSetupsAdapter(listen: false).deleteData();
                            },
                            child: Text(
                              'YES',
                              style: TextStyle(fontSize: 16.0, color: Theme.of(context).colorScheme.error),
                            ),
                          ),
                          Padding(
                            padding: const EdgeInsets.only(right: 8.0),
                            child: MaterialButton(
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(5)),
                              color: Theme.of(context).colorScheme.error,
                              onPressed: () {
                                Navigator.of(context).pop();
                              },
                              child: const Text('NO', style: TextStyle(fontSize: 16.0, color: Colors.white)),
                            ),
                          ),
                        ],
                        backgroundColor: Theme.of(context).primaryColor,
                      ),
                    );
                  },
                ),
                ListTile(
                  leading: const Icon(JamIcons.log_out),
                  title: Text(
                    "Logout",
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.secondary,
                      fontWeight: FontWeight.w500,
                      fontFamily: "Proxima Nova",
                    ),
                  ),
                  subtitle: Text(globals.prismUser.email, style: const TextStyle(fontSize: 12)),
                  onTap: () {
                    globals.gAuth.signOutGoogle();
                    toasts.codeSend("Log out Successful!");
                    main.RestartWidget.restartApp(context);
                  },
                ),
              ],
            )
          else
            Container(),
        ],
      );
    }
  }
}
