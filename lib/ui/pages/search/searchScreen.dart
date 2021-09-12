import 'package:Prism/data/wallhaven/provider/wallhavenWithoutProvider.dart'
    as wdata;
import 'package:Prism/data/pexels/provider/pexelsWithoutProvider.dart' as pdata;
import 'package:Prism/global/searchProviderMenu.dart';
import 'package:Prism/global/svgAssets.dart';
import 'package:Prism/routes/router.dart';
import 'package:Prism/routes/routing_constants.dart';
import 'package:Prism/theme/jam_icons_icons.dart';
import 'package:Prism/theme/themeModeProvider.dart';
import 'package:Prism/ui/widgets/home/core/bottomNavBar.dart';
import 'package:Prism/ui/widgets/home/wallpapers/loading.dart';
import 'package:Prism/ui/widgets/search/searchGrid.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:provider/provider.dart';
import 'package:Prism/main.dart' as main;
import 'package:Prism/logger/logger.dart';

class SearchScreen extends StatefulWidget {
  @override
  _SearchScreenState createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  Future<bool> onWillPop() async {
    if (navStack.length > 1) navStack.removeLast();
    logger.d(navStack.toString());
    return true;
  }

  String? selectedProvider;
  SearchProviderMenuItem? selectedProviders;
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
    'Minimalism',
    'Mountains',
    'Field',
    'Chocolate',
    'Train',
    'Walking',
    'Food',
    'Design',
    'Love',
    'Wildlife',
    'Stock',
    'Trees',
    'Planets',
    'Space',
    'Winter',
    'Beach',
    'Ninja',
    'Summer',
    'Titan',
    'White',
  ];
  late bool isSubmitted;
  TextEditingController searchController = TextEditingController();
  Future? _future;
  @override
  void initState() {
    isSubmitted = false;

    selectedProvider = main.prefs
        .get('selectedSearchProvider', defaultValue: "WallHaven")
        .toString();
    selectedProviders = selectedProvider == "WallHaven"
        ? providers[0] as SearchProviderMenuItem
        : providers[1] as SearchProviderMenuItem;
    tags.shuffle();
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: onWillPop,
      child: Scaffold(
          backgroundColor: Theme.of(context).primaryColor,
          appBar: AppBar(
            automaticallyImplyLeading: false,
            titleSpacing: 0,
            title: Row(
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
                              cursorColor: Theme.of(context).errorColor,
                              style: Theme.of(context)
                                  .textTheme
                                  .headline5!
                                  .copyWith(
                                      color: Theme.of(context).accentColor),
                              controller: searchController,
                              decoration: InputDecoration(
                                contentPadding:
                                    const EdgeInsets.only(left: 30, top: 15),
                                border: InputBorder.none,
                                disabledBorder: InputBorder.none,
                                enabledBorder: InputBorder.none,
                                focusedBorder: InputBorder.none,
                                hintText: "Search",
                                hintStyle: Theme.of(context)
                                    .textTheme
                                    .headline5!
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
                                    wdata.wallsS = [];
                                    _future = wdata.getWallsbyQuery(
                                        tex,
                                        main.prefs.get('WHcategories') as int?,
                                        main.prefs.get('WHpurity') as int?);
                                  } else if (selectedProvider == "Pexels") {
                                    pdata.wallsPS = [];
                                    _future = pdata.getWallsPbyQuery(tex);
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
                    offset: const Offset(5, 30),
                    icon: Icon(JamIcons.more_vertical,
                        color: Theme.of(context).accentColor),
                    elevation: 4,
                    initialValue: selectedProviders,
                    onCanceled: () {
                      logger.d('You have not choosed anything');
                    },
                    color: Theme.of(context).hintColor,
                    tooltip: 'Providers',
                    onSelected: (dynamic choice) {
                      setState(() {
                        selectedProviders = choice as SearchProviderMenuItem;
                        selectedProvider = choice.title.toString();
                        main.prefs
                            .put('selectedSearchProvider', selectedProvider);
                        if (searchController.text != "") {
                          isSubmitted = true;
                          if (choice.title == "WallHaven") {
                            wdata.wallsS = [];
                            _future = wdata.getWallsbyQuery(
                                searchController.text,
                                main.prefs.get('WHcategories') as int?,
                                main.prefs.get('WHpurity') as int?);
                          } else if (choice.title == "Pexels") {
                            pdata.wallsPS = [];
                            _future =
                                pdata.getWallsPbyQuery(searchController.text);
                          }
                        }
                      });
                    },
                    itemBuilder: (BuildContext context) {
                      return providers.map((choice) {
                        return PopupMenuItem(
                          textStyle: Theme.of(context)
                              .textTheme
                              .headline4!
                              .copyWith(color: Theme.of(context).accentColor),
                          value: choice,
                          child: Row(
                            children: <Widget>[
                              Icon(choice.icon as IconData?,
                                  color: Theme.of(context).accentColor),
                              const SizedBox(width: 10),
                              Text(choice.title.toString()),
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
              preferredSize: const Size(double.infinity, 54),
              child: SizedBox(
                width: MediaQuery.of(context).size.width,
                height: 53,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  itemCount: tags.length + 1,
                  itemBuilder: (context, index) {
                    if (index == 0) {
                      return Container();
                      // return IconButton(
                      //   onPressed: () {
                      //     Navigator.pushNamed(context, userSearchRoute);
                      //   },
                      //   icon: const Icon(
                      //     JamIcons.users,
                      //   ),
                      // );
                    } else {
                      index = index - 1;
                      return Align(
                        child: Stack(
                          children: <Widget>[
                            Padding(
                              padding: const EdgeInsets.fromLTRB(5, 0, 2, 0),
                              child: ActionChip(
                                  pressElevation: 5,
                                  padding:
                                      const EdgeInsets.fromLTRB(14, 11, 14, 11),
                                  backgroundColor:
                                      searchController.text.toLowerCase() ==
                                              tags[index].toLowerCase()
                                          ? Theme.of(context).accentColor
                                          : Theme.of(context).hintColor,
                                  label: Text(tags[index],
                                      style: Theme.of(context)
                                          .textTheme
                                          .headline4!
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
                                        wdata.wallsS = [];
                                        _future = wdata.getWallsbyQuery(
                                            tags[index],
                                            main.prefs.get('WHcategories')
                                                as int?,
                                            main.prefs.get('WHpurity') as int?);
                                      } else if (selectedProvider == "Pexels") {
                                        pdata.wallsPS = [];
                                        _future =
                                            pdata.getWallsPbyQuery(tags[index]);
                                      }
                                    });
                                  }),
                            ),
                          ],
                        ),
                      );
                    }
                  },
                ),
              ),
            ),
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
                        child: Provider.of<ThemeModeExtended>(context)
                                    .getCurrentModeStyle(MediaQuery.of(context)
                                        .platformBrightness) ==
                                "Dark"
                            ? SvgPicture.string(
                                loaderDark
                                    .replaceAll(
                                        "181818",
                                        Theme.of(context)
                                            .primaryColor
                                            .value
                                            .toRadixString(16)
                                            .toString()
                                            .substring(2))
                                    .replaceAll(
                                        "E57697",
                                        Theme.of(context)
                                            .errorColor
                                            .toString()
                                            .replaceAll("Color(0xff", "")
                                            .replaceAll(")", ""))
                                    .replaceAll(
                                        "F0F0F0",
                                        Theme.of(context)
                                            .accentColor
                                            .value
                                            .toRadixString(16)
                                            .toString()
                                            .substring(2))
                                    .replaceAll(
                                        "2F2E41",
                                        Theme.of(context)
                                            .accentColor
                                            .value
                                            .toRadixString(16)
                                            .toString()
                                            .substring(2))
                                    .replaceAll(
                                        "3F3D56",
                                        Theme.of(context)
                                            .accentColor
                                            .value
                                            .toRadixString(16)
                                            .toString()
                                            .substring(2))
                                    .replaceAll(
                                        "2F2F2F",
                                        Theme.of(context)
                                            .hintColor
                                            .value
                                            .toRadixString(16)
                                            .toString()
                                            .substring(2)),
                              )
                            : SvgPicture.string(
                                loaderLight
                                    .replaceAll(
                                        "181818",
                                        Theme.of(context)
                                            .primaryColor
                                            .value
                                            .toRadixString(16)
                                            .toString()
                                            .substring(2))
                                    .replaceAll(
                                        "E57697",
                                        Theme.of(context)
                                            .errorColor
                                            .toString()
                                            .replaceAll("Color(0xff", "")
                                            .replaceAll(")", ""))
                                    .replaceAll(
                                        "F0F0F0",
                                        Theme.of(context)
                                            .accentColor
                                            .value
                                            .toRadixString(16)
                                            .toString()
                                            .substring(2))
                                    .replaceAll(
                                        "2F2E41",
                                        Theme.of(context)
                                            .accentColor
                                            .value
                                            .toRadixString(16)
                                            .toString()
                                            .substring(2))
                                    .replaceAll(
                                        "3F3D56",
                                        Theme.of(context)
                                            .accentColor
                                            .value
                                            .toRadixString(16)
                                            .toString()
                                            .substring(2))
                                    .replaceAll(
                                        "2F2F2F",
                                        Theme.of(context)
                                            .hintColor
                                            .value
                                            .toRadixString(16)
                                            .toString()
                                            .substring(2)),
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
  final Future? future;
  final String query;
  final String? selectedProvider;
  const SearchLoader(
      {required this.future,
      required this.query,
      required this.selectedProvider});
  @override
  _SearchLoaderState createState() => _SearchLoaderState();
}

class _SearchLoaderState extends State<SearchLoader> {
  Future? _future;

  @override
  void initState() {
    if (widget.selectedProvider == "WallHaven") {
      wdata.wallsS = [];
      wdata.pageGetQuery = 1;
      _future = widget.future;
    } else if (widget.selectedProvider == "Pexels") {
      pdata.wallsPS = [];
      pdata.pageGetQueryP = 1;
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
          logger.d("snapshot null");
          return const LoadingCards();
        }
        if (snapshot.connectionState == ConnectionState.waiting ||
            snapshot.connectionState == ConnectionState.none) {
          logger.d("snapshot none, waiting");
          return const LoadingCards();
        } else {
          return SearchGrid(
            query: widget.query,
            selectedProvider: widget.selectedProvider,
          );
        }
      },
    );
  }
}
