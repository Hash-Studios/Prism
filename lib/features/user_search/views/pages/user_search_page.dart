import 'package:Prism/core/router/app_router.dart';
import 'package:Prism/core/utils/status.dart';
import 'package:Prism/core/utils/url_launcher_compat.dart';
import 'package:Prism/core/widgets/home/wallpapers/loading.dart';
import 'package:Prism/core/widgets/popup/noLoadLinkPopUp.dart';
import 'package:Prism/features/user_search/domain/entities/user_search_user.dart';
import 'package:Prism/features/user_search/user_search.dart';
import 'package:Prism/global/svgAssets.dart';
import 'package:Prism/theme/jam_icons_icons.dart';
import 'package:auto_route/auto_route.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_svg/flutter_svg.dart';

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
                    hintText: "Search",
                    hintStyle: Theme.of(context)
                        .textTheme
                        .headlineSmall!
                        .copyWith(color: Theme.of(context).colorScheme.secondary),
                    suffixIcon: Icon(
                      JamIcons.search,
                      color: Theme.of(context).colorScheme.secondary,
                    ),
                  ),
                  onSubmitted: (tex) {
                    if (tex.trim().isNotEmpty) {
                      setState(() {
                        isSubmitted = true;
                      });
                      context.read<UserSearchBloc>().add(
                            UserSearchEvent.searchRequested(query: tex.trim()),
                          );
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
      body: const UserSearchLoader(),
    );
  }
}

class UserSearchLoader extends StatelessWidget {
  const UserSearchLoader({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<UserSearchBloc, UserSearchState>(
      builder: (context, state) {
        if (state.status == LoadStatus.initial || state.status == LoadStatus.loading) {
          return const LoadingCards();
        }
        if (state.status == LoadStatus.failure) {
          return const LoadingCards();
        }
        return UsersResultList(users: state.users);
      },
    );
  }
}

class UsersResultList extends StatefulWidget {
  const UsersResultList({required this.users, super.key});
  final List<UserSearchUser> users;

  @override
  _UsersResultListState createState() => _UsersResultListState();
}

class _UsersResultListState extends State<UsersResultList> {
  List<bool> generateItems(int numberOfItems) {
    return List<bool>.generate(numberOfItems, (int index) {
      return false;
    });
  }

  late List<bool> _data;
  @override
  void initState() {
    super.initState();
    _data = generateItems(widget.users.length);
  }

