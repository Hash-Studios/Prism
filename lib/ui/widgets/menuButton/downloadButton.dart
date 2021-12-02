import 'dart:io';
import 'dart:math';

import 'package:Prism/analytics/analytics_service.dart';
import 'package:Prism/data/ads/adsNotifier.dart';
import 'package:Prism/global/globals.dart' as globals;
import 'package:Prism/logger/logger.dart';
import 'package:Prism/routes/routing_constants.dart';
import 'package:Prism/theme/jam_icons_icons.dart';
import 'package:Prism/theme/toasts.dart' as toasts;
import 'package:Prism/ui/widgets/popup/signInPopUp.dart';
import 'package:animations/animations.dart';
import 'package:device_info/device_info.dart';
import 'package:flare_flutter/flare_actor.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_downloader/flutter_downloader.dart';
import 'package:gallery_saver/gallery_saver.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:provider/provider.dart';

class DownloadButtonNew extends StatefulWidget {
  final String link;
  final bool colorChanged;
  final bool loading;
  final int progress;
  final String path;
  final Future<File> Function()? screenshotCallback;

  const DownloadButtonNew({
    required this.link,
    required this.loading,
    required this.progress,
    required this.path,
    required this.colorChanged,
    required this.screenshotCallback,
    Key? key,
  }) : super(key: key);

  @override
  _DownloadButtonNewState createState() => _DownloadButtonNewState();
}

class _DownloadButtonNewState extends State<DownloadButtonNew> {
  @override
  void initState() {
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () async {
        if (!widget.loading) {
          if (globals.prismUser.loggedIn == true) {
            if (globals.prismUser.premium == true) {
              finalDownload(widget.link, widget.path);
            } else {
              showDownloadPopup(context, () {
                logger.d("Download");
                finalDownload(widget.link, widget.path);
              });
            }
          } else {
            showDownloadPopup(context, () {
              logger.d("Download");
              finalDownload(widget.link, widget.path);
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
              child: widget.loading
                  ? const CircularProgressIndicator()
                  : Container())
        ],
      ),
    );
  }

  void showPremiumPopUp(Function func) {
    if (globals.prismUser.premium == false) {
      toasts.codeSend("Variants are a premium feature.");
      Navigator.pushNamed(context, premiumRoute);
    } else {
      func();
    }
  }

  Future<void> finalDownload(String link, String path) async {
    if (await Permission.storage.request().isGranted) {
      String url = link;
      logger.d('Already not downloaded, downloading $url');
      final r = Random();
      String rNum = "";
      for (var i = 0; i < 6; i++) {
        rNum = "$rNum${r.nextInt(9)}";
      }
      if (widget.colorChanged) {
        final File? file = await widget.screenshotCallback?.call();
        url = file?.path ?? link;
        GallerySaver.saveImage(url, albumName: "Prism").then((value) {
          analytics.logEvent(
              name: 'download_wallpaper', parameters: {'link': widget.link});
          toasts.codeSend("Wall Downloaded in Pictures/Prism!");
        }).catchError((e, StackTrace s) {
          logger.e(e, s, s);
        });
      } else {
        if (Platform.isAndroid) {
          final androidInfo = await DeviceInfoPlugin().androidInfo;
          logger.d(androidInfo.version.sdkInt);
          final taskId = await FlutterDownloader.enqueue(
            url: url,
            savedDir: path,
            fileName:
                "${url.split('/').last.toString().split(".")[0]}$rNum.${url.split('/').last.toString().split(".")[1]}",
            saveInPublicStorage:
                (androidInfo.version.sdkInt >= 29) ? true : false,
          );
          logger.d('Downloaded wallpaper, saving taskID $taskId $url');
        } else {
          final taskId = await FlutterDownloader.enqueue(
            url: url,
            savedDir: path,
            fileName:
                "${url.split('/').last.toString().split(".")[0]}$rNum.${url.split('/').last.toString().split(".")[1]}",
          );
          logger.d('Downloaded wallpaper, saving taskID $taskId $url');
        }
      }
    } else {
      toasts.error("No storage permission");
    }
  }
}

class DownloadButton extends StatefulWidget {
  final String? link;

  const DownloadButton({
    required this.link,
    Key? key,
  }) : super(key: key);

