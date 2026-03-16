import 'package:Prism/analytics/analytics_service.dart';
import 'package:Prism/core/analytics/events/events.dart';
import 'package:Prism/core/di/injection.dart';
import 'package:Prism/core/persistence/data_sources/settings_local_data_source.dart';
import 'package:Prism/core/wallpaper/wallpaper_source.dart';
import 'package:Prism/core/widgets/coins/coin_balance_chip.dart';
import 'package:Prism/core/widgets/home/wallpapers/loading.dart';
import 'package:Prism/data/pexels/provider/pexelsWithoutProvider.dart' as pdata;
import 'package:Prism/data/wallhaven/provider/wallhavenWithoutProvider.dart' as wdata;
import 'package:Prism/features/user_search/biz/bloc/search_discovery_bloc.j.dart';
import 'package:Prism/features/user_search/views/widgets/search_discovery_widget.dart';
import 'package:Prism/features/user_search/views/widgets/search_grid.dart';
import 'package:Prism/logger/logger.dart';
import 'package:Prism/theme/jam_icons_icons.dart';
import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

@RoutePage()
class SearchScreen extends StatefulWidget {
  @override
  _SearchScreenState createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final SettingsLocalDataSource _settingsLocal = getIt<SettingsLocalDataSource>();

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

  // Default provider for free-text/tag searches
  static const String _defaultProvider = 'WallHaven';

  String _providerStringForSource(WallpaperSource source) =>
      source == WallpaperSource.pexels ? 'Pexels' : 'WallHaven';

  SearchProviderValue _providerValueFromString(String provider) {
    return provider == 'Pexels' ? SearchProviderValue.pexels : SearchProviderValue.wallhaven;
  }

  int _queryWordCount(String query) {
    return query.trim().split(RegExp(r'\s+')).where((segment) => segment.trim().isNotEmpty).length;
  }

  void _trackSearchSubmitted({
    required String query,
    required bool fromSuggestion,
    required String sourceContext,
    String provider = _defaultProvider,
  }) {
    final String trimmedQuery = query.trim();
    if (trimmedQuery.isEmpty) return;
    analytics.track(
      SearchSubmittedEvent(
        provider: _providerValueFromString(provider),
        queryLength: trimmedQuery.length,
        queryWordCount: _queryWordCount(trimmedQuery),
        sourceContext: sourceContext,
        fromSuggestion: fromSuggestion,
      ),
    );
  }

  void _triggerSearch(String query, String provider) {
    setState(() {
      isSubmitted = true;
      if (provider == 'WallHaven') {
        wdata.wallsS = [];
        _future = wdata.getWallsbyQuery(
          query,
          _settingsLocal.get<int>('WHcategories', defaultValue: 100),
          _settingsLocal.get<int>('WHpurity', defaultValue: 100),
        );
      } else {
        pdata.wallsPS = [];
        _future = pdata.getWallsPbyQuery(query);
      }
    });
  }

  @override
  void initState() {
    isSubmitted = false;
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
                          style: Theme.of(context)
                              .textTheme
                              .headlineSmall!
                              .copyWith(color: Theme.of(context).colorScheme.secondary),
                          controller: searchController,
                          decoration: InputDecoration(
                            contentPadding: const EdgeInsets.only(left: 30, top: 15),
                            border: InputBorder.none,
                            disabledBorder: InputBorder.none,
                            enabledBorder: InputBorder.none,
                            focusedBorder: InputBorder.none,
                            hintText: 'Search',
                            hintStyle: Theme.of(context)
                                .textTheme
                                .headlineSmall!
                                .copyWith(color: Theme.of(context).colorScheme.secondary),
                            suffixIcon: Icon(JamIcons.search, color: Theme.of(context).colorScheme.secondary),
                          ),
                          onSubmitted: (tex) {
                            final String query = tex.trim();
                            if (query.isEmpty) return;
                            _trackSearchSubmitted(
                              query: query,
                              fromSuggestion: false,
                              sourceContext: 'search_textfield',
                            );
                            _triggerSearch(query, _defaultProvider);
                          },
                        ),
                      ),
                    ],
                  ),
                ),
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
                                  provider: _providerValueFromString(_defaultProvider),
                                  tag: tags[index].toLowerCase(),
                                ),
                              );
                              _trackSearchSubmitted(
                                query: tags[index],
                                fromSuggestion: true,
                                sourceContext: 'search_tag',
                              );
                              searchController.text = tags[index];
                              _triggerSearch(tags[index], _defaultProvider);
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
          ? _SearchLoader(future: _future, query: searchController.text, selectedProvider: _defaultProvider)
          : BlocProvider<SearchDiscoveryBloc>(
              create: (_) => getIt<SearchDiscoveryBloc>()..add(const SearchDiscoveryEvent.fetchRequested()),
              child: SearchDiscoveryWidget(
                onSearch: (String query, WallpaperSource source) {
                  final String provider = _providerStringForSource(source);
                  _trackSearchSubmitted(
                    query: query,
                    fromSuggestion: true,
                    sourceContext: 'discovery_category',
                    provider: provider,
                  );
                  searchController.text = query;
                  _triggerSearch(query, provider);
                },
              ),
            ),
    );
  }
}

class _SearchLoader extends StatefulWidget {
  final Future? future;
  final String query;
  final String? selectedProvider;
  const _SearchLoader({required this.future, required this.query, required this.selectedProvider});
  @override
  _SearchLoaderState createState() => _SearchLoaderState();
}

class _SearchLoaderState extends State<_SearchLoader> {
  Future? _future;

  @override
  void initState() {
    if (widget.selectedProvider == 'WallHaven') {
      wdata.wallsS = [];
      wdata.pageGetQuery = 1;
      _future = widget.future;
    } else if (widget.selectedProvider == 'Pexels') {
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
          logger.d('snapshot none, waiting');
          return const LoadingCards();
        } else {
          return SearchGrid(query: widget.query, selectedProvider: widget.selectedProvider);
        }
      },
    );
  }
}