  @override
  void didUpdateWidget(covariant UsersResultList oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.users.length != widget.users.length) {
      _data = generateItems(widget.users.length);
    }
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: ExpansionPanelList(
        animationDuration: const Duration(milliseconds: 300),
        elevation: 0,
        dividerColor: Theme.of(context).colorScheme.error,
        expansionCallback: (int index, bool isExpanded) {
          setState(() {
            _data[index] = !isExpanded;
          });
        },
        children: widget.users.map<ExpansionPanel>((UserSearchUser user) {
          return ExpansionPanel(
            canTapOnHeader: true,
            backgroundColor: _data[widget.users.indexOf(user)]
                ? Theme.of(context).colorScheme.error
                : Theme.of(context).primaryColor,
            headerBuilder: (BuildContext context, bool isExpanded) {
              return ListTile(
                title: Row(
                  children: [
                    Padding(
                      padding: EdgeInsets.all(_data[widget.users.indexOf(user)] ? 2 : 8.0),
                      child: CircleAvatar(
                        foregroundImage: CachedNetworkImageProvider(
                          user.profilePhoto,
                        ),
                        radius: _data[widget.users.indexOf(user)] ? 0 : 16,
                      ),
                    ),
                    Text(
                      user.name,
                      style: Theme.of(context).textTheme.headlineSmall!.copyWith(
                            color: Theme.of(context).colorScheme.secondary,
                          ),
                    ),
                  ],
                ),
                tileColor: _data[widget.users.indexOf(user)]
                    ? Theme.of(context).colorScheme.error
                    : Theme.of(context).primaryColor,
              );
            },
            body: ColoredBox(
              color: _data[widget.users.indexOf(user)]
                  ? Theme.of(context).colorScheme.error
                  : Theme.of(context).primaryColor,
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Card(
                  color: Theme.of(context).primaryColor,
                  elevation: 10,
                  child: Stack(
                    children: [
                      Column(
                        children: [
                          ClipRRect(
                            borderRadius: const BorderRadius.only(
                              topLeft: Radius.circular(8),
                              topRight: Radius.circular(8),
                            ),
                            child: (user.coverPhoto == null)
                                ? SvgPicture.string(
                                    defaultHeader
                                        .replaceAll(
                                          "#181818",
                                          "#${Theme.of(context).primaryColor.toARGB32().toRadixString(16).substring(2)}",
                                        )
                                        .replaceAll(
                                          "#E77597",
                                          "#${Theme.of(context).colorScheme.error.toARGB32().toRadixString(16).substring(2)}",
                                        ),
                                    fit: BoxFit.cover,
                                    width: MediaQuery.of(context).size.width,
                                    height: MediaQuery.of(context).size.height * 0.19,
                                  )
                                : CachedNetworkImage(
                                    imageUrl: user.coverPhoto!,
                                    fit: BoxFit.cover,
                                    width: MediaQuery.of(context).size.width,
                                    height: MediaQuery.of(context).size.height * 0.19,
                                  ),
                          ),
                          const SizedBox(
                            width: double.maxFinite,
                            height: 37,
                          ),
                          Container(
                            padding: const EdgeInsets.fromLTRB(12, 4, 12, 0),
                            width: double.maxFinite,
                            height: user.links.keys.toList().isEmpty
                                ? MediaQuery.of(context).size.height * 0.21 - 37
                                : MediaQuery.of(context).size.height * 0.27 - 37,
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                              children: [
                                SizedBox(
                                  width: MediaQuery.of(context).size.width * 0.7,
                                  child: Text(
                                    user.name,
                                    textAlign: TextAlign.center,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      fontFamily: "Proxima Nova",
                                      color: Theme.of(context).colorScheme.secondary,
                                      fontSize: 22,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ),
                                const SizedBox(
                                  height: 2,
                                ),
                                SizedBox(
                                  width: MediaQuery.of(context).size.width * 0.7,
                                  child: Text(
                                    "@${user.username}",
                                    textAlign: TextAlign.center,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      fontFamily: "Proxima Nova",
                                      color: Theme.of(context).colorScheme.secondary.withValues(alpha: 0.6),
                                      fontSize: 16,
                                      fontWeight: FontWeight.normal,
                                    ),
                                  ),
                                ),
                                const SizedBox(
                                  height: 15,
                                ),
                                SizedBox(
                                  width: MediaQuery.of(context).size.width * 0.7,
                                  child: Text(
                                    user.bio,
                                    textAlign: TextAlign.center,
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      fontFamily: "Proxima Nova",
                                      color: Theme.of(context).colorScheme.secondary.withValues(alpha: 0.6),
                                      fontSize: 14,
                                      fontWeight: FontWeight.normal,
                                    ),
                                  ),
                                ),
                                const SizedBox(
                                  height: 15,
                                ),
                                SizedBox(
                                  width: MediaQuery.of(context).size.width * 0.7,
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      RichText(
                                        text: TextSpan(
                                          text: "${user.following.length}",
                                          style: TextStyle(
                                            fontFamily: "Proxima Nova",
                                            color: Theme.of(context).colorScheme.secondary.withValues(alpha: 1),
                                            fontSize: 16,
                                            fontWeight: FontWeight.bold,
                                          ),
                                          children: [
                                            TextSpan(
                                              text: " Following",
                                              style: TextStyle(
                                                color: Theme.of(context).colorScheme.secondary.withValues(alpha: 0.6),
                                                fontWeight: FontWeight.normal,
                                              ),
                                            ),
                                          ],
                                        ),
                                        textAlign: TextAlign.center,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      const SizedBox(width: 24),
                                      RichText(
                                        text: TextSpan(
                                          text: "${user.followers.length}",
                                          style: TextStyle(
                                            fontFamily: "Proxima Nova",
                                            color: Theme.of(context).colorScheme.secondary.withValues(alpha: 1),
                                            fontSize: 16,
                                            fontWeight: FontWeight.bold,
                                          ),
                                          children: [
                                            TextSpan(
                                              text: " Followers",
                                              style: TextStyle(
                                                color: Theme.of(context).colorScheme.secondary.withValues(alpha: 0.6),
                                                fontWeight: FontWeight.normal,
                                              ),
                                            ),
                                          ],
                                        ),
                                        textAlign: TextAlign.center,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ],
                                  ),
                                ),
                                if (user.links.keys.toList().isNotEmpty)
                                  const SizedBox(
                                    height: 8,
                                  ),
                                if (user.links.keys.toList().isNotEmpty)
                                  SizedBox(
                                    width: MediaQuery.of(context).size.width,
                                    height: 48,
                                    child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                                      ...user.links.keys
                                          .toList()
                                          .map((e) => IconButton(
                                              padding: const EdgeInsets.all(2),
                                              icon: Container(
                                                padding: const EdgeInsets.all(6.0),
                                                decoration: BoxDecoration(
                                                  shape: BoxShape.circle,
                                                  color: Theme.of(context).colorScheme.secondary.withValues(alpha: 0.1),
                                                ),
                                                child: Icon(
                                                  linksData[e]!["icon"] as IconData,
                                                  size: 20,
                                                  color: Theme.of(context).colorScheme.secondary.withValues(alpha: 0.8),
                                                ),
                                              ),
                                              onPressed: () {
                                                final links = user.links;
                                                if (links[e].toString().contains("@gmail.com")) {
                                                  launch("mailto:${user.links[e]}");
                                                }
                                              }))
                                          .toList()
                                          .sublist(
                                            0,
                                            user.links.keys.toList().length > 3 ? 3 : user.links.keys.toList().length,
                                          ),
                                      if (user.links.keys.toList().length > 3)
                                        IconButton(
                                            padding: const EdgeInsets.all(2),
                                            icon: Container(
                                              padding: const EdgeInsets.all(6.0),
                                              decoration: BoxDecoration(
                                                shape: BoxShape.circle,
                                                color: Theme.of(context).colorScheme.secondary.withValues(alpha: 0.1),
                                              ),
                                              child: Icon(
                                                JamIcons.more_horizontal,
                                                size: 20,
                                                color: Theme.of(context).colorScheme.secondary.withValues(alpha: 0.8),
                                              ),
                                            ),
                                            onPressed: () {
                                              showNoLoadLinksPopUp(context, user.links);
                                            }),
                                    ]),
                                  )
                              ],
                            ),
                          )
                        ],
                      ),
                      Positioned(
                        top: MediaQuery.of(context).size.height * 0.19 - 56,
                        child: SizedBox(
                          width: MediaQuery.of(context).size.width - 32,
                          child: Center(
                            child: Container(
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: Theme.of(context).colorScheme.error,
                                  width: 4,
                                ),
                                color: Theme.of(context).colorScheme.secondary,
                              ),
                              child: ClipOval(
                                child: CachedNetworkImage(
                                  imageUrl: user.profilePhoto,
                                  width: 78,
                                  height: 78,
                                  fit: BoxFit.cover,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                      Positioned(
                        child: IconButton(
                          onPressed: () {
                            context.router.push(ProfileRoute(arguments: [
                              user.email,
                            ]));
                          },
                          icon: const Icon(
                            JamIcons.user_circle,
                          ),
                        ),
                      )
                    ],
                  ),
                ),
              ),
            ),
            isExpanded: _data[widget.users.indexOf(user)],
          );
        }).toList(),
      ),
    );
  }
}
