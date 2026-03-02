import 'package:Prism/core/utils/url_launcher_compat.dart';
import 'package:Prism/core/state/app_state.dart' as app_state;
import 'package:flutter/material.dart';

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
          style: Theme.of(context).textTheme.displaySmall!.copyWith(color: Theme.of(context).colorScheme.secondary),
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
                "The version ${app_state.currentAppVersion}+${app_state.currentAppVersionCode} is obsolete and no longer supported. Please update the app to the latest version, to use it.",
                textAlign: TextAlign.center,
              ),
            ),
          ),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: () async {
              openPrismLink(context, "https://play.google.com/store/apps/details?id=com.hash.prism");
            },
            style: ButtonStyle(backgroundColor: WidgetStateColor.resolveWith((states) => Colors.white)),
            child: const SizedBox(
              width: 60,
              child: Text(
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
