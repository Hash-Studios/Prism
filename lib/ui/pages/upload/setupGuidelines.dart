import 'dart:io';
import 'dart:math';
import 'package:Prism/analytics/analytics_service.dart';
import 'package:Prism/global/svgAssets.dart';
import 'package:Prism/routes/routing_constants.dart';
import 'package:Prism/theme/jam_icons_icons.dart';
import 'package:Prism/theme/themeModel.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path/path.dart' as Path;
import 'package:Prism/routes/router.dart';
import 'package:flutter/material.dart';
import 'package:photo_view/photo_view.dart';
import 'package:Prism/data/upload/wallpaper/wallfirestore.dart' as WallStore;
import 'package:Prism/theme/toasts.dart' as toasts;
import 'package:Prism/main.dart' as main;
import 'package:Prism/theme/config.dart' as config;
import 'package:provider/provider.dart';

class SetupGuidelinesScreen extends StatefulWidget {
  const SetupGuidelinesScreen();

  @override
  _SetupGuidelinesScreenState createState() => _SetupGuidelinesScreenState();
}

class _SetupGuidelinesScreenState extends State<SetupGuidelinesScreen> {
  File _setup;

  final picker2 = ImagePicker();

  Future<bool> onWillPop() async {
    if (navStack.length > 1) navStack.removeLast();
    debugPrint(navStack.toString());
    return true;
  }

  Future getSetup() async {
    final pickedFile = await picker2.getImage(source: ImageSource.gallery);
    if (pickedFile != null) {
      setState(() {
        _setup = File(pickedFile.path);
      });
      Navigator.pop(context);
      if (navStack.length > 1) navStack.removeLast();
      debugPrint(navStack.toString());
      Future.delayed(const Duration()).then((value) =>
          Navigator.pushNamed(context, uploadSetupRoute, arguments: [_setup]));
    }
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: onWillPop,
      child: Scaffold(
          backgroundColor: Theme.of(context).primaryColor,
          appBar: AppBar(
            title: Text(
              "Upload Setup",
              style: TextStyle(color: Theme.of(context).accentColor),
            ),
          ),
          body: Column(
            children: [
              const Spacer(),
              SizedBox(
                width: MediaQuery.of(context).size.width,
                child: Provider.of<ThemeModel>(context, listen: false)
                            .returnThemeType() ==
                        "Dark"
                    ? SvgPicture.string(
                        setupDark.replaceAll(
                            "E57697",
                            main.prefs
                                .get("mainAccentColor")
                                .toRadixString(16)
                                .toString()
                                .substring(2)),
                      )
                    : SvgPicture.string(
                        setupLight.replaceAll(
                            "E57697",
                            main.prefs
                                .get("mainAccentColor")
                                .toRadixString(16)
                                .toString()
                                .substring(2)),
                      ),
              ),
              const Spacer(),
              Container(
                width: MediaQuery.of(context).size.width * 0.8,
                child: Text(
                  """
Guidelines for uploading setups -""",
                  textAlign: TextAlign.left,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                    color: Theme.of(context).accentColor,
                  ),
                ),
              ),
              Container(
                width: MediaQuery.of(context).size.width * 0.8,
                child: Text(
                  """
- Keep a screenshot of your homescreen setup ready.
- After you press the continue button below, you will be prompted to select this screenshot.
- Keep the name of wallpaper app / wallpaper link ready.
- You’ll also need a name, and description for the setup.
- Make sure you have connected your account to Twitter or Instagram, so that your audience on Prism can follow you there.""",
                  textAlign: TextAlign.left,
                  style: TextStyle(
                    fontSize: 14,
                    color: Theme.of(context).accentColor,
                  ),
                ),
              ),
              const Spacer(flex: 2),
            ],
          ),
          floatingActionButton: Padding(
            padding: const EdgeInsets.only(bottom: 50.0),
            child: FloatingActionButton.extended(
              backgroundColor: config.Colors().mainAccentColor(1),
              onPressed: () async => getSetup(),
              label: Text(
                "Continue",
                style: TextStyle(
                    color: Theme.of(context).accentColor,
                    fontWeight: FontWeight.normal),
              ),
              icon: Icon(
                JamIcons.arrow_right,
                color: Theme.of(context).accentColor,
              ),
            ),
          ),
          floatingActionButtonLocation:
              FloatingActionButtonLocation.centerFloat),
    );
  }
}
