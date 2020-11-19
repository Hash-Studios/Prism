import 'package:Prism/analytics/analytics_service.dart';
import 'package:Prism/theme/jam_icons_icons.dart';
import 'package:Prism/routes/routing_constants.dart';
import 'package:Prism/ui/widgets/popup/signInPopUp.dart';
import 'package:animations/animations.dart';
import 'package:device_info/device_info.dart';
import 'package:firebase_admob/firebase_admob.dart';
import 'package:flare_flutter/flare_actor.dart';
import 'package:flutter/material.dart';
import 'package:Prism/theme/toasts.dart' as toasts;
import 'package:flutter/services.dart';
import 'package:Prism/main.dart' as main;
import 'package:gallery_saver/gallery_saver.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:Prism/global/globals.dart' as globals;
import 'package:Prism/theme/config.dart' as config;

class DownloadButton extends StatefulWidget {
  final String link;
  final bool colorChanged;

  const DownloadButton({
    @required this.link,
    @required this.colorChanged,
    Key key,
  }) : super(key: key);

  @override
  _DownloadButtonState createState() => _DownloadButtonState();
}

class _DownloadButtonState extends State<DownloadButton> {
  bool isLoading;

  @override
  void initState() {
    isLoading = false;
    super.initState();
  }

  static const platform = MethodChannel('flutter.prism.set_wallpaper');

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () async {
        if (!isLoading) {
          if (main.prefs.get("isLoggedin") == true) {
            if (main.prefs.get("premium") == true) {
              onDownload();
            } else {
              showDownloadPopup(context, () {
                debugPrint("Download");
                onDownload();
              });
            }
          } else {
            showDownloadPopup(context, () {
              debugPrint("Download");
              onDownload();
            });
          }
        } else {
          toasts.error("Wait for download to complete!");
        }
      },
      child: Stack(
        children: [
          Container(
            decoration: BoxDecoration(
              color: Theme.of(context).primaryColor,
              boxShadow: [
                BoxShadow(
                    color: Colors.black.withOpacity(.25),
                    blurRadius: 4,
                    offset: const Offset(0, 4))
              ],
              borderRadius: BorderRadius.circular(500),
            ),
            padding: const EdgeInsets.all(17),
            child: Icon(
              JamIcons.download,
              color: Theme.of(context).accentColor,
              size: 20,
            ),
          ),
          Positioned(
              top: 0,
              left: 0,
              height: 53,
              width: 53,
              child:
                  isLoading ? const CircularProgressIndicator() : Container())
        ],
      ),
    );
  }

  void showPremiumPopUp(Function func) {
    if (main.prefs.get("premium") == false) {
      toasts.codeSend("Variants are a premium feature.");
      Navigator.pushNamed(context, premiumRoute);
    } else {
      func();
    }
  }

  Future<void> onDownload() async {
    final status = await Permission.storage.status;
    if (!status.isGranted) {
      await Permission.storage.request();
    }
    setState(() {
      isLoading = true;
    });
    debugPrint(widget.link);

    final androidInfo = await DeviceInfoPlugin().androidInfo;
    final sdkInt = androidInfo.version.sdkInt;
    debugPrint('(SDK $sdkInt)');
    toasts.codeSend("Starting Download");

    if (sdkInt >= 30) {
      await platform
          .invokeMethod('save_image', {"link": widget.link}).then((value) {
        if (value as bool) {
          analytics.logEvent(
              name: 'download_wallpaper', parameters: {'link': widget.link});
          toasts.codeSend("Wall Downloaded in Pictures/Prism!");
        } else {
          toasts.error("Couldn't download! Please Retry!");
        }
        setState(() {
          isLoading = false;
        });
      }).catchError((e) {
        debugPrint(e.toString());
        setState(() {
          isLoading = false;
        });
      });
    } else {
      GallerySaver.saveImage(widget.link, albumName: "Prism").then((value) {
        analytics.logEvent(
            name: 'download_wallpaper', parameters: {'link': widget.link});
        toasts.codeSend("Wall Downloaded in Internal Storage/Prism!");
        setState(() {
          isLoading = false;
        });
      }).catchError((e) {
        setState(() {
          isLoading = false;
        });
      });
    }
  }
}

void showDownloadPopup(BuildContext context, Function rewardFunc) {
  showModal(
      context: context,
      configuration: const FadeScaleTransitionConfiguration(),
      builder: (BuildContext context) => StatefulBuilder(
              builder: (BuildContext context, StateSetter setState) {
            return Dialog(
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20)),
              child: DownloadDialogContent(
                rewardFunc: rewardFunc,
              ),
            );
          }));
}

class DownloadDialogContent extends StatefulWidget {
  final Function rewardFunc;

