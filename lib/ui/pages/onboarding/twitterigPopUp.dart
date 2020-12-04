import 'package:Prism/data/profile/wallpaper/getUserProfile.dart';
import 'package:Prism/theme/jam_icons_icons.dart';
import 'package:Prism/ui/pages/home/core/splashScreen.dart';
import 'package:Prism/ui/widgets/animated/showUp.dart';
import 'package:flutter/material.dart';
import 'package:Prism/main.dart' as main;
import 'package:Prism/theme/toasts.dart' as toasts;

class OptionalInfo extends StatefulWidget {
  @override
  _OptionalInfoState createState() => _OptionalInfoState();
}

class _OptionalInfoState extends State<OptionalInfo> {
  Image image1;
  final TextEditingController _twitterController = TextEditingController();
  final TextEditingController _igController = TextEditingController();
  Future<bool> onWillPop(BuildContext ctx) async {
    Navigator.pushReplacement(
        ctx, MaterialPageRoute(builder: (context) => SplashWidget()));
    return false;
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    precacheImage(image1.image, context);
  }

  @override
  void initState() {
    image1 = Image.asset('assets/images/first.png');
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () {
        onWillPop(context);
      },
      child: Scaffold(
        backgroundColor: const Color(0xFFE57697),
        body: SingleChildScrollView(
          child: Container(
            height: MediaQuery.of(context).size.height,
            child: Column(
              children: [
                Padding(
                    padding: const EdgeInsets.fromLTRB(0, 120, 0, 8),
                    child: image1),
                const ShowUpTransition(
                  forward: true,
                  slideSide: SlideFromSlide.bottom,
                  delay: Duration(milliseconds: 150),
                  child: Text(
                    'Interact with community',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 24,
                      fontFamily: "Roboto",
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
                const SizedBox(
                  height: 17,
                ),
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 24.0),
                  child: ShowUpTransition(
                    forward: true,
                    slideSide: SlideFromSlide.bottom,
                    delay: Duration(milliseconds: 200),
                    child: Text(
                      'Add your twitter or instagram handles below',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Colors.white70,
                        fontSize: 15,
                        fontFamily: "Roboto",
                        fontWeight: FontWeight.normal,
                      ),
                    ),
                  ),
                ),
                const SizedBox(
                  height: 17,
                ),
                Container(
                  height: 80,
                  width: 250,
                  child: Center(
                    child: TextField(
                      cursorColor: const Color(0xFFE57697),
                      style: Theme.of(context)
                          .textTheme
                          .headline5
                          .copyWith(color: Colors.white),
                      controller: _twitterController,
                      decoration: InputDecoration(
                        contentPadding:
                            const EdgeInsets.only(left: 30, top: 15),
                        border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                            borderSide: const BorderSide(
                                color: Colors.white, width: 2)),
                        disabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                            borderSide: const BorderSide(
                                color: Colors.white, width: 2)),
                        enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                            borderSide: const BorderSide(
                                color: Colors.white, width: 2)),
                        focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                            borderSide: const BorderSide(
                                color: Colors.white, width: 2)),
                        labelText: "Twitter",
                        labelStyle: Theme.of(context)
                            .textTheme
                            .headline5
                            .copyWith(fontSize: 14, color: Colors.white),
                        hintText: "Ex - PrismWallpapers",
                        hintStyle: Theme.of(context)
                            .textTheme
                            .headline5
                            .copyWith(fontSize: 14, color: Colors.white),
                        prefixIcon: Icon(
                          JamIcons.twitter,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                ),
                Container(
                  height: 80,
                  width: 250,
                  child: Center(
                    child: TextField(
                      cursorColor: const Color(0xFFE57697),
                      style: Theme.of(context)
                          .textTheme
                          .headline5
                          .copyWith(color: Colors.white),
                      controller: _igController,
                      decoration: InputDecoration(
                        contentPadding:
                            const EdgeInsets.only(left: 30, top: 15),
                        border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                            borderSide: const BorderSide(
                                color: Colors.white, width: 2)),
                        disabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                            borderSide: const BorderSide(
                                color: Colors.white, width: 2)),
                        enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                            borderSide: const BorderSide(
                                color: Colors.white, width: 2)),
                        focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                            borderSide: const BorderSide(
                                color: Colors.white, width: 2)),
                        labelText: "Instagram",
                        hintText: "Ex - PrismWallpapers",
                        labelStyle: Theme.of(context)
                            .textTheme
                            .headline5
                            .copyWith(fontSize: 14, color: Colors.white),
                        hintStyle: Theme.of(context)
                            .textTheme
                            .headline5
                            .copyWith(fontSize: 14, color: Colors.white),
                        prefixIcon: Icon(
                          JamIcons.instagram,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                ),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    TextButton(
                      onPressed: () {
                        Navigator.pushReplacement(
                            context,
                            MaterialPageRoute(
                                builder: (context) => SplashWidget()));
                      },
                      style: ButtonStyle(
                          overlayColor: MaterialStateColor.resolveWith(
                              (states) => Colors.white10)),
                      child: Container(
                        width: 75,
                        child: Text(
                          "Skip",
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 15,
                            fontFamily: "Roboto",
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ),
                    ElevatedButton(
                      onPressed: () async {
                        if (_twitterController.text != null &&
                            _twitterController.text != "" &&
                            _igController.text != null &&
                            _igController.text != "") {
                          await setUserTwitter(
                              "https://www.twitter.com/${_twitterController.text}",
                              main.prefs.get("id").toString());
                          await setUserIG(
                              "https://www.instagram.com/${_igController.text}",
                              main.prefs.get("id").toString());
                          toasts.codeSend("Successfully linked!");
                        }
                        Navigator.pushReplacement(
                            context,
                            MaterialPageRoute(
                                builder: (context) => SplashWidget()));
                      },
                      style: ButtonStyle(
                        backgroundColor: MaterialStateColor.resolveWith(
                            (states) => Colors.white),
                      ),
                      child: Container(
                        width: 60,
                        child: Text(
                          'DONE',
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            color: Color(0xFFE57697),
                            fontSize: 15,
                            fontFamily: "Roboto",
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(
                  height: 24,
                ),
              ],
            ),
          ),
        ),
        floatingActionButtonLocation: FloatingActionButtonLocation.miniEndTop,
        floatingActionButton: FloatingActionButton(
          backgroundColor: Colors.transparent,
          focusElevation: 0,
          highlightElevation: 0,
          elevation: 0,
          mini: true,
          onPressed: () {
            Navigator.pushReplacement(context,
                MaterialPageRoute(builder: (context) => SplashWidget()));
          },
          child: const Icon(
            JamIcons.close,
            color: Colors.white,
          ),
        ),
      ),
    );
  }
}
