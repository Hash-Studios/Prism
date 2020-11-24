import 'package:Prism/ui/pages/home/core/pageManager.dart';
import 'package:Prism/ui/widgets/animated/showUp.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class OnboardingScreen extends StatefulWidget {
  @override
  _OnboardingScreenState createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  PageController onboardingCarouselController = PageController();
  int _currentPage;

  @override
  void initState() {
    SystemChrome.setEnabledSystemUIOverlays(
        [SystemUiOverlay.top, SystemUiOverlay.bottom]);
    super.initState();
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
        body: Stack(
          alignment: Alignment.center,
          children: [
            PageView(
              controller: onboardingCarouselController,
              physics: const BouncingScrollPhysics(),
              children: [
                Container(
                  child: Image.asset('assets/images/prism.png'),
                ),
                Container(),
                Container(),
              ],
            ),
            Column(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                _currentPage == 0
                    ? const ShowUpTransition(
                        forward: true,
                        slideSide: SlideFromSlide.bottom,
                        delay: Duration(milliseconds: 50),
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
                      )
                    : Container(),
                const SizedBox(
                  height: 17,
                ),
                _currentPage == 0
                    ? const ShowUpTransition(
                        forward: true,
                        slideSide: SlideFromSlide.bottom,
                        delay: Duration(milliseconds: 150),
                        child: const Text(
                          'The Next Level in customisation!',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: Colors.white70,
                            fontSize: 15,
                            fontFamily: "Roboto",
                            fontWeight: FontWeight.normal,
                          ),
                        ),
                      )
                    : Container(),
                const SizedBox(
                  height: 56,
                ),
                ElevatedButton(
                  onPressed: () {
                    onboardingCarouselController.nextPage(
                        duration: const Duration(milliseconds: 150),
                        curve: Curves.easeOutCubic);
                  },
                  style: ButtonStyle(
                    backgroundColor: MaterialStateColor.resolveWith(
                        (states) => Colors.white),
                  ),
                  child: Text(
                    _currentPage == 0
                        ? 'GET STARTED'
                        : _currentPage == 1
                            ? 'NEXT'
                            : 'FINISH',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Color(0xFFE57697),
                      fontSize: 15,
                      fontFamily: "Roboto",
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
                const SizedBox(
                  height: 24,
                ),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [0, 1, 2].map((i) {
                    return AnimatedContainer(
                      duration: const Duration(milliseconds: 250),
                      curve: Curves.easeOutCubic,
                      width: _currentPage == i ? 12.0 : 7.0,
                      height: 7.0,
                      margin: const EdgeInsets.symmetric(
                          vertical: 10.0, horizontal: 2.0),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(500),
                        color:
                            _currentPage == i ? Colors.white : Colors.white38,
                      ),
                    );
                  }).toList(),
                ),
                const SizedBox(
                  height: 24,
                ),
              ],
            )
          ],
        ),
      ),
    );
  }
}
