import 'package:Prism/data/wallhaven/provider/wallhavenWithoutProvider.dart'
    as WData;
import 'package:Prism/data/pexels/provider/pexelsWithoutProvider.dart' as PData;
import 'package:Prism/global/searchProviderMenu.dart';
import 'package:Prism/routes/router.dart';
import 'package:Prism/theme/jam_icons_icons.dart';
import 'package:Prism/theme/themeModel.dart';
import 'package:Prism/ui/widgets/home/bottomNavBar.dart';
import 'package:Prism/ui/widgets/home/loading.dart';
import 'package:Prism/ui/widgets/searchGrid.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:provider/provider.dart';

class SearchScreen extends StatefulWidget {
  @override
  _SearchScreenState createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  Future<bool> onWillPop() async {
    if (navStack.length > 1) navStack.removeLast();
    print(navStack);
    return true;
  }

  String selectedProvider;
  var selectedProviders;
  final List providers = [
    SearchProviderMenuItem(title: 'WallHaven', icon: JamIcons.arrow_right),
    SearchProviderMenuItem(title: 'Pexels', icon: JamIcons.arrow_right)
  ];
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
    selectedProvider = "WallHaven";
    selectedProviders = providers[0];
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
            title: Row(
              mainAxisAlignment: MainAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Padding(
                  padding: const EdgeInsets.only(top: 6.0),
                  child: SizedBox(
                    width: MediaQuery.of(context).size.width * 0.9,
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
                                  .copyWith(
                                      color: Theme.of(context).accentColor),
                              controller: searchController,
                              decoration: InputDecoration(
                                contentPadding:
                                    EdgeInsets.only(left: 30, top: 15),
                                border: InputBorder.none,
                                disabledBorder: InputBorder.none,
                                enabledBorder: InputBorder.none,
                                focusedBorder: InputBorder.none,
                                hintText: "Search",
                                hintStyle: Theme.of(context)
                                    .textTheme
                                    .headline5
                                    .copyWith(
                                        color: Theme.of(context).accentColor),
                                suffixIcon: Icon(
                                  JamIcons.search,
                                  color: Theme.of(context).accentColor,
                                ),
                              ),
                              onSubmitted: (tex) {
                                setState(() {
                                  isSubmitted = true;
                                  if (selectedProvider == "WallHaven") {
                                    WData.wallsS = [];
                                    _future = WData.getWallsbyQuery(tex);
                                  } else if (selectedProvider == "Pexels") {
                                    PData.wallsPS = [];
                                    _future = PData.getWallsPbyQuery(tex);
                                  }
                                });
                              },
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                SizedBox(
                  width: MediaQuery.of(context).size.width * 0.1,
                  child: PopupMenuButton(
                    icon: Icon(JamIcons.more_vertical),
                    elevation: 4,
                    initialValue: selectedProviders,
                    onCanceled: () {
                      print('You have not choosed anything');
                    },
                    tooltip: 'Providers',
                    onSelected: (choice) {
                      setState(() {
                        selectedProviders = choice;
                        selectedProvider = choice.title;
                        if (searchController.text != "") {
                          isSubmitted = true;
                          if (choice.title == "WallHaven") {
                            WData.wallsS = [];
                            _future =
                                WData.getWallsbyQuery(searchController.text);
                          } else if (choice.title == "Pexels") {
                            PData.wallsPS = [];
                            _future =
                                PData.getWallsPbyQuery(searchController.text);
                          }
                        }
                      });
                    },
                    itemBuilder: (BuildContext context) {
                      return providers.map((choice) {
                        return PopupMenuItem(
                          textStyle: Theme.of(context)
                              .textTheme
                              .headline4
                              .copyWith(color: Theme.of(context).accentColor),
                          value: choice,
                          child: Row(
                            children: <Widget>[
                              Icon(choice.icon),
                              SizedBox(width: 10),
                              Text(choice.title),
                            ],
                          ),
                        );
                      }).toList();
                    },
                  ),
                )
              ],
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
                                  backgroundColor:
                                      searchController.text.toLowerCase() ==
                                              tags[index].toLowerCase()
                                          ? Theme.of(context).accentColor
                                          : Theme.of(context).hintColor,
                                  label: Text(tags[index],
                                      style: Theme.of(context)
                                          .textTheme
                                          .headline4
                                          .copyWith(
                                              color: searchController.text
                                                          .toLowerCase() ==
                                                      tags[index].toLowerCase()
                                                  ? Theme.of(context)
                                                      .primaryColor
                                                  : Theme.of(context)
                                                      .accentColor)),
                                  onPressed: () {
                                    setState(() {
                                      searchController.text = tags[index];
                                      isSubmitted = true;
                                      if (selectedProvider == "WallHaven") {
                                        WData.wallsS = [];
                                        _future =
                                            WData.getWallsbyQuery(tags[index]);
                                      } else if (selectedProvider == "Pexels") {
                                        PData.wallsPS = [];
                                        _future =
                                            PData.getWallsPbyQuery(tags[index]);
                                      }
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
                    query: searchController.text,
                    selectedProvider: selectedProvider,
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
  final String query;
  final String selectedProvider;
  SearchLoader(
      {@required this.future,
      @required this.query,
      @required this.selectedProvider});
  @override
  _SearchLoaderState createState() => _SearchLoaderState();
}

class _SearchLoaderState extends State<SearchLoader> {
  Future _future;

  @override
  void initState() {
    if (widget.selectedProvider == "WallHaven") {
      WData.wallsS = [];
      WData.pageGetQuery = 1;
      _future = widget.future;
    } else if (widget.selectedProvider == "Pexels") {
      PData.wallsPS = [];
      PData.pageGetQueryP = 1;
      _future = widget.future;
    }

    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder(
      future: _future,
      builder: (ctx, snapshot) {
        if (snapshot == null) {
          print("snapshot null");
          return LoadingCards();
        }
        if (snapshot.connectionState == ConnectionState.waiting ||
            snapshot.connectionState == ConnectionState.none) {
          print("snapshot none, waiting");
          return LoadingCards();
        } else {
          // print("snapshot done");
          return SearchGrid(
            query: widget.query,
            selectedProvider: widget.selectedProvider,
          );
        }
      },
    );
  }
}