  @override
  _DownloadButtonState createState() => _DownloadButtonState();
}

class _DownloadButtonState extends State<DownloadButton> {
  late bool isLoading;

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
          if (globals.prismUser.loggedIn == true) {
            if (globals.prismUser.premium == true) {
              onDownload(widget.link!);
            } else {
              showDownloadPopup(context, () {
                logger.d("Download");
                onDownload(widget.link!);
              });
            }
          } else {
            showDownloadPopup(context, () {
              logger.d("Download");
              onDownload(widget.link!);
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
    if (globals.prismUser.premium == false) {
      toasts.codeSend("Variants are a premium feature.");
      Navigator.pushNamed(context, premiumRoute);
    } else {
      func();
    }
  }

  Future<void> onDownload(String link) async {
    if (await Permission.storage.request().isGranted) {
      final String url = link;
      String? externalStorageDirPath;
      if (Platform.isAndroid) {
        try {
          externalStorageDirPath = "/storage/emulated/0/Download";
        } catch (e) {
          final directory = await getExternalStorageDirectory();
          externalStorageDirPath = directory?.path;
        }
      } else if (Platform.isIOS) {
        externalStorageDirPath =
            (await getApplicationDocumentsDirectory()).absolute.path;
      }
      logger.d('Already not downloaded, downloading $url');
      final r = Random();
      String rNum = "";
      for (var i = 0; i < 6; i++) {
        rNum = "$rNum${r.nextInt(9)}";
      }
      if (Platform.isAndroid) {
        final androidInfo = await DeviceInfoPlugin().androidInfo;
        logger.d(androidInfo.version.sdkInt);
        final taskId = await FlutterDownloader.enqueue(
          url: url,
          savedDir: externalStorageDirPath ?? "",
          fileName:
              "${url.split('/').last.toString().split(".")[0]}$rNum.${url.split('/').last.toString().split(".")[1]}",
          saveInPublicStorage:
              (androidInfo.version.sdkInt >= 29) ? true : false,
        );
        logger.d('Downloaded wallpaper, saving taskID $taskId $url');
      } else {
        final taskId = await FlutterDownloader.enqueue(
          url: url,
          savedDir: externalStorageDirPath ?? "",
          fileName:
              "${url.split('/').last.toString().split(".")[0]}$rNum.${url.split('/').last.toString().split(".")[1]}",
        );
        logger.d('Downloaded wallpaper, saving taskID $taskId $url');
      }
    } else {
      toasts.error("No storage permission");
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

  const DownloadDialogContent({required this.rewardFunc});

  @override
  _DownloadDialogContentState createState() => _DownloadDialogContentState();
}

class _DownloadDialogContentState extends State<DownloadDialogContent> {
  @override
  void initState() {
    final AdsNotifier adsNotifier =
        Provider.of<AdsNotifier>(context, listen: false);
    if (!adsNotifier.adLoaded) {
      Future.delayed(const Duration()).then((value) {
        adsNotifier.createRewardedAd();
      });
    }
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    final AdsNotifier adsNotifier = Provider.of<AdsNotifier>(context);
    if (adsNotifier.adFailed) {
      if (mounted) {
        adsNotifier.adFailed = false;
        Future.delayed(const Duration()).then((value) {
          Navigator.pushReplacementNamed(context, adsNotLoadingRoute);
          widget.rewardFunc();
        });
      }
    }
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
                  SizedBox(
                    width: MediaQuery.of(context).size.width * 0.7,
                    child: Text(
                      "Watch a small video ad to download this wallpaper.",
                      style: Theme.of(context)
                          .textTheme
                          .headline6!
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
                color: Theme.of(context).errorColor,
                onPressed: () {
                  if (globals.prismUser.loggedIn == false) {
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
                  if (adsNotifier.loadingAd == false &&
                      adsNotifier.adLoaded == true) {
                    adsNotifier.showRewardedAd(widget.rewardFunc);
                    Navigator.of(context).pop();
                  } else {
                    toasts.error("Loading ads");
                  }
                },
                child: adsNotifier.loadingAd == false &&
                        adsNotifier.adLoaded == true
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
                          const SizedBox(
                              height: 16,
                              width: 16,
                              child: CircularProgressIndicator()),
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
