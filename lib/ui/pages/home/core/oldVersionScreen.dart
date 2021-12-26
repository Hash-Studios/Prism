import 'package:Prism/global/globals.dart' as globals;
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

class OldVersion extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).primaryColor,
      appBar: AppBar(
        automaticallyImplyLeading: false,
        titleSpacing: 0,
        centerTitle: true,
        title: Text(
          "Update",
          style: Theme.of(context)
              .textTheme
              .headline3!
              .copyWith(color: Theme.of(context).accentColor),
        ),
      ),
      body: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: <Widget>[
          const Spacer(),
          Center(
              child: SizedBox(
            width: MediaQuery.of(context).size.width * 0.7,
            child: Text(
              "The version ${globals.currentAppVersion}+${globals.currentAppVersionCode} is obsolete and no longer supported. Please update the app to the latest version, to use it.",
              textAlign: TextAlign.center,
            ),
          )),
          const SizedBox(
            height: 16,
          ),
          ElevatedButton(
            onPressed: () async {
              launch(
                  "https://play.google.com/store/apps/details?id=com.hash.prism");
            },
            style: ButtonStyle(
              backgroundColor:
                  MaterialStateColor.resolveWith((states) => Colors.white),
            ),
            child: SizedBox(
              width: 60,
              child: const Text(
                'UPDATE',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Color(0xFFE57697),
                  fontSize: 15,
                  fontFamily: "Roboto",
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ),
          const Spacer(),
        ],
      ),
    );
  }
}
