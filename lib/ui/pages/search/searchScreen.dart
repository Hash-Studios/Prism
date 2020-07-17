import 'package:Prism/data/wallhaven/provider/wallhaven.dart';
import 'package:Prism/routes/router.dart';
import 'package:Prism/theme/jam_icons_icons.dart';
import 'package:Prism/theme/themeModel.dart';
import 'package:Prism/ui/widgets/home/bottomNavBar.dart';
import 'package:Prism/ui/widgets/home/gridLoader.dart';
import 'package:Prism/ui/widgets/home/homeGrid.dart';
import 'package:Prism/ui/widgets/home/inheritedScrollControllerProvider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:provider/provider.dart';

class SearchScreen extends StatefulWidget {
  @override
  _SearchScreenState createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  Future<bool> onWillPop() async {
    if(navStack.length>1)navStack.removeLast();
    print(navStack);
    return true;
  }

  final List<String> tags = [
    'Art',
    'Abstract',
    'Patterns',
    'Geometry',
    'Cyber',
    'Cars',
    'Comics',
    'Anime',
    'Illustrations',
    'Games',
    'Street',
    'Flowers',
    'Epic',
  ];
  bool isSubmitted;
  TextEditingController searchController = TextEditingController();
  Future _future;
  @override
  void initState() {
    isSubmitted = false;
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: onWillPop,
      child: Scaffold(
          backgroundColor: Theme.of(context).primaryColor,
          appBar: AppBar(
            excludeHeaderSemantics: false,
            automaticallyImplyLeading: false,
            elevation: 0,
            titleSpacing: 0,
            title: Padding(
              padding: const EdgeInsets.only(top: 6.0),
              child: SizedBox(
                width: MediaQuery.of(context).size.width,
                child: Padding(
                  padding: const EdgeInsets.all(4.0),
                  child: Column(
                    children: [
                      Container(
                        decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(500),
                            color: Theme.of(context).hintColor),
                        child: TextField(
                          cursorColor: Color(0xFFE57697),
                          style: Theme.of(context)
                              .textTheme
                              .headline5
                              .copyWith(color: Theme.of(context).accentColor),
                          controller: searchController,
                          decoration: InputDecoration(
                            contentPadding: EdgeInsets.only(left: 30, top: 15),
                            border: InputBorder.none,
                            disabledBorder: InputBorder.none,
                            enabledBorder: InputBorder.none,
                            focusedBorder: InputBorder.none,
                            hintText: "Search",
                            hintStyle: Theme.of(context)
                                .textTheme
                                .headline5
                                .copyWith(color: Theme.of(context).accentColor),
                            suffixIcon: Icon(
                              JamIcons.search,
                              color: Theme.of(context).accentColor,
                            ),
                          ),
                          onSubmitted: (tex) {
                            setState(() {
                              isSubmitted = true;
                              Provider.of<WallHavenProvider>(context,
                                      listen: false)
                                  .wallsS = [];
                              _future = Provider.of<WallHavenProvider>(context,
                                      listen: false)
                                  .getWallsbyQuery(tex);
                            });
                          },
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            bottom: PreferredSize(
                child: SizedBox(
                  width: MediaQuery.of(context).size.width,
                  height: 53,
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    itemCount: tags.length,
                    itemBuilder: (context, index) {
                      return Align(
                        alignment: Alignment.center,
                        child: Stack(
                          children: <Widget>[
                            Padding(
                              padding: const EdgeInsets.fromLTRB(5, 0, 2, 0),
                              child: ActionChip(
                                  pressElevation: 5,
                                  padding: EdgeInsets.fromLTRB(14, 11, 14, 11),
                                  backgroundColor: Theme.of(context).hintColor,
                                  label: Text(tags[index],
                                      style: Theme.of(context)
                                          .textTheme
                                          .headline4),
                                  onPressed: () {
                                    setState(() {
                                      searchController.text = tags[index];
                                      isSubmitted = true;
                                      Provider.of<WallHavenProvider>(context,
                                              listen: false)
                                          .wallsS = [];
                                      _future = Provider.of<WallHavenProvider>(
                                              context,
                                              listen: false)
                                          .getWallsbyQuery(tags[index]);
                                    });
                                  }),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
                preferredSize: Size(double.infinity, 54)),
          ),
          body: BottomBar(
            child: isSubmitted
                ? SearchLoader(
                    future: _future,
                    provider: searchController.text,
                  )
                : Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: <Widget>[
                      SizedBox(
                        width: MediaQuery.of(context).size.width,
                        child: Provider.of<ThemeModel>(context, listen: false)
                                    .returnTheme() ==
                                ThemeType.Dark
                            ? SvgPicture.asset(
                                "assets/images/loader dark.svg",
                              )
                            : SvgPicture.asset(
                                "assets/images/loader light.svg",
                              ),
                      ),
                      SizedBox(
                        width: MediaQuery.of(context).size.width,
                        height: MediaQuery.of(context).size.height * 0.1,
                      )
                    ],
                  ),
          )),
    );
  }
}

class SearchLoader extends StatefulWidget {
  final Future future;
  final String provider;
  SearchLoader({@required this.future, @required this.provider});
  @override
  _SearchLoaderState createState() => _SearchLoaderState();
}

class _SearchLoaderState extends State<SearchLoader>
    with SingleTickerProviderStateMixin {
  AnimationController _controller;
  Animation<Color> animation;
  Future _future;

  @override
  void initState() {
    Provider.of<WallHavenProvider>(context, listen: false).wallsS = [];
    Provider.of<WallHavenProvider>(context, listen: false).pageGetQuery = 1;
    _future = widget.future;
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    animation = Provider.of<ThemeModel>(context, listen: false).returnTheme() ==
            ThemeType.Dark
        ? TweenSequence<Color>(
            [
              TweenSequenceItem(
                weight: 1.0,
                tween: ColorTween(
                  begin: Colors.white10,
                  end: Color(0x22FFFFFF),
                ),
              ),
              TweenSequenceItem(
                weight: 1.0,
                tween: ColorTween(
                  begin: Color(0x22FFFFFF),
                  end: Colors.white10,
                ),
              ),
            ],
          ).animate(_controller)
        : TweenSequence<Color>(
            [
              TweenSequenceItem(
                weight: 1.0,
                tween: ColorTween(
                  begin: Colors.black12.withOpacity(.1),
                  end: Colors.black.withOpacity(.14),
                ),
              ),
              TweenSequenceItem(
                weight: 1.0,
                tween: ColorTween(
                  begin: Colors.black.withOpacity(.14),
                  end: Colors.black.withOpacity(.1),
                ),
              ),
            ],
          ).animate(_controller)
      ..addListener(() {
        setState(() {});
      });
    _controller.repeat();
  }

  @override
  dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ScrollController controller =
        InheritedDataProvider.of(context).scrollController;
    return FutureBuilder(
      future: _future,
      builder: (ctx, snapshot) {
        if (snapshot == null) {
          print("snapshot null");
          return LoadingCards(controller: controller, animation: animation);
        }
        if (snapshot.connectionState == ConnectionState.waiting ||
            snapshot.connectionState == ConnectionState.none) {
          print("snapshot none, waiting");
          return LoadingCards(controller: controller, animation: animation);
        } else {
          // print("snapshot done");
          return HomeGrid(
            provider: widget.provider,
          );
        }
      },
    );
  }
}
