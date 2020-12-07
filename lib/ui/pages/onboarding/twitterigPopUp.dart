import 'package:Prism/data/profile/wallpaper/getUserProfile.dart';
import 'package:Prism/global/svgAssets.dart';
import 'package:Prism/theme/jam_icons_icons.dart';
import 'package:Prism/ui/pages/home/core/splashScreen.dart';
import 'package:Prism/ui/widgets/animated/showUp.dart';
import 'package:flutter/material.dart';
import 'package:Prism/main.dart' as main;
import 'package:Prism/theme/toasts.dart' as toasts;
import 'package:flutter_svg/flutter_svg.dart';
import 'package:url_launcher/url_launcher.dart';

class OptionalInfo extends StatefulWidget {
  final Image img;
  final String heading;
  final String subheading;
  final bool showSkip;
  final String skipText;
  final String doneText;
  const OptionalInfo({
    @required this.img,
    @required this.heading,
    @required this.subheading,
    @required this.showSkip,
    this.skipText,
    @required this.doneText,
  });
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
    image1 = widget.img;
    super.initState();
  }

  Future<void> func() async {
    if (_twitterController.text != null &&
        _twitterController.text != "" &&
        _igController.text != null &&
        _igController.text != "") {
      await setUserTwitter("https://www.twitter.com/${_twitterController.text}",
          main.prefs.get("id").toString());
      await setUserIG("https://www.instagram.com/${_igController.text}",
          main.prefs.get("id").toString());
      toasts.codeSend("Successfully linked!");
    }
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
                    padding: const EdgeInsets.fromLTRB(0, 110, 0, 8),
                    child: image1),
                ShowUpTransition(
                  forward: true,
                  slideSide: SlideFromSlide.bottom,
                  delay: const Duration(milliseconds: 150),
                  child: Text(
                    widget.heading,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
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
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24.0),
                  child: ShowUpTransition(
                    forward: true,
                    slideSide: SlideFromSlide.bottom,
                    delay: const Duration(milliseconds: 200),
                    child: Text(
                      widget.subheading,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
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
                TwitterIGBoxes(
                    twitterController: _twitterController,
                    igController: _igController),
                widget.showSkip == true
                    ? Row(
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
                                widget.skipText ?? "Skip",
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
                              await func();
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
                                widget.doneText ?? 'DONE',
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
                      )
                    : Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          ElevatedButton(
                            onPressed: () async {
                              await func();
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
                              child: const Text(
                                'DONE',
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

class TwitterIGBoxes extends StatelessWidget {
  final TextEditingController twitterController;
  final TextEditingController igController;
  const TwitterIGBoxes(
      {@required this.twitterController, @required this.igController});
  @override
  Widget build(BuildContext context) {
    return Container(
      height: 160,
      child: Column(
        children: [
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
                controller: twitterController,
                decoration: InputDecoration(
                  contentPadding: const EdgeInsets.only(left: 30, top: 15),
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide:
                          const BorderSide(color: Colors.white, width: 2)),
                  disabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide:
                          const BorderSide(color: Colors.white, width: 2)),
                  enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide:
                          const BorderSide(color: Colors.white, width: 2)),
                  focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide:
                          const BorderSide(color: Colors.white, width: 2)),
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
                  prefixIcon: const Icon(
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
                controller: igController,
                decoration: InputDecoration(
                  contentPadding: const EdgeInsets.only(left: 30, top: 15),
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide:
                          const BorderSide(color: Colors.white, width: 2)),
                  disabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide:
                          const BorderSide(color: Colors.white, width: 2)),
                  enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide:
                          const BorderSide(color: Colors.white, width: 2)),
                  focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide:
                          const BorderSide(color: Colors.white, width: 2)),
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
                  prefixIcon: const Icon(
                    JamIcons.instagram,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class OptionalInfo2 extends StatefulWidget {
  final Image img;
  final String heading;
  final String subheading;
  final bool showSkip;
  final String skipText;
  final String doneText;
  const OptionalInfo2({
    @required this.img,
    @required this.heading,
    @required this.subheading,
    @required this.showSkip,
    this.skipText,
    @required this.doneText,
  });
  @override
  _OptionalInfo2State createState() => _OptionalInfo2State();
}

class _OptionalInfo2State extends State<OptionalInfo2> {
  Image image1;
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
    image1 = widget.img;
    super.initState();
  }

  Future<void> func() async {}

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
                ShowUpTransition(
                  forward: true,
                  slideSide: SlideFromSlide.bottom,
                  delay: const Duration(milliseconds: 150),
                  child: Text(
                    widget.heading,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
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
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24.0),
                  child: ShowUpTransition(
                    forward: true,
                    slideSide: SlideFromSlide.bottom,
                    delay: const Duration(milliseconds: 200),
                    child: Text(
                      widget.subheading,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
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
                ApplyButton(),
                widget.showSkip == true
                    ? Row(
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
                                widget.skipText ?? "Skip",
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
                              await func();
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
                                widget.doneText ?? 'DONE',
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
                      )
                    : Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          ElevatedButton(
                            onPressed: () async {
                              await func();
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
                              child: const Text(
                                'DONE',
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

class ApplyButton extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 15),
      child: GestureDetector(
        onTap: () {
          launch("https://forms.gle/MnSu824XXrpMXcox7");
        },
        child: Container(
            height: 50,
            width: 250,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: Colors.white, width: 2),
            ),
            child: Row(
              children: [
                const Spacer(flex: 4),
                const Text(
                  "Apply now",
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 15,
                    fontFamily: "Roboto",
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const Spacer(),
                Container(
                  width: 20,
                  height: 20,
                  child: SvgPicture.string(
                      verifiedIcon.replaceAll("E57697", "FFFFFF")),
                ),
                const Spacer(flex: 4),
              ],
            )),
      ),
    );
  }
}
//  OptionalInfo(
//   img: Image.asset(
//       'assets/images/first.png'),
//   heading:
//       'Interact with community',
//   subheading:
//       'Add your twitter or instagram handles below',
//   showSkip: true,
//   skipText: "Skip",
//   doneText: "DONE",
//   )

// OptionalInfo2(
//   img: Image.asset(
//       'assets/images/first.png'),
//   heading:
//       'Get paid for your work!',
//   subheading:
//       'Apply to become a verified user below',
//   showSkip: true,
//   skipText: "Skip",
//   doneText: "DONE",
// )
