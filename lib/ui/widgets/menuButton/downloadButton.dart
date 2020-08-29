import 'package:Prism/analytics/analytics_service.dart';
import 'package:Prism/theme/jam_icons_icons.dart';
import 'package:Prism/routes/routing_constants.dart';
import 'package:Prism/ui/widgets/popup/signInPopUp.dart';
// import 'package:Prism/ui/widgets/popup/proPopUp.dart';
import 'package:firebase_admob/firebase_admob.dart';
import 'package:flare_flutter/flare_actor.dart';
import 'package:flutter/material.dart';
import 'package:Prism/theme/toasts.dart' as toasts;
import 'package:gallery_saver/gallery_saver.dart';
import 'package:Prism/main.dart' as main;
import 'package:permission_handler/permission_handler.dart';
import 'package:Prism/global/globals.dart' as globals;

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

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () async {
        // if (!widget.colorChanged) {
        if (main.prefs.get("isLoggedin")) {
          if (main.prefs.get("premium")) {
            onDownload();
          } else {
            showDownloadPopup(context, () {
              print("Download");
              onDownload();
            });
          }
        } else {
          showDownloadPopup(context, () {
            print("Download");
            onDownload();
          });
        }
        // } else {
        //   showPremiumPopUp(() async {
        //     print("Download");
        //     onDownload();
        //   });
        // }
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
                    offset: Offset(0, 4))
              ],
              borderRadius: BorderRadius.circular(500),
            ),
            padding: EdgeInsets.all(17),
            child: Icon(
              JamIcons.download,
              color: Theme.of(context).accentColor,
              size: 30,
            ),
          ),
          Positioned(
              top: 0,
              left: 0,
              height: 63,
              width: 63,
              child: isLoading ? CircularProgressIndicator() : Container())
        ],
      ),
    );
  }

  void showPremiumPopUp(Function func) {
    if (!main.prefs.get("premium")) {
      toasts.codeSend("Variants are a premium feature.");
      Navigator.pushNamed(context, PremiumRoute);
      // premiumPopUp(context, func);
    } else {
      func();
    }
  }

  void onDownload() async {
    // if (widget.colorChanged) {
    //   showPremiumPopUp(() async {
    //     var status = await Permission.storage.status;
    //     if (!status.isGranted) {
    //       await Permission.storage.request();
    //     }
    //     setState(() {
    //       isLoading = true;
    //     });
    //     print(widget.link);
    //     toasts.codeSend("Starting Download");
    //     Future.delayed(Duration(seconds: 2)).then(
    //       (value) => GallerySaver.saveImage(widget.link, albumName: "Prism")
    //           .then((value) {
    //         analytics.logEvent(
    //             name: 'download_wallpaper', parameters: {'link': widget.link});
    //         toasts.codeSend("Image Downloaded in Pictures/Prism!");
    //         setState(() {
    //           isLoading = false;
    //         });
    //       }).catchError(
    //         (e) {
    //           // toasts.error(e.toString());
    //           setState(
    //             () {
    //               isLoading = false;
    //             },
    //           );
    //         },
    //       ),
    //     );
    //   });
    // } else {
    var status = await Permission.storage.status;
    if (!status.isGranted) {
      await Permission.storage.request();
    }
    setState(() {
      isLoading = true;
    });
    print(widget.link);
    toasts.codeSend("Starting Download");
    GallerySaver.saveImage(widget.link, albumName: "Prism").then((value) {
      analytics.logEvent(
          name: 'download_wallpaper', parameters: {'link': widget.link});
      toasts.codeSend("Image Downloaded in Pictures/Prism!");
      setState(() {
        isLoading = false;
      });
    }).catchError((e) {
      // toasts.error(e.toString());
      setState(() {
        isLoading = false;
      });
    });
    // }
  }
}

void showDownloadPopup(BuildContext context, Function rewardFunc) {
  showDialog(
      context: context,
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
  DownloadDialogContent({@required this.rewardFunc});
  @override
  _DownloadDialogContentState createState() => _DownloadDialogContentState();
}

class _DownloadDialogContentState extends State<DownloadDialogContent> {
  int download_coins = 0;
  RewardedVideoAd videoAd = RewardedVideoAd.instance;
  static const MobileAdTargetingInfo targetingInfo = MobileAdTargetingInfo(
    testDevices: <String>[],
    keywords: <String>['Apps', 'Games', 'Mobile', 'Game'],
    nonPersonalizedAds: false,
  );

  void reward(int rewardAmount) {
    download_coins += rewardAmount;
    print("Coins : " + download_coins.toString());
  }

  @override
  void initState() {
    FirebaseAdMob.instance
        .initialize(appId: "ca-app-pub-4649644680694757~6175744196");
    videoAd.listener =
        (RewardedVideoAdEvent event, {String rewardType, int rewardAmount}) {
      print("REWARDED VIDEO AD $event");
      switch (event) {
        case RewardedVideoAdEvent.loaded:
          setState(() {
            globals.loadingAd = false;
          });
          break;
        case RewardedVideoAdEvent.failedToLoad:
          toasts.error("Failed to load ad");
          Navigator.pop(context);
          break;
        case RewardedVideoAdEvent.leftApplication:
          break;
        case RewardedVideoAdEvent.started:
          break;
        case RewardedVideoAdEvent.rewarded:
          reward(rewardAmount);
          break;
        case RewardedVideoAdEvent.closed:
          if (download_coins >= 10) widget.rewardFunc();
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
                borderRadius: BorderRadius.only(
                    topLeft: Radius.circular(20),
                    topRight: Radius.circular(20)),
                color: Theme.of(context).hintColor),
            child: FlareActor(
              "assets/animations/Update.flr",
              fit: BoxFit.contain,
              isPaused: false,
              alignment: Alignment.center,
              animation: "update",
            ),
          ),
          Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              SizedBox(
                height: 20,
              ),
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                mainAxisAlignment: MainAxisAlignment.start,
                children: [
                  SizedBox(
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
          SizedBox(
            height: 25,
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: <Widget>[
              FlatButton(
                shape: StadiumBorder(),
                color: Color(0xFFE57697),
                onPressed: () {
                  if (!main.prefs.get("isLoggedin")) {
                    googleSignInPopUp(context, () {
                      Navigator.of(context).pop();
                      Navigator.pushNamed(context, PremiumRoute);
                    });
                  } else {
                    Navigator.of(context).pop();
                    Navigator.pushNamed(context, PremiumRoute);
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
                shape: StadiumBorder(),
                color: Theme.of(context).accentColor.withOpacity(0.3),
                onPressed: () {
                  globals.loadingAd
                      ? toasts.error("Loading ads")
                      : videoAd.show();
                  globals.loadingAd ? print("") : Navigator.of(context).pop();
                  setState(() {
                    globals.loadingAd ? print("") : globals.loadingAd = true;
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
                          CircularProgressIndicator(),
                        ],
                      ),
              ),
            ],
          ),
          SizedBox(
            height: 15,
          ),
        ],
      ),
    );
  }
}
