import 'package:Prism/analytics/analytics_service.dart';
import 'package:Prism/core/analytics/events/events.dart';
import 'package:Prism/core/widgets/coins/coin_balance_chip.dart';
import 'package:Prism/core/widgets/home/wallpapers/loading.dart';
import 'package:Prism/data/pexels/provider/pexelsWithoutProvider.dart' as pdata;
import 'package:Prism/data/wallhaven/provider/wallhavenWithoutProvider.dart' as wdata;
import 'package:Prism/features/theme_mode/views/theme_mode_bloc_utils.dart';
import 'package:Prism/features/user_search/views/widgets/search_grid.dart';
import 'package:Prism/global/searchProviderMenu.dart';
import 'package:Prism/global/svgAssets.dart';
import 'package:Prism/logger/logger.dart';
import 'package:Prism/main.dart' as main;
import 'package:Prism/theme/jam_icons_icons.dart';
import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

@RoutePage()
class SearchScreen extends StatefulWidget {
  @override
  _SearchScreenState createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  String? selectedProvider;
  SearchProviderMenuItem? selectedProviders;
  final List providers = [
    SearchProviderMenuItem(title: 'WallHaven', icon: JamIcons.arrow_right),
    SearchProviderMenuItem(title: 'Pexels', icon: JamIcons.arrow_right),
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
    '8bit',
    'Fantasy',
    'Fashion',
    'Fitness',
    'Fruits',
    'Futuristic',
    'Gems',
    'Graffiti',
    'Halloween',
    'Hipster',
    'Holidays',
    'Industry',
    'Interiors',
    'Kids',
    'Landscapes',
    'Macro',
    'Nature',
    'Night',
    'People',
    'Plants',
    'Portraits',
    'Retro',
    'Robots',
    'Science',
    'Sports',
    'Technics',
    'Textures',
    'Transport',
    'Travel',
    'Wedding',
    'Zombies',
    'Cute',
    'Fairy',
    'Fairytale',
    'Funny',
    'Geometric',
    'Graphic',
  ];
  late bool isSubmitted;
  TextEditingController searchController = TextEditingController();
  Future? _future;

  SearchProviderValue _providerFromTitle(String? providerTitle) {
    switch (providerTitle) {
      case 'Pexels':
        return SearchProviderValue.pexels;
      case 'WallHaven':
        return SearchProviderValue.wallhaven;
      default:
        return SearchProviderValue.wallhaven;
    }
  }

  int _queryWordCount(String query) {
    return query.trim().split(RegExp(r'\s+')).where((segment) => segment.trim().isNotEmpty).length;
  }

  void _trackSearchSubmitted({required String query, required bool fromSuggestion, required String sourceContext}) {
    final String trimmedQuery = query.trim();
    if (trimmedQuery.isEmpty) {
      return;
    }
    analytics.track(
      SearchSubmittedEvent(
        provider: _providerFromTitle(selectedProvider),
        queryLength: trimmedQuery.length,
        queryWordCount: _queryWordCount(trimmedQuery),
        sourceContext: sourceContext,
        fromSuggestion: fromSuggestion,
      ),
    );
  }

