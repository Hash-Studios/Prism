import 'package:Prism/analytics/analytics_service.dart';
import 'package:Prism/core/platform/pigeon/prism_media_api.g.dart';
import 'package:Prism/core/router/app_router.dart';
import 'package:Prism/core/widgets/common/safe_rive_asset.dart';
import 'package:Prism/core/widgets/popup/signInPopUp.dart';
import 'package:Prism/features/ads/ads.dart';
import 'package:Prism/global/globals.dart' as globals;
import 'package:Prism/logger/logger.dart';
import 'package:Prism/theme/jam_icons_icons.dart';
import 'package:Prism/theme/toasts.dart' as toasts;
import 'package:animations/animations.dart';
import 'package:auto_route/auto_route.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:permission_handler/permission_handler.dart';

class DownloadButton extends StatefulWidget {
  final String? link;
  final bool colorChanged;

  const DownloadButton({required this.link, required this.colorChanged, super.key});

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

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        if (!isLoading) {
          if (globals.prismUser.loggedIn == true) {
            if (globals.prismUser.premium == true) {
              onDownload();
            } else {
              showDownloadPopup(context, () {
                logger.d("Download");
                onDownload();
              });
            }
          } else {
            showDownloadPopup(context, () {
              logger.d("Download");
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
                BoxShadow(color: Colors.black.withValues(alpha: .25), blurRadius: 4, offset: const Offset(0, 4)),
              ],
              borderRadius: BorderRadius.circular(500),
            ),
            padding: const EdgeInsets.all(17),
            child: Icon(JamIcons.download, color: Theme.of(context).colorScheme.secondary, size: 20),
          ),
          Positioned(
            top: 0,
            left: 0,
            height: 53,
            width: 53,
            child: isLoading ? const CircularProgressIndicator() : Container(),
          ),
        ],
      ),
    );
  }

  void showPremiumPopUp(VoidCallback func) {
    if (globals.prismUser.premium == false) {
      toasts.codeSend("Variants are a premium feature.");
      context.router.push(const UpgradeRoute());
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
    logger.d(widget.link);

    final androidInfo = await DeviceInfoPlugin().androidInfo;
    final sdkInt = androidInfo.version.sdkInt;
    logger.d('(SDK $sdkInt)');
    if (widget.link!.contains("com.hash.prism")) {
      debugPrint("Saving local file");
      try {
        final request = SaveMediaRequest(link: widget.link!, isLocalFile: true, kind: SaveMediaKind.wallpaper);
        final result = await PrismMediaHostApi().saveMedia(request);
        if (result.success) {
          analytics.logEvent(name: 'download_wallpaper', parameters: {'link': widget.link ?? ''});
          toasts.codeSend("Wall Downloaded in Pictures/Prism!");
        } else {
          toasts.error("Couldn't download! Please Retry!");
        }
      } on PlatformException catch (e) {
        logger.e('saveMedia failed', error: e);
        toasts.error("Couldn't download! Please Retry!");
      } catch (e) {
        logger.e('Unexpected saveMedia failure', error: e);
        toasts.error("Something went wrong!");
      } finally {
        if (mounted) {
          setState(() {
            isLoading = false;
          });
        }
      }
    } else {
      debugPrint("Downloading using DownloadManager");
      try {
        final request = DownloadRequest(
          link: widget.link!,
          filenameWithoutExtension: widget.link!.split('/').last.replaceAll(".jpg", "").replaceAll(".png", ""),
        );
        await PrismMediaHostApi().enqueueDownload(request);
        toasts.codeSend("Wall Downloaded in Pictures/Prism!");
        analytics.logEvent(name: 'download_wallpaper', parameters: {'link': widget.link ?? ''});
      } on PlatformException catch (e) {
        logger.e('enqueueDownload failed', error: e);
        toasts.error("Couldn't download! Please Retry!");
      } catch (e) {
        logger.e('Unexpected enqueueDownload failure', error: e);
        toasts.error("Something went wrong!");
      } finally {
        if (mounted) {
          setState(() {
            isLoading = false;
          });
        }
      }
    }
  }
}

void showDownloadPopup(BuildContext context, VoidCallback rewardFunc) {
  showModal(
    context: context,
    builder: (BuildContext context) => StatefulBuilder(
      builder: (BuildContext context, StateSetter setState) {
        return Dialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          child: DownloadDialogContent(rewardFunc: rewardFunc),
        );
      },
    ),
  );
}

