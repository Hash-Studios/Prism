import 'package:Prism/routes/router.dart';
import 'package:Prism/ui/widgets/animated/loader.dart';
import 'package:flutter/material.dart';
import 'package:Prism/data/prism/provider/prismWithoutProvider.dart';
import 'package:Prism/ui/widgets/home/wallpapers/trendingGrid.dart';

class TrendingScreen extends StatefulWidget {
  const TrendingScreen({
    Key key,
  }) : super(key: key);

  @override
  _TrendingScreenState createState() => _TrendingScreenState();
}

class _TrendingScreenState extends State<TrendingScreen> {
  Future<List> _future;

  Future<bool> onWillPop() async {
    if (navStack.length > 1) navStack.removeLast();
    debugPrint(navStack.toString());
    debugPrint("Bye! Have a good day!");
    return true;
  }

  @override
  void initState() {
    super.initState();
    _future =
        Future.delayed(const Duration()).then((value) => getTrendingWalls());
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: onWillPop,
      child: FutureBuilder<List>(
        future: _future, // async work
        builder: (BuildContext context, AsyncSnapshot<List> snapshot) {
          switch (snapshot.connectionState) {
            case ConnectionState.waiting:
              return Center(child: Loader());
            case ConnectionState.none:
              return Center(child: Loader());
            default:
              if (snapshot.hasError) {
                debugPrint(snapshot.error.toString());
                return RefreshIndicator(
                    onRefresh: () async {
                      // ignore: unnecessary_statements
                      _future;
                    },
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: const <Widget>[
                        Spacer(),
                        Center(child: Text("Can't connect to the Servers!")),
                        Spacer(),
                      ],
                    ));
              } else {
                return const TrendingGrid(provider: "Trending");
              }
          }
        },
      ),
    );
  }
}