  @override
  void initState() {
    isSubmitted = false;

    selectedProvider = main.prefs.get('selectedSearchProvider', defaultValue: "WallHaven").toString();
    selectedProviders = selectedProvider == "WallHaven"
        ? providers[0] as SearchProviderMenuItem
        : providers[1] as SearchProviderMenuItem;
    tags.shuffle();
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).primaryColor,
      appBar: AppBar(
        automaticallyImplyLeading: false,
        titleSpacing: 0,
        title: Row(
          children: <Widget>[
            Expanded(
              child: Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Padding(
                  padding: const EdgeInsets.all(4),
                  child: Column(
                    children: [
                      Container(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(500),
                          color: Theme.of(context).hintColor,
                        ),
                        child: TextField(
                          cursorColor: Theme.of(context).colorScheme.error,
                          style: Theme.of(
                            context,
                          ).textTheme.headlineSmall!.copyWith(color: Theme.of(context).colorScheme.secondary),
                          controller: searchController,
                          decoration: InputDecoration(
                            contentPadding: const EdgeInsets.only(left: 30, top: 15),
                            border: InputBorder.none,
                            disabledBorder: InputBorder.none,
                            enabledBorder: InputBorder.none,
                            focusedBorder: InputBorder.none,
                            hintText: "Search",
                            hintStyle: Theme.of(
                              context,
                            ).textTheme.headlineSmall!.copyWith(color: Theme.of(context).colorScheme.secondary),
                            suffixIcon: Icon(JamIcons.search, color: Theme.of(context).colorScheme.secondary),
                          ),
                          onSubmitted: (tex) {
                            _trackSearchSubmitted(query: tex, fromSuggestion: false, sourceContext: 'search_textfield');
                            setState(() {
                              isSubmitted = true;
                              if (selectedProvider == "WallHaven") {
                                wdata.wallsS = [];
                                _future = wdata.getWallsbyQuery(
                                  tex,
                                  main.prefs.get('WHcategories') as int?,
                                  main.prefs.get('WHpurity') as int?,
                                );
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
              width: 40,
              child: PopupMenuButton(
                offset: const Offset(5, 30),
                icon: Icon(JamIcons.more_vertical, color: Theme.of(context).colorScheme.secondary),
                elevation: 4,
                initialValue: selectedProviders,
                onCanceled: () {
                  logger.d('You have not choosed anything');
                },
                color: Theme.of(context).hintColor,
                tooltip: 'Providers',
                onSelected: (dynamic choice) {
                  final SearchProviderValue previousProvider = _providerFromTitle(selectedProvider);
                  setState(() {
                    selectedProviders = choice as SearchProviderMenuItem;
                    selectedProvider = choice.title.toString();
                    main.prefs.put('selectedSearchProvider', selectedProvider);
                    analytics.track(
                      SearchProviderChangedEvent(
                        fromProvider: previousProvider,
                        toProvider: _providerFromTitle(selectedProvider),
                      ),
                    );
                    if (searchController.text != "") {
                      isSubmitted = true;
                      _trackSearchSubmitted(
                        query: searchController.text,
                        fromSuggestion: false,
                        sourceContext: 'provider_switch',
                      );
                      if (choice.title == "WallHaven") {
                        wdata.wallsS = [];
                        _future = wdata.getWallsbyQuery(
                          searchController.text,
                          main.prefs.get('WHcategories') as int?,
                          main.prefs.get('WHpurity') as int?,
                        );
                      } else if (choice.title == "Pexels") {
                        pdata.wallsPS = [];
                        _future = pdata.getWallsPbyQuery(searchController.text);
                      }
                    }
                  });
                },
                itemBuilder: (BuildContext context) {
                  return providers.map((choice) {
                    return PopupMenuItem(
                      textStyle: Theme.of(
                        context,
                      ).textTheme.headlineMedium!.copyWith(color: Theme.of(context).colorScheme.secondary),
                      value: choice,
                      child: Row(
                        children: <Widget>[
                          Icon(choice.icon as IconData?, color: Theme.of(context).colorScheme.secondary),
                          const SizedBox(width: 10),
                          Text(choice.title.toString()),
                        ],
                      ),
                    );
                  }).toList();
                },
              ),
            ),
            const SizedBox(width: 6),
            const CoinBalanceChip(sourceTag: 'coins.chip.search_screen'),
            const SizedBox(width: 4),
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
                  //     context.router.push(const UserSearchRoute());
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
                            padding: const EdgeInsets.fromLTRB(14, 11, 14, 11),
                            backgroundColor: searchController.text.toLowerCase() == tags[index].toLowerCase()
                                ? Theme.of(context).colorScheme.secondary
                                : Theme.of(context).hintColor,
                            label: Text(
                              tags[index],
                              style: Theme.of(context).textTheme.headlineMedium!.copyWith(
                                color: searchController.text.toLowerCase() == tags[index].toLowerCase()
                                    ? Theme.of(context).primaryColor
                                    : Theme.of(context).colorScheme.secondary,
                              ),
                            ),
                            onPressed: () {
                              analytics.track(
                                SearchTagSelectedEvent(
                                  provider: _providerFromTitle(selectedProvider),
                                  tag: tags[index].toLowerCase(),
                                ),
                              );
                              _trackSearchSubmitted(
                                query: tags[index],
                                fromSuggestion: true,
                                sourceContext: 'search_tag',
                              );
                              setState(() {
                                searchController.text = tags[index];
                                isSubmitted = true;
                                if (selectedProvider == "WallHaven") {
                                  wdata.wallsS = [];
                                  _future = wdata.getWallsbyQuery(
                                    tags[index],
                                    main.prefs.get('WHcategories') as int?,
                                    main.prefs.get('WHpurity') as int?,
                                  );
                                } else if (selectedProvider == "Pexels") {
                                  pdata.wallsPS = [];
                                  _future = pdata.getWallsPbyQuery(tags[index]);
                                }
                              });
                            },
                          ),
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
      body: isSubmitted
          ? SearchLoader(future: _future, query: searchController.text, selectedProvider: selectedProvider)
          : Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: <Widget>[
                SizedBox(
                  width: MediaQuery.of(context).size.width,
                  child: context.prismModeStyleForContext() == "Dark"
                      ? SvgPicture.string(
                          loaderDark
                              .replaceAll(
                                "181818",
                                Theme.of(context).primaryColor.toARGB32().toRadixString(16).substring(2),
                              )
                              .replaceAll(
                                "E57697",
                                Theme.of(
                                  context,
                                ).colorScheme.error.toString().replaceAll("Color(0xff", "").replaceAll(")", ""),
                              )
                              .replaceAll(
                                "F0F0F0",
                                Theme.of(context).colorScheme.secondary.toARGB32().toRadixString(16).substring(2),
                              )
                              .replaceAll(
                                "2F2E41",
                                Theme.of(context).colorScheme.secondary.toARGB32().toRadixString(16).substring(2),
                              )
                              .replaceAll(
                                "3F3D56",
                                Theme.of(context).colorScheme.secondary.toARGB32().toRadixString(16).substring(2),
                              )
                              .replaceAll(
                                "2F2F2F",
                                Theme.of(context).hintColor.toARGB32().toRadixString(16).substring(2),
                              ),
                        )
                      : SvgPicture.string(
                          loaderLight
                              .replaceAll(
                                "181818",
                                Theme.of(context).primaryColor.toARGB32().toRadixString(16).substring(2),
                              )
                              .replaceAll(
                                "E57697",
                                Theme.of(
                                  context,
                                ).colorScheme.error.toString().replaceAll("Color(0xff", "").replaceAll(")", ""),
                              )
                              .replaceAll(
                                "F0F0F0",
                                Theme.of(context).colorScheme.secondary.toARGB32().toRadixString(16).substring(2),
                              )
                              .replaceAll(
                                "2F2E41",
                                Theme.of(context).colorScheme.secondary.toARGB32().toRadixString(16).substring(2),
                              )
                              .replaceAll(
                                "3F3D56",
                                Theme.of(context).colorScheme.secondary.toARGB32().toRadixString(16).substring(2),
                              )
                              .replaceAll(
                                "2F2F2F",
                                Theme.of(context).hintColor.toARGB32().toRadixString(16).substring(2),
                              ),
                        ),
                ),
                SizedBox(width: MediaQuery.of(context).size.width, height: MediaQuery.of(context).size.height * 0.1),
              ],
            ),
    );
  }
}

class SearchLoader extends StatefulWidget {
  final Future? future;
  final String query;
  final String? selectedProvider;
  const SearchLoader({required this.future, required this.query, required this.selectedProvider});
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
        if (snapshot.connectionState == ConnectionState.waiting || snapshot.connectionState == ConnectionState.none) {
          logger.d("snapshot none, waiting");
          return const LoadingCards();
        } else {
          return SearchGrid(query: widget.query, selectedProvider: widget.selectedProvider);
        }
      },
    );
  }
}