  const DownloadDialogContent({@required this.rewardFunc});

  @override
  _DownloadDialogContentState createState() => _DownloadDialogContentState();
}

class _DownloadDialogContentState extends State<DownloadDialogContent> {
  int downloadCoins = 0;
  RewardedVideoAd videoAd = RewardedVideoAd.instance;
  static const MobileAdTargetingInfo targetingInfo = MobileAdTargetingInfo(
    testDevices: <String>[],
    keywords: <String>['Apps', 'Games', 'Mobile', 'Game'],
    nonPersonalizedAds: false,
  );

  void reward(int rewardAmount) {
    downloadCoins += rewardAmount;
    debugPrint("Coins : ${downloadCoins.toString()}");
  }

  @override
  void initState() {
    FirebaseAdMob.instance
        .initialize(appId: "ca-app-pub-4649644680694757~6175744196");
    videoAd.listener =
        (RewardedVideoAdEvent event, {String rewardType, int rewardAmount}) {
      debugPrint("REWARDED VIDEO AD $event");
      switch (event) {
        case RewardedVideoAdEvent.loaded:
          setState(() {
            globals.loadingAd = false;
          });
          break;
        case RewardedVideoAdEvent.failedToLoad:
          toasts.error("Failed to load ad");
          if (mounted) {
            Navigator.pop(context);
            widget.rewardFunc();
          }
          break;
        case RewardedVideoAdEvent.leftApplication:
          break;
        case RewardedVideoAdEvent.started:
          break;
        case RewardedVideoAdEvent.rewarded:
          reward(rewardAmount);
          break;
        case RewardedVideoAdEvent.closed:
          if (downloadCoins >= 10) widget.rewardFunc();
          break;
        case RewardedVideoAdEvent.opened:
        case RewardedVideoAdEvent.completed:
      }
    };
    videoAd.load(
        // adUnitId: RewardedVideoAd.testAdUnitId,
        adUnitId: "ca-app-pub-4649644680694757/3358009164",
        targetingInfo: targetingInfo);
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          color: Theme.of(context).primaryColor),
      width: MediaQuery.of(context).size.width * .78,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Container(
            height: 150,
            width: MediaQuery.of(context).size.width * .78,
            decoration: BoxDecoration(
                borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(20),
                    topRight: Radius.circular(20)),
                color: Theme.of(context).hintColor),
            child: const FlareActor(
              "assets/animations/Update.flr",
              animation: "update",
            ),
          ),
          Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              const SizedBox(
                height: 20,
              ),
              Row(
                children: [
                  const SizedBox(
                    width: 20,
                  ),
                  Container(
                    width: MediaQuery.of(context).size.width * 0.7,
                    child: Text(
                      "Watch a small video ad to download this wallpaper.",
                      style: Theme.of(context)
                          .textTheme
                          .headline6
                          .copyWith(color: Theme.of(context).accentColor),
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(
            height: 25,
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: <Widget>[
              FlatButton(
                shape: const StadiumBorder(),
                color: config.Colors().mainAccentColor(1),
                onPressed: () {
                  if (main.prefs.get("isLoggedin") == false) {
                    googleSignInPopUp(context, () {
                      Navigator.of(context).pop();
                      Navigator.pushNamed(context, premiumRoute);
                    });
                  } else {
                    Navigator.of(context).pop();
                    Navigator.pushNamed(context, premiumRoute);
                  }
                },
                child: Text(
                  'BUY PREMIUM',
                  style: TextStyle(
                    fontSize: 16.0,
                    color: Theme.of(context).accentColor,
                  ),
                ),
              ),
              FlatButton(
                shape: const StadiumBorder(),
                color: Theme.of(context).accentColor.withOpacity(0.3),
                onPressed: () {
                  globals.loadingAd
                      ? toasts.error("Loading ads")
                      : videoAd.show();
                  globals.loadingAd
                      ? debugPrint("")
                      : Navigator.of(context).pop();
                  setState(() {
                    globals.loadingAd
                        ? debugPrint("")
                        : globals.loadingAd = true;
                  });
                },
                child: !globals.loadingAd
                    ? Text(
                        'WATCH AD',
                        style: TextStyle(
                          fontSize: 16.0,
                          color: Theme.of(context).accentColor,
                        ),
                      )
                    : Stack(
                        alignment: Alignment.center,
                        children: <Widget>[
                          Text(
                            'WATCH AD',
                            style: TextStyle(
                              fontSize: 16.0,
                              color: Theme.of(context)
                                  .accentColor
                                  .withOpacity(0.3),
                            ),
                          ),
                          const CircularProgressIndicator(),
                        ],
                      ),
              ),
            ],
          ),
          const SizedBox(
            height: 15,
          ),
        ],
      ),
    );
  }
}
