import 'package:Prism/analytics/analytics_service.dart';
import 'package:Prism/theme/jam_icons_icons.dart';
import 'package:Prism/routes/routing_constants.dart';
// import 'package:Prism/ui/widgets/popup/proPopUp.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:Prism/theme/toasts.dart' as toasts;
import 'package:Prism/main.dart' as main;

class SetWallpaperButton extends StatefulWidget {
  final String url;
  final bool colorChanged;
  const SetWallpaperButton({
    Key key,
    @required this.url,
    @required this.colorChanged,
  }) : super(key: key);

  @override
  _SetWallpaperButtonState createState() => _SetWallpaperButtonState();
}

class _SetWallpaperButtonState extends State<SetWallpaperButton> {
  static const platform = const MethodChannel("flutter.prism.set_wallpaper");
  bool isLoading = false;

  void _setWallPaper() async {
    bool result;
    try {
      result = await platform.invokeMethod("set_wallpaper", <String, dynamic>{
        'url': widget.url,
      });
      if (result) {
        print("Success");
        analytics.logEvent(
            name: 'set_wall',
            parameters: {'type': 'Both', 'result': 'Success'});
        toasts.codeSend("Wallpaper set successfully!");
      } else {
        print("Failed");
        toasts.error("Something went wrong!");
      }
      if (this.mounted) {
        setState(() {
          isLoading = false;
        });
      }
    } catch (e) {
      analytics.logEvent(
          name: 'set_wall', parameters: {'type': 'Both', 'result': 'Failure'});
      print(e);
    }
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

  void onPaint() async {
    HapticFeedback.vibrate();
    Navigator.of(context).pop();
    if (widget.colorChanged) {
      showPremiumPopUp(() async {
        setState(() {
          isLoading = true;
        });
        Future.delayed(Duration(seconds: 1)).then((value) => _setWallPaper());
      });
    } else {
      setState(() {
        isLoading = true;
      });
      Future.delayed(Duration(seconds: 1)).then((value) => _setWallPaper());
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        onPaint();
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
              JamIcons.picture,
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
}
