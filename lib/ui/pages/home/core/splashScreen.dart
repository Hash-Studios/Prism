import 'dart:convert';
import 'package:Prism/data/categories/categories.dart';
import 'package:Prism/theme/themeModel.dart';
import 'package:Prism/ui/pages/home/core/pageManager.dart';
import 'package:firebase_remote_config/firebase_remote_config.dart';
import 'package:flutter/material.dart';
import 'package:flare_splash_screen/flare_splash_screen.dart';
import 'package:Prism/theme/theme.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:Prism/global/globals.dart' as globals;
import 'package:Prism/theme/config.dart' as config;
import 'package:Prism/main.dart' as main;

RemoteConfig remoteConfig;

class SplashWidget extends StatelessWidget {
  bool notchChecked = false;
  Future<void> rcInit() async {
    remoteConfig = await RemoteConfig.instance;
    await remoteConfig.setConfigSettings(RemoteConfigSettings());
    await remoteConfig.setDefaults(<String, dynamic>{
      'topImageLink':
          'https://firebasestorage.googleapis.com/v0/b/prism-wallpapers.appspot.com/o/Replacement%20Thumbnails%2Fpost%20bg.png?alt=media&token=d708b5e3-a7ee-421b-beae-3b10946678c4',
      'bannerText': "Join our Telegram",
      'bannerURL': "https://t.me/PrismWallpapers",
      'newCategories': categories.toString(),
      'currentVersion': globals.currentAppVersion.toString(),
      'versionDesc':
          "Prism Premium is here, for the personalisaton lords!^*^Setups are here! Change the way of personalisation.^*^Favourites moved to profile.",
      'topTitleText':
          '["TOP-RATED","BEST OF COMMUNITY","FAN-FAVOURITE","TRENDING",]',
      'premiumCollections': '["space","landscapes","mesh gradients",]',
      'verifiedUsers':
          '["akshaymaurya3006@gmail.com","maurya.abhay30@gmail.com",]'
    });
    debugPrint("Started Fetching Values from rc");
    await remoteConfig.fetch(expiration: const Duration(hours: 6));
    await remoteConfig.activateFetched();
    debugPrint("Fetched Values from rc");
    globals.topImageLink = remoteConfig.getString('topImageLink');
    globals.bannerText = remoteConfig.getString('bannerText');
    globals.bannerURL = remoteConfig.getString('bannerURL');
    var verifiedU = remoteConfig.getString('verifiedUsers');
    verifiedU = verifiedU.replaceAll('"', '');
    verifiedU = verifiedU.replaceAll("[", "");
    verifiedU = verifiedU.replaceAll(",]", "");
    globals.verifiedUsers = verifiedU.split(",");
    var premiumC = remoteConfig.getString('premiumCollections');
    premiumC = premiumC.replaceAll('"', '');
    premiumC = premiumC.replaceAll("[", "");
    premiumC = premiumC.replaceAll(",]", "");
    globals.premiumCollections = premiumC.split(",");
    var text = remoteConfig.getString('topTitleText');
    text = text.replaceAll('"', '');
    text = text.replaceAll("[", "");
    text = text.replaceAll(",]", "");
    globals.topTitleText = text.split(",");
    globals.topTitleText.shuffle();
    final cList = [];
    var tempVar = remoteConfig
        .getString('newCategories')
        .replaceAll('[', "")
        .replaceAll(']', "")
        .split("},");
    tempVar = tempVar.sublist(0, tempVar.length - 1);
    tempVar.forEach((element) {
      cList.add(element.split('"name": "')[1].split('",')[0].toString());
      categories[tempVar.indexOf(element)] = json.decode("$element}");
    });
    debugPrint(cList.toString());
  }

  void checkNotch(BuildContext ctx) {
    final height = MediaQuery.of(ctx).padding.top;
    bool hasNotch;
    if (height > 24) {
      hasNotch = true;
    } else {
      hasNotch = false;
    }
    notchChecked = true;
    main.prefs.put('hasNotch', hasNotch);
    debugPrint('notch checked $hasNotch');
  }

  SplashWidget({
    Key key,
  }) : super(key: key);
  @override
  Widget build(BuildContext context) {
    if (!notchChecked) {
      Future.delayed(const Duration(seconds: 0), () => checkNotch(context));
    }
    SystemChrome.setEnabledSystemUIOverlays([]);
    return SplashScreen(
      'assets/animations/Prism Splash.flr',
      (context) {
        debugPrint("splash done");
        return PageManager();
      },
      startAnimation:
          Provider.of<ThemeModel>(context).currentTheme == kLightTheme
              ? 'Main'
              : 'Dark',
      backgroundColor:
          Provider.of<ThemeModel>(context).currentTheme == kLightTheme
              ? config.Colors().mainColor(1)
              : config.Colors().mainDarkColor(1),
      until: rcInit,
    );
  }
}
