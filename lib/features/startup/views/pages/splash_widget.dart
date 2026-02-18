import 'dart:convert';

import 'package:Prism/core/router/app_router.dart';
import 'package:Prism/data/categories/categories.dart';
import 'package:Prism/data/notifications/notifications.dart';
import 'package:Prism/features/startup/views/pages/old_version_screen.dart';
import 'package:Prism/global/globals.dart' as globals;
import 'package:Prism/logger/logger.dart';
import 'package:Prism/main.dart' as main;
import 'package:Prism/theme/config.dart' as config;
import 'package:auto_route/auto_route.dart';
import 'package:firebase_remote_config/firebase_remote_config.dart';
import 'package:flutter/material.dart';

late FirebaseRemoteConfig remoteConfig;

@RoutePage(name: 'SplashWidgetRoute')
class SplashWidget extends StatefulWidget {
  const SplashWidget({
    super.key,
  });

  @override
  _SplashWidgetState createState() => _SplashWidgetState();
}

class _SplashWidgetState extends State<SplashWidget> {
  bool notchChecked = false;
  bool _navigated = false;
  late Future<bool> _future;

  @override
  void initState() {
    super.initState();
    _future = loading();
  }

  Future<bool> loading() async {
    try {
      remoteConfig = FirebaseRemoteConfig.instance;
      await remoteConfig.setConfigSettings(
        RemoteConfigSettings(
          fetchTimeout: const Duration(seconds: 30),
          minimumFetchInterval: const Duration(hours: 6),
        ),
      );
      await remoteConfig.setDefaults(<String, dynamic>{
        'topImageLink':
            'https://firebasestorage.googleapis.com/v0/b/prism-wallpapers.appspot.com/o/Replacement%20Thumbnails%2Fpost%20bg.png?alt=media&token=d708b5e3-a7ee-421b-beae-3b10946678c4',
        'bannerText': "Join our Telegram",
        'bannerTextOn': globals.bannerTextOn,
        'bannerURL': "https://t.me/PrismWallpapers",
        'latestCategories': categories.toString(),
        'currentVersion': globals.currentAppVersion,
        'obsoleteVersion': globals.obsoleteAppVersion,
        'versionDesc':
            "Prism Premium is here, for the personalisaton lords!^*^Setups are here! Change the way of personalisation.^*^Favourites moved to profile.",
        'topTitleText': '["TOP-RATED","BEST OF COMMUNITY","FAN-FAVOURITE","TRENDING",]',
        'premiumCollections': '["space","landscapes","mesh gradients",]',
        'verifiedUsers': '["akshaymaurya3006@gmail.com","maurya.abhay30@gmail.com",]'
      });
      logger.d("Started Fetching Values from rc");
      await remoteConfig.fetch();
      await remoteConfig.activate();
      logger.d("Fetched Values from rc");
      globals.topImageLink = remoteConfig.getString('topImageLink');
      globals.bannerText = remoteConfig.getString('bannerText');
      globals.bannerTextOn = remoteConfig.getString('bannerTextOn');
      globals.bannerURL = remoteConfig.getString('bannerURL');
      globals.obsoleteAppVersion = remoteConfig.getString('obsoleteVersion');
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
      var tempVar = remoteConfig.getString('latestCategories').replaceAll('[', "").replaceAll(']', "").split("},");
      tempVar = tempVar.sublist(0, tempVar.length - 1);
      categories = [];
      for (final element in tempVar) {
        cList.add(element.split('"name": "')[1].split('",')[0]);
        categories.add(json.decode("$element}"));
      }
      categories.removeWhere((element) => element['name'] == "Trending");
      logger.d(cList.toString());
      globals.followersTab = main.prefs.get('followersTab', defaultValue: true) as bool;
      await getNotifs();
      logger.d("splash done");
      logger.d("Current App Version: ${globals.currentAppVersion.replaceAll(".", "")}");
      logger.d("Obsolete App Version: ${globals.obsoleteAppVersion.replaceAll(".", "")}");
      return true;
    } catch (e) {
      logger.d(e.toString());
    }
    return false;
  }

  void checkNotch(BuildContext context) {
    final height = MediaQuery.of(context).padding.top;
    globals.hasNotch = height > 24;
    globals.notchSize = height;
    notchChecked = true;
    logger.d('Notch Height = $height');
  }

  @override
  Widget build(BuildContext context) {
    if (!notchChecked) {
      checkNotch(context);
    }
    return FutureBuilder(
      future: _future,
      builder: (BuildContext context, AsyncSnapshot snapshot) {
        if (snapshot.hasData) {
          if ((int.parse(globals.currentAppVersion.replaceAll(".", "")) <
                  int.parse(globals.obsoleteAppVersion.replaceAll(".", ""))) ==
              true) {
            return OldVersion();
          }
          // Check if onboarded, then navigate to dashboard
          if (!_navigated) {
            _navigated = true;
            final isOnboarded = (main.prefs.get('onboarded_new') as bool?) ?? false;
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted) {
                if (isOnboarded) {
                  context.router.replaceAll([const DashboardRoute()]);
                } else {
                  context.router.replaceAll([const OnboardingRoute()]);
                }
              }
            });
          }
          return const SecondarySplash();
        }
        return const SecondarySplash();
      },
    );
  }
}

class SecondarySplash extends StatelessWidget {
  const SecondarySplash({
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    final brightness = MediaQuery.platformBrightnessOf(context);
    final bool darkModeOn = brightness == Brightness.dark;
    return Container(
      width: MediaQuery.of(context).size.width,
      height: MediaQuery.of(context).size.height,
      color: darkModeOn ? config.Colors().mainDarkColor(1) : config.Colors().mainColor(1),
      child: Center(
        child: Container(
          width: MediaQuery.of(context).size.width * 0.29074074074,
          height: MediaQuery.of(context).size.width * 0.29074074074,
          decoration: const BoxDecoration(
              image: DecorationImage(image: AssetImage("assets/images/ic_launcher.png"), fit: BoxFit.cover)),
        ),
      ),
    );
  }
}
