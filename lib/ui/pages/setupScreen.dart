import 'package:Prism/data/setups/provider/setupProvider.dart';
import 'package:Prism/routes/router.dart';
import 'package:Prism/theme/jam_icons_icons.dart';
import 'package:Prism/ui/widgets/animated/loader.dart';
import 'package:Prism/ui/widgets/home/bottomNavBar.dart';
import 'package:Prism/ui/widgets/home/headingChipBar.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:optimized_cached_image/widgets.dart';
import 'package:provider/provider.dart';

class SetupScreen extends StatefulWidget {
  SetupScreen({
    Key key,
  }) : super(key: key);

  @override
  _SetupScreenState createState() => _SetupScreenState();
}

class _SetupScreenState extends State<SetupScreen> {
  Future<bool> onWillPop() async {
    navStack.removeLast();
    print(navStack);
    return true;
  }

  final PageController controller = PageController(
    viewportFraction: 0.78,
    initialPage: 0,
  );
  Future future;

  @override
  void initState() {
    future = Provider.of<SetupProvider>(context, listen: false).getDataBase();
    super.initState();
  }

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
                FutureBuilder(
                    future: future,
                    builder: (context, snapshot) {
                      if (snapshot == null) {
                        print("snapshot null");
                        return Loader();
                      }
                      if (snapshot.connectionState == ConnectionState.waiting ||
                          snapshot.connectionState == ConnectionState.none) {
                        print("snapshot none, waiting");
                        return Loader();
                      } else {
                        return SizedBox(
                          width: MediaQuery.of(context).size.width,
                          height: MediaQuery.of(context).size.height,
                          child: PageView.builder(
                            controller: controller,
                            itemCount: Provider.of<SetupProvider>(context,
                                            listen: false)
                                        .setups
                                        .length ==
                                    0
                                ? 1
                                : Provider.of<SetupProvider>(context,
                                        listen: false)
                                    .setups
                                    .length,
                            itemBuilder: (context, index) => Provider.of<
                                                SetupProvider>(context,
                                            listen: false)
                                        .setups
                                        .length ==
                                    0
                                ? Loader()
                                : Padding(
                                    padding: EdgeInsets.only(
                                        top:
                                            MediaQuery.of(context).size.height *
                                                0.0299),
                                    child: Align(
                                      alignment: Alignment.topCenter,
                                      child: OptimizedCacheImage(
                                        imageUrl: Provider.of<SetupProvider>(
                                                context,
                                                listen: false)
                                            .setups[index]['image'],
                                        imageBuilder:
                                            (context, imageProvider) =>
                                                Container(
                                          width: MediaQuery.of(context)
                                                  .size
                                                  .width *
                                              0.672,
                                          height: MediaQuery.of(context)
                                                  .size
                                                  .height *
                                              0.72,
                                          decoration: BoxDecoration(
                                            image: DecorationImage(
                                                image: imageProvider,
                                                fit: BoxFit.fill),
                                          ),
                                        ),
                                        placeholder: (context, url) =>
                                            Container(
                                          width: MediaQuery.of(context)
                                                  .size
                                                  .width *
                                              0.672,
                                          height: MediaQuery.of(context)
                                                  .size
                                                  .height *
                                              0.72,
                                          child: Center(
                                            child: Loader(),
                                          ),
                                        ),
                                        errorWidget: (context, url, error) =>
                                            Container(
                                          child: Center(
                                            child: Icon(
                                              JamIcons.close_circle_f,
                                              color:
                                                  Theme.of(context).accentColor,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                          ),
                        );
                      }
                    }),
                GestureDetector(
                  child: Container(
                    width: MediaQuery.of(context).size.width * 0.83,
                    height: MediaQuery.of(context).size.height * 0.8,
                    decoration: BoxDecoration(
                      image: DecorationImage(
                          image:
                              Theme.of(context).accentColor == Color(0xFF2F2F2F)
                                  ? AssetImage('assets/images/Black.png')
                                  : AssetImage('assets/images/White.png'),
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
