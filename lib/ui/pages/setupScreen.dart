import 'package:Prism/routes/router.dart';
import 'package:Prism/ui/widgets/home/bottomNavBar.dart';
import 'package:Prism/ui/widgets/home/headingChipBar.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class SetupScreen extends StatelessWidget {
  SetupScreen({
    Key key,
  }) : super(key: key);

  Future<bool> onWillPop() async {
    navStack.removeLast();
    print(navStack);
    return true;
  }

  final PageController controller = PageController(
    viewportFraction: 0.78,
    initialPage: 0,
  );

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: onWillPop,
      child: Scaffold(
        appBar: PreferredSize(
          child: HeadingChipBar(
            current: "Setups",
          ),
          preferredSize: Size(double.infinity, 55),
        ),
        backgroundColor: Theme.of(context).primaryColor,
        body: BottomBar(
          child: SafeArea(
            child: Stack(
              alignment: Alignment.topCenter,
              children: <Widget>[
                SizedBox(
                  width: MediaQuery.of(context).size.width,
                  height: MediaQuery.of(context).size.height,
                  child: PageView.builder(
                    controller: controller,
                    itemCount: 10,
                    itemBuilder: (context, index) => Padding(
                      padding: EdgeInsets.only(
                          top: MediaQuery.of(context).size.height * 0.03),
                      child: Align(
                        alignment: Alignment.topCenter,
                        child: Container(
                          width: MediaQuery.of(context).size.width * 0.67,
                          height: MediaQuery.of(context).size.height * 0.72,
                          decoration: BoxDecoration(
                            image: DecorationImage(
                                image: NetworkImage(
                                    'https://firebasestorage.googleapis.com/v0/b/prism-wallpapers.appspot.com/o/image_picker6234277413502819198.jpg?alt=media&token=dbfb7a56-3b6e-4f8b-9fc0-5340d9ba6d60'),
                                fit: BoxFit.fill),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                GestureDetector(
                  child: Container(
                    width: MediaQuery.of(context).size.width * 0.83,
                    height: MediaQuery.of(context).size.height * 0.8,
                    decoration: BoxDecoration(
                      image: DecorationImage(
                          image: AssetImage('assets/images/Black.png'),
                          fit: BoxFit.fill),
                    ),
                  ),
                  onPanUpdate: (details) {
                    if (details.delta.dx < -10) {
                      controller.animateToPage(controller.page.toInt() + 1,
                          duration: Duration(milliseconds: 300),
                          curve: Curves.fastOutSlowIn);
                      HapticFeedback.vibrate();
                    } else if (details.delta.dx > 10) {
                      controller.animateToPage(controller.page.toInt() - 1,
                          duration: Duration(milliseconds: 300),
                          curve: Curves.fastOutSlowIn);
                      HapticFeedback.vibrate();
                    }
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
