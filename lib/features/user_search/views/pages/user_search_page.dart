import 'package:Prism/analytics/analytics_service.dart';
import 'package:Prism/core/analytics/events/events.dart';
import 'package:Prism/core/router/app_router.dart';
import 'package:Prism/core/utils/status.dart';
import 'package:Prism/core/widgets/home/wallpapers/loading.dart';
import 'package:Prism/features/user_search/domain/entities/user_search_user.dart';
import 'package:Prism/features/user_search/user_search.dart';
import 'package:Prism/theme/jam_icons_icons.dart';
import 'package:auto_route/auto_route.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

@RoutePage(name: 'UserSearchRoute')
class UserSearch extends StatefulWidget {
  const UserSearch({super.key});

  @override
  _UserSearchState createState() => _UserSearchState();
}

class _UserSearchState extends State<UserSearch> {
  TextEditingController searchController = TextEditingController();
  late bool isSubmitted;

  @override
  void initState() {
    isSubmitted = false;
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      context.read<UserSearchBloc>().add(const UserSearchEvent.cleared());
    });
  }

  @override
  void dispose() {
    searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).primaryColor,
      appBar: AppBar(
        automaticallyImplyLeading: false,
        titleSpacing: 0,
        title: Padding(
          padding: const EdgeInsets.only(top: 6.0),
          child: SizedBox(
            width: MediaQuery.of(context).size.width,
            child: Padding(
              padding: const EdgeInsets.all(4.0),
              child: Container(
                decoration: BoxDecoration(borderRadius: BorderRadius.circular(500), color: Theme.of(context).hintColor),
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
                    if (tex.trim().isNotEmpty) {
                      final String trimmed = tex.trim();
                      analytics.track(
                        UserSearchSubmittedEvent(queryLength: trimmed.length, sourceContext: 'user_search_textfield'),
                      );
                      setState(() {
                        isSubmitted = true;
                      });
                      context.read<UserSearchBloc>().add(UserSearchEvent.searchRequested(query: trimmed));
                      return;
                    }
                    context.read<UserSearchBloc>().add(const UserSearchEvent.cleared());
                  },
                ),
              ),
            ),
          ),
        ),
      ),
      body: const _UserSearchLoader(),
    );
  }
}

class _UserSearchLoader extends StatelessWidget {
  const _UserSearchLoader();

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<UserSearchBloc, UserSearchState>(
      builder: (context, state) {
        if (state.status == LoadStatus.initial) {
          return const _SearchHint();
        }
        if (state.status == LoadStatus.loading) {
          return const LoadingCards();
        }
        if (state.status == LoadStatus.failure) {
          return const _SearchHint();
        }
        if (state.users.isEmpty) {
          return const _NoResults();
        }
        return _CreatorList(users: state.users, queryLength: state.query.trim().length);
      },
    );
  }
}

class _SearchHint extends StatelessWidget {
  const _SearchHint();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(JamIcons.user_circle, size: 48, color: Theme.of(context).colorScheme.secondary.withValues(alpha: 0.3)),
          const SizedBox(height: 12),
          Text(
            'Search for creators by name',
            style: TextStyle(
              fontFamily: 'Satoshi',
              fontSize: 14,
              color: Theme.of(context).colorScheme.secondary.withValues(alpha: 0.5),
            ),
          ),
        ],
      ),
    );
  }
}

class _NoResults extends StatelessWidget {
  const _NoResults();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Text(
        'No creators found',
        style: TextStyle(
          fontFamily: 'Satoshi',
          fontSize: 14,
          color: Theme.of(context).colorScheme.secondary.withValues(alpha: 0.5),
        ),
      ),
    );
  }
}

class _CreatorList extends StatelessWidget {
  const _CreatorList({required this.users, required this.queryLength});
  final List<UserSearchUser> users;
  final int queryLength;

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      itemCount: users.length,
      itemBuilder: (context, index) => _CreatorCard(user: users[index], index: index, queryLength: queryLength),
    );
  }
}

class _CreatorCard extends StatelessWidget {
  const _CreatorCard({required this.user, required this.index, required this.queryLength});
  final UserSearchUser user;
  final int index;
  final int queryLength;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      leading: CircleAvatar(
        radius: 22,
        foregroundImage: CachedNetworkImageProvider(user.profilePhoto),
        backgroundColor: Theme.of(context).colorScheme.secondary.withValues(alpha: 0.1),
      ),
      title: Text(
        user.name,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          fontFamily: 'Proxima Nova',
          fontWeight: FontWeight.bold,
          color: Theme.of(context).colorScheme.secondary,
        ),
      ),
      subtitle: Text(
        '@${user.username}',
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          fontFamily: 'Proxima Nova',
          color: Theme.of(context).colorScheme.secondary.withValues(alpha: 0.6),
        ),
      ),
      trailing: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Text(
            '${user.followers.length}',
            style: TextStyle(
              fontFamily: 'Proxima Nova',
              fontWeight: FontWeight.bold,
              fontSize: 14,
              color: Theme.of(context).colorScheme.secondary,
            ),
          ),
          Text(
            'followers',
            style: TextStyle(
              fontFamily: 'Proxima Nova',
              fontSize: 11,
              color: Theme.of(context).colorScheme.secondary.withValues(alpha: 0.5),
            ),
          ),
        ],
      ),
      onTap: () {
        analytics.track(
          UserSearchResultOpenedEvent(
            resultUserId: user.id.trim().isNotEmpty ? user.id : user.email,
            index: index,
            queryLength: queryLength,
          ),
        );
        context.router.push(ProfileRoute(profileIdentifier: user.email));
      },
    );
  }
}