class DownloadDialogContent extends StatefulWidget {
  final VoidCallback rewardFunc;

  const DownloadDialogContent({required this.rewardFunc});

  @override
  _DownloadDialogContentState createState() => _DownloadDialogContentState();
}

class _DownloadDialogContentState extends State<DownloadDialogContent> {
  @override
  void initState() {
    final adsState = context.read<AdsBloc>().state;
    if (!adsState.ads.loadingAd && !adsState.ads.adLoaded) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        context.read<AdsBloc>().add(const AdsEvent.started());
      });
    }
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<AdsBloc, AdsState>(
      listenWhen: (previous, current) =>
          previous.ads != current.ads || previous.shouldUnlockDownload != current.shouldUnlockDownload,
      listener: (context, state) {
        if (state.shouldUnlockDownload) {
          widget.rewardFunc();
          context.read<AdsBloc>().add(const AdsEvent.transientStateCleared());
          Navigator.of(context).pop();
        }
      },
      builder: (context, state) {
        final ads = state.ads;
        final adFailed = ads.adFailed;
        final canWatchAd = !ads.loadingAd && ads.adLoaded && !adFailed;

        return Container(
          decoration: BoxDecoration(borderRadius: BorderRadius.circular(20), color: Theme.of(context).primaryColor),
          width: MediaQuery.of(context).size.width * .78,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Container(
                height: 150,
                width: MediaQuery.of(context).size.width * .78,
                decoration: BoxDecoration(
                  borderRadius: const BorderRadius.only(topLeft: Radius.circular(20), topRight: Radius.circular(20)),
                  color: Theme.of(context).hintColor,
                ),
                child: const SafeRiveAsset(assetName: "assets/animations/Update.flr", animations: <String>["update"]),
              ),
              Column(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  const SizedBox(height: 20),
                  Row(
                    children: [
                      const SizedBox(width: 20),
                      SizedBox(
                        width: MediaQuery.of(context).size.width * 0.7,
                        child: Text(
                          "Watch a small video ad to download this wallpaper.",
                          style: Theme.of(
                            context,
                          ).textTheme.titleLarge!.copyWith(color: Theme.of(context).colorScheme.secondary),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 25),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: <Widget>[
                  MaterialButton(
                    shape: const StadiumBorder(),
                    color: Theme.of(context).colorScheme.error,
                    onPressed: () {
                      if (globals.prismUser.loggedIn == false) {
                        googleSignInPopUp(context, () {
                          Navigator.of(context).pop();
                          context.router.push(const UpgradeRoute());
                        });
                      } else {
                        Navigator.of(context).pop();
                        context.router.push(const UpgradeRoute());
                      }
                    },
                    child: Text(
                      'BUY PREMIUM',
                      style: TextStyle(fontSize: 16.0, color: Theme.of(context).colorScheme.secondary),
                    ),
                  ),
                  MaterialButton(
                    shape: const StadiumBorder(),
                    color: Theme.of(context).colorScheme.secondary.withValues(alpha: 0.3),
                    onPressed: () {
                      if (adFailed) {
                        context.read<AdsBloc>().add(const AdsEvent.transientStateCleared());
                        context.read<AdsBloc>().add(const AdsEvent.started());
                      } else if (canWatchAd) {
                        context.read<AdsBloc>().add(const AdsEvent.watchAdRequested());
                      } else {
                        toasts.error("Loading ads");
                      }
                    },
                    child: adFailed
                        ? Text(
                            'WATCH AD',
                            style: TextStyle(fontSize: 16.0, color: Theme.of(context).colorScheme.secondary),
                          )
                        : canWatchAd
                        ? Text(
                            'WATCH AD',
                            style: TextStyle(fontSize: 16.0, color: Theme.of(context).colorScheme.secondary),
                          )
                        : Stack(
                            alignment: Alignment.center,
                            children: <Widget>[
                              Text(
                                'WATCH AD',
                                style: TextStyle(
                                  fontSize: 16.0,
                                  color: Theme.of(context).colorScheme.secondary.withValues(alpha: 0.3),
                                ),
                              ),
                              const SizedBox(height: 16, width: 16, child: CircularProgressIndicator()),
                            ],
                          ),
                  ),
                ],
              ),
              const SizedBox(height: 15),
            ],
          ),
        );
      },
    );
  }
}
