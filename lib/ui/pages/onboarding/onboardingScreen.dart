import 'package:Prism/analytics/analytics_service.dart';
import 'package:Prism/routes/routing_constants.dart';
import 'package:Prism/theme/jam_icons_icons.dart';
import 'package:Prism/theme/themeModel.dart';
import 'package:Prism/ui/pages/home/core/splashScreen.dart';
import 'package:Prism/ui/pages/onboarding/twitterigPopUp.dart';
import 'package:Prism/ui/widgets/animated/showUp.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:Prism/global/globals.dart' as globals;
import 'package:Prism/main.dart' as main;
import 'package:Prism/theme/toasts.dart' as toasts;

class OnboardingScreen extends StatefulWidget {
  @override
  _OnboardingScreenState createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  PageController onboardingCarouselController = PageController();
  int _currentPage;
  Color selectedAccentColor;
  int selectedTheme;
  bool isLoading;
  bool isSignedIn;
  Image image1;
  Image image2;
  Image image3;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    precacheImage(image1.image, context);
    precacheImage(image2.image, context);
    precacheImage(image3.image, context);
  }

  @override
  void initState() {
    image1 = Image.asset('assets/images/first.png');
    image2 = Image.asset('assets/images/second.png');
    image3 = Image.asset('assets/images/third.png');
    super.initState();
    isLoading = false;
    isSignedIn = main.prefs.get('isLoggedin') as bool ?? false;
    selectedTheme = 1;
    selectedAccentColor = const Color(0xFFE57697);
    _currentPage = 0;
    onboardingCarouselController.addListener(() {
      setState(() {
        _currentPage = onboardingCarouselController.page.toInt();
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async {
        if (_currentPage != 0) {
          onboardingCarouselController.previousPage(
              duration: const Duration(milliseconds: 150),
              curve: Curves.easeOutCubic);
          return false;
        }
        return true;
      },
      child: Scaffold(
        backgroundColor: const Color(0xFFE57697),
        body: SafeArea(
          child: Stack(
            alignment: Alignment.center,
            children: [
              PageView(
                controller: onboardingCarouselController,
                physics: const BouncingScrollPhysics(),
                children: [
                  Column(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Padding(
                          padding: const EdgeInsets.fromLTRB(0, 120, 0, 8),
                          child: image1),
                      Column(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          const ShowUpTransition(
                            forward: true,
                            slideSide: SlideFromSlide.bottom,
                            delay: Duration(milliseconds: 150),
                            child: Text(
                              'Welcome to Prism!',
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
                                'The Next Level in customisation!',
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
                            height: 179,
                          ),
                        ],
                      ),
                    ],
                  ),
                  Column(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Padding(
                          padding: const EdgeInsets.fromLTRB(0, 120, 0, 8),
                          child: image2),
                      Column(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          const ShowUpTransition(
                            forward: true,
                            slideSide: SlideFromSlide.bottom,
                            delay: Duration(milliseconds: 150),
                            child: Text(
                              'Customise your experience!',
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
                          ShowUpTransition(
                            forward: true,
                            slideSide: SlideFromSlide.bottom,
                            delay: const Duration(milliseconds: 200),
                            child: Container(
                              width: MediaQuery.of(context).size.width * 0.935,
                              height: MediaQuery.of(context).size.height * 0.07,
                              child: ListView.builder(
                                scrollDirection: Axis.horizontal,
                                itemCount: themes.length,
                                itemBuilder: (context, index) {
                                  return Padding(
                                    padding:
                                        const EdgeInsets.fromLTRB(8, 4, 8, 4),
                                    child: ClipRRect(
                                      borderRadius: BorderRadius.circular(5),
                                      child: MaterialButton(
                                        color: Theme.of(context).hintColor,
                                        padding: EdgeInsets.zero,
                                        onPressed: () {
                                          Provider.of<ThemeModel>(context,
                                                  listen: false)
                                              .changeThemeByID(
                                                  themes.keys.toList()[index]);
                                          setState(() {
                                            selectedTheme = index;
                                            selectedAccentColor = Color(int
                                                .parse(Provider.of<ThemeModel>(
                                                        context,
                                                        listen: false)
                                                    .currentTheme
                                                    .errorColor
                                                    .toString()
                                                    .replaceAll(
                                                        "MaterialColor(primary value: Color(0xff",
                                                        "")
                                                    .replaceAll("Color(", "")
                                                    .replaceAll(")", "")));
                                          });
                                          final accentColor = int.parse(
                                              selectedAccentColor
                                                  .toString()
                                                  .replaceAll(
                                                      "MaterialColor(primary value: Color(0xff",
                                                      "")
                                                  .replaceAll("Color(", "")
                                                  .replaceAll(")", ""));
                                          final hexString = selectedAccentColor
                                              .toString()
                                              .replaceAll(
                                                  "MaterialColor(primary value: Color(0xff",
                                                  "")
                                              .replaceAll("Color(0xff", "")
                                              .replaceAll(")", "");
                                          main.prefs.put(
                                              "mainAccentColor", accentColor);
                                          analytics.logEvent(
                                              name: "accent_changed",
                                              parameters: {'color': hexString});
                                        },
                                        child: Stack(
                                          children: [
                                            Container(
                                              width: MediaQuery.of(context)
                                                      .size
                                                      .width *
                                                  0.27,
                                              height: MediaQuery.of(context)
                                                      .size
                                                      .height *
                                                  0.06,
                                              decoration: BoxDecoration(
                                                border: Border.all(
                                                    color: Colors.black12),
                                                borderRadius:
                                                    BorderRadius.circular(5),
                                                color: themes[themes.keys
                                                        .toList()[index]]
                                                    .hintColor,
                                              ),
                                              child: Column(
                                                mainAxisAlignment:
                                                    MainAxisAlignment.center,
                                                children: [
                                                  Padding(
                                                    padding:
                                                        const EdgeInsets.all(
                                                            4.0),
                                                    child: Text(
                                                      themes.keys
                                                          .toList()[index]
                                                          .substring(2),
                                                      style: Theme.of(context)
                                                          .textTheme
                                                          .subtitle2
                                                          .copyWith(
                                                              color: themes[themes
                                                                          .keys
                                                                          .toList()[
                                                                      index]]
                                                                  .accentColor),
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                            index == selectedTheme
                                                ? Container(
                                                    width:
                                                        MediaQuery.of(context)
                                                                .size
                                                                .width *
                                                            0.27,
                                                    height:
                                                        MediaQuery.of(context)
                                                                .size
                                                                .height *
                                                            0.06,
                                                    decoration: BoxDecoration(
                                                        color: Theme.of(context)
                                                            .accentColor
                                                            .withOpacity(0.5),
                                                        border: Border.all(
                                                            color:
                                                                Colors.black45),
                                                        borderRadius:
                                                            BorderRadius
                                                                .circular(5)),
                                                    child: Column(
                                                      mainAxisAlignment:
                                                          MainAxisAlignment
                                                              .center,
                                                      children: [
                                                        Icon(
                                                          JamIcons.check,
                                                          color:
                                                              Theme.of(context)
                                                                  .primaryColor,
                                                        ),
                                                      ],
                                                    ),
                                                  )
                                                : Container(),
                                          ],
                                        ),
                                      ),
                                    ),
                                  );
                                },
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
                              delay: Duration(milliseconds: 250),
                              child: Text(
                                'These preferences will enhance your experience. You can always change these later.',
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
                            height: 92,
                          ),
                        ],
                      ),
                    ],
                  ),
                  Column(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Padding(
                          padding: const EdgeInsets.fromLTRB(0, 120, 0, 8),
                          child: image3),
                      Column(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          const ShowUpTransition(
                            forward: true,
                            slideSide: SlideFromSlide.bottom,
                            delay: Duration(milliseconds: 150),
                            child: Text(
                              'Continue with Google',
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
                                'Sign in to save & sync your data!',
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
                            height: 179,
                          ),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
              Column(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      TextButton(
                        onPressed: _currentPage != 2
                            ? () {
                                onboardingCarouselController.animateToPage(2,
                                    duration: const Duration(milliseconds: 250),
                                    curve: Curves.easeOutCubic);
                              }
                            : () {
                                main.prefs.put('onboarded', true);
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
                            _currentPage == 2 ? "Finish" : "Skip",
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
                      OBIndicator(currentPage: _currentPage),
                      ElevatedButton(
                        onPressed: _currentPage != 2
                            ? () {
                                onboardingCarouselController.nextPage(
                                    duration: const Duration(milliseconds: 250),
                                    curve: Curves.easeOutCubic);
                              }
                            : isSignedIn
                                ? () {
                                    toasts.codeSend("Already signed-in!");
                                  }
                                : isLoading
                                    ? () {}
                                    : () async {
                                        setState(() {
                                          isLoading = true;
                                        });
                                        await globals.gAuth
                                            .signInWithGoogle()
                                            .then((value) {
                                          toasts.codeSend("Login Successful!");
                                          main.prefs.put("isLoggedin", true);
                                          Future.delayed(const Duration(
                                                  milliseconds: 500))
                                              .then((value) {
                                            main.prefs.put('onboarded', true);
                                            Navigator.pushReplacement(
                                                context,
                                                MaterialPageRoute(
                                                    builder: (context) =>
                                                        OptionalInfo(
                                                          img: Image.asset(
                                                              'assets/images/first.png'),
                                                          heading:
                                                              'Interact with community',
                                                          subheading:
                                                              'Add your twitter or instagram handles below',
                                                          showSkip: true,
                                                          skipText: "Skip",
                                                          doneText: "DONE",
                                                        )));
                                          });
                                        }).catchError((e) {
                                          debugPrint(e.toString());
                                          main.prefs.put("isLoggedin", false);
                                          toasts.error(
                                              "Something went wrong, please try again!");
                                        });
                                        setState(() {
                                          isLoading = false;
                                          isSignedIn = main.prefs
                                              .get('isLoggedin') as bool;
                                        });
                                      },
                        style: ButtonStyle(
                          backgroundColor: MaterialStateColor.resolveWith(
                              (states) => Colors.white),
                        ),
                        child: Container(
                          width: 60,
                          child: _currentPage != 2
                              ? Text(
                                  _currentPage == 0
                                      ? 'NEXT'
                                      : _currentPage == 1
                                          ? 'NEXT'
                                          : 'SIGN IN',
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(
                                    color: Color(0xFFE57697),
                                    fontSize: 15,
                                    fontFamily: "Roboto",
                                    fontWeight: FontWeight.w500,
                                  ),
                                )
                              : isSignedIn
                                  ? const Icon(
                                      JamIcons.check,
                                      color: Color(0xFFE57697),
                                    )
                                  : isLoading
                                      ? const Center(
                                          child: SizedBox(
                                            height: 20,
                                            width: 20,
                                            child: CircularProgressIndicator(
                                              valueColor:
                                                  AlwaysStoppedAnimation<Color>(
                                                      Color(0xFFE57697)),
                                            ),
                                          ),
                                        )
                                      : Text(
                                          _currentPage == 0
                                              ? 'NEXT'
                                              : _currentPage == 1
                                                  ? 'NEXT'
                                                  : 'SIGN IN',
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
            ],
          ),
        ),
      ),
    );
  }
}

class OBIndicator extends StatelessWidget {
  const OBIndicator({
    Key key,
    @required int currentPage,
  })  : _currentPage = currentPage,
        super(key: key);

  final int _currentPage;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [0, 1, 2].map((i) {
        return AnimatedContainer(
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOutCubic,
          width: _currentPage == i ? 12.0 : 7.0,
          height: 7.0,
          margin: const EdgeInsets.symmetric(vertical: 10.0, horizontal: 2.0),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(500),
            color: _currentPage == i ? Colors.white : Colors.white38,
          ),
        );
      }).toList(),
    );
  }
}
