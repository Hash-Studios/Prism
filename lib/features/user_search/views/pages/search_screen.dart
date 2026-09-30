import 'package:Prism/analytics/analytics_service.dart';
import 'package:Prism/core/analytics/events/events.dart';
import 'package:Prism/core/di/injection.dart';
import 'package:Prism/core/widgets/home/wallpapers/loading.dart';
import 'package:Prism/features/user_search/biz/bloc/search_discovery_bloc.j.dart';
import 'package:Prism/features/user_search/data/wallpaper_search_service.dart';
import 'package:Prism/features/user_search/views/widgets/search_discovery_widget.dart';
import 'package:Prism/features/user_search/views/widgets/search_grid.dart';
import 'package:Prism/theme/jam_icons_icons.dart';
import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

@RoutePage()
class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
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

  final TextEditingController searchController = TextEditingController();
  Future<WallpaperSearchPage>? _search;
  bool isSubmitted = false;

  int _queryWordCount(String query) {
    return query.trim().split(RegExp(r'\s+')).where((segment) => segment.trim().isNotEmpty).length;
  }

  void _trackSearchSubmitted({required String query, required bool fromSuggestion, required String sourceContext}) {
    final String trimmedQuery = query.trim();
    if (trimmedQuery.isEmpty) return;
    analytics.track(
      SearchSubmittedEvent(
        provider: SearchProviderValue.wallhaven,
        queryLength: trimmedQuery.length,
        queryWordCount: _queryWordCount(trimmedQuery),
        sourceContext: sourceContext,
        fromSuggestion: fromSuggestion,
      ),
    );
  }

  void _triggerSearch(String query) {
    setState(() {
      isSubmitted = true;
      _search = getIt<WallpaperSearchService>().search(query);
    });
  }

  @override
  void initState() {
    tags.shuffle();
    super.initState();
  }

  @override
  void dispose() {
    searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final TextStyle? fieldStyle = theme.textTheme.headlineSmall?.copyWith(
      fontFamily: 'Satoshi',
      color: theme.colorScheme.secondary,
    );
    return Scaffold(
      backgroundColor: theme.primaryColor,
      appBar: AppBar(
        backgroundColor: theme.primaryColor,
        elevation: 0,
        surfaceTintColor: theme.primaryColor,
        automaticallyImplyLeading: false,
        titleSpacing: 0,
        title: Row(
          children: <Widget>[
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(4, 10, 4, 4),
                child: Column(
                  children: [
                    TextField(
                      cursorColor: theme.colorScheme.error,
                      style: fieldStyle,
                      controller: searchController,
                      onChanged: (text) {
                        if (text.trim().isEmpty && isSubmitted) {
                          setState(() => isSubmitted = false);
                        }
                      },
                      decoration: InputDecoration(
                        contentPadding: const EdgeInsets.only(left: 24, top: 12),
                        border: InputBorder.none,
                        disabledBorder: InputBorder.none,
                        enabledBorder: InputBorder.none,
                        focusedBorder: InputBorder.none,
                        hintText: 'Search...',
                        hintStyle: fieldStyle,
                        suffixIcon: Icon(JamIcons.search, color: theme.colorScheme.secondary),
                      ),
                      onSubmitted: (tex) {
                        final String query = tex.trim();
                        if (query.isEmpty) return;
                        _trackSearchSubmitted(query: query, fromSuggestion: false, sourceContext: 'search_textfield');
                        _triggerSearch(query);
                      },
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 6),
          ],
        ),
      ),
      body: isSubmitted
          ? FutureBuilder<WallpaperSearchPage>(
              future: _search,
              builder: (context, snapshot) {
                final WallpaperSearchPage? page = snapshot.data;
                if (page == null) {
                  return const LoadingCards();
                }
                if (page.results.isEmpty) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(32),
                      child: Text(
                        'No wallpapers found for "${searchController.text}".',
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.bodyLarge,
                      ),
                    ),
                  );
                }
                return SearchGrid(
                  key: ValueKey<Future<WallpaperSearchPage>?>(_search),
                  query: searchController.text,
                  provider: page.provider,
                  initialResults: page.results,
                );
              },
            )
          : BlocProvider<SearchDiscoveryBloc>(
              create: (_) => getIt<SearchDiscoveryBloc>()..add(const SearchDiscoveryEvent.fetchRequested()),
              child: SearchDiscoveryWidget(
                tags: tags,
                selectedTag: searchController.text,
                onTagPressed: (tag) {
                  analytics.track(
                    SearchTagSelectedEvent(provider: SearchProviderValue.wallhaven, tag: tag.toLowerCase()),
                  );
                  _trackSearchSubmitted(query: tag, fromSuggestion: true, sourceContext: 'search_tag');
                  searchController.text = tag;
                  _triggerSearch(tag);
                },
              ),
            ),
    );
  }
}
