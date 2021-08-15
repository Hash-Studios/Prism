import 'package:Prism/auth/userModel.dart';
import 'package:Prism/data/user/user_service.dart';
import 'package:Prism/data/user/user_notifier.dart';
import 'package:Prism/global/svgAssets.dart';
import 'package:Prism/locator/locator.dart';
import 'package:Prism/logger/logger.dart';
import 'package:Prism/routes/router.dart';
import 'package:Prism/ui/pages/search/searchScreen.dart';
import 'package:Prism/ui/widgets/home/wallpapers/loading.dart';
import 'package:Prism/ui/widgets/popup/noLoadLinkPopUp.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:Prism/theme/jam_icons_icons.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

class UserSearch extends StatefulWidget {
  const UserSearch({Key? key}) : super(key: key);

  @override
  _UserSearchState createState() => _UserSearchState();
}

class _UserSearchState extends State<UserSearch> {
  TextEditingController searchController = TextEditingController();
  late bool isSubmitted;
  Future<bool> onWillPop() async {
    if (navStack.length > 1) navStack.removeLast();
    logger.d(navStack.toString());
    return true;
  }

  @override
  void initState() {
    isSubmitted = false;
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    final _userService = locator<UserService>();
    return WillPopScope(
      onWillPop: onWillPop,
      child: Scaffold(
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
                  decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(500),
                      color: Theme.of(context).hintColor),
                  child: TextField(
                    cursorColor: Theme.of(context).errorColor,
                    style: Theme.of(context)
                        .textTheme
                        .headline5!
                        .copyWith(color: Theme.of(context).accentColor),
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
                          .headline5!
                          .copyWith(color: Theme.of(context).accentColor),
                      suffixIcon: Icon(
                        JamIcons.search,
                        color: Theme.of(context).accentColor,
                      ),
                    ),
                    onSubmitted: (tex) {
                      setState(() {
                        isSubmitted = true;
                        _userService.fetchUsers(tex);
                      });
                    },
                  ),
                ),
              ),
            ),
          ),
        ),
        body: UserSearchLoader(),
      ),
    );
  }
}

class UserSearchLoader extends StatefulWidget {
  @override
  _UserSearchLoaderState createState() => _UserSearchLoaderState();
}

class _UserSearchLoaderState extends State<UserSearchLoader> {
  @override
  void initState() {
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    final _userNotifier = Provider.of<UserNotifier>(context);

    return StreamBuilder<List<PrismUsersV2>>(
      stream: _userNotifier.sessionsStream,
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
          logger.d("${snapshot.data}");
          return ListView.builder(
            itemCount: snapshot.data?.length,
            itemBuilder: (context, index) {
              return Padding(
                padding: const EdgeInsets.all(8.0),
                child: Card(
                  elevation: 4,
                  color: Theme.of(context).primaryColor,
                  child: Stack(
                    children: [
                      Column(children: [
                        if (snapshot.data?[index].coverPhoto == null)
                          SvgPicture.string(
                            defaultHeader
                                .replaceAll(
                                  "#181818",
                                  "#${Theme.of(context).primaryColor.value.toRadixString(16).toString().substring(2)}",
                                )
                                .replaceAll(
                                  "#E77597",
                                  "#${Theme.of(context).errorColor.value.toRadixString(16).toString().substring(2)}",
                                ),
                            fit: BoxFit.cover,
                            width: MediaQuery.of(context).size.width,
                            height: MediaQuery.of(context).size.height * 0.19,
                          )
                        else
                          CachedNetworkImage(
                            imageUrl: snapshot.data?[index].coverPhoto ??
                                "https://firebasestorage.googleapis.com/v0/b/prism-wallpapers.appspot.com/o/Headers%2FheaderDefault.png?alt=media&token=1a10b128-c355-45d8-af96-678c13c05b3c",
                            fit: BoxFit.cover,
                            width: MediaQuery.of(context).size.width,
                            height: MediaQuery.of(context).size.height * 0.19,
                          ),
                        const SizedBox(
                          width: double.maxFinite,
                          height: 37,
                        ),
                        Container(
                          padding: const EdgeInsets.fromLTRB(12, 4, 12, 0),
                          width: double.maxFinite,
                          height: (snapshot.data?[index].links ?? {})
                                  .keys
                                  .toList()
                                  .isEmpty
                              ? MediaQuery.of(context).size.height * 0.21 - 37
                              : MediaQuery.of(context).size.height * 0.27 - 37,
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                            children: [
                              SizedBox(
                                width: MediaQuery.of(context).size.width * 0.7,
                                child: Text(
                                  "${snapshot.data?[index].name}",
                                  textAlign: TextAlign.center,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontFamily: "Proxima Nova",
                                    color: Theme.of(context).accentColor,
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
                                  "@${snapshot.data?[index].username}",
                                  textAlign: TextAlign.center,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontFamily: "Proxima Nova",
                                    color: Theme.of(context)
                                        .accentColor
                                        .withOpacity(0.6),
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
                                  snapshot.data?[index].bio ?? "",
                                  textAlign: TextAlign.center,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontFamily: "Proxima Nova",
                                    color: Theme.of(context)
                                        .accentColor
                                        .withOpacity(0.6),
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
                                        text:
                                            "${(snapshot.data?[index].following ?? []).length}",
                                        style: TextStyle(
                                          fontFamily: "Proxima Nova",
                                          color: Theme.of(context)
                                              .accentColor
                                              .withOpacity(1),
                                          fontSize: 16,
                                          fontWeight: FontWeight.bold,
                                        ),
                                        children: [
                                          TextSpan(
                                            text: " Following",
                                            style: TextStyle(
                                              color: Theme.of(context)
                                                  .accentColor
                                                  .withOpacity(0.6),
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
                                        text:
                                            "${(snapshot.data?[index].followers ?? []).length}",
                                        style: TextStyle(
                                          fontFamily: "Proxima Nova",
                                          color: Theme.of(context)
                                              .accentColor
                                              .withOpacity(1),
                                          fontSize: 16,
                                          fontWeight: FontWeight.bold,
                                        ),
                                        children: [
                                          TextSpan(
                                            text: " Followers",
                                            style: TextStyle(
                                              color: Theme.of(context)
                                                  .accentColor
                                                  .withOpacity(0.6),
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
                              if ((snapshot.data?[index].links ?? {})
                                  .keys
                                  .toList()
                                  .isNotEmpty)
                                const SizedBox(
                                  height: 8,
                                ),
                              if ((snapshot.data?[index].links ?? {})
                                  .keys
                                  .toList()
                                  .isNotEmpty)
                                SizedBox(
                                  width: MediaQuery.of(context).size.width,
                                  height: 48,
                                  child: Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      children: [
                                        ...(snapshot.data?[index].links ?? {})
                                            .keys
                                            .toList()
                                            .map((e) => IconButton(
                                                padding:
                                                    const EdgeInsets.all(2),
                                                icon: Container(
                                                  padding:
                                                      const EdgeInsets.all(6.0),
                                                  decoration: BoxDecoration(
                                                    shape: BoxShape.circle,
                                                    color: Theme.of(context)
                                                        .accentColor
                                                        .withOpacity(0.1),
                                                  ),
                                                  child: Icon(
                                                    linksData[e]!["icon"]
                                                        as IconData,
                                                    size: 20,
                                                    color: Theme.of(context)
                                                        .accentColor
                                                        .withOpacity(0.8),
                                                  ),
                                                ),
                                                onPressed: () {
                                                  if (snapshot
                                                          .data?[index].links !=
                                                      null) {
                                                    final links = snapshot
                                                        .data?[index].links;
                                                    if (links![e]
                                                        .toString()
                                                        .contains(
                                                            "@gmail.com")) {
                                                      launch(
                                                          "mailto:${snapshot.data?[index].links[e].toString()}");
                                                    }
                                                  } else {
                                                    launch(snapshot.data?[index]
                                                            .links[e]
                                                            .toString() ??
                                                        "");
                                                  }
                                                }))
                                            .toList()
                                            .sublist(
                                              0,
                                              (snapshot.data?[index].links ??
                                                              {})
                                                          .keys
                                                          .toList()
                                                          .length >
                                                      3
                                                  ? 3
                                                  : (snapshot.data?[index]
                                                              .links ??
                                                          {})
                                                      .keys
                                                      .toList()
                                                      .length,
                                            ),
                                        if ((snapshot.data?[index].links ?? {})
                                                .keys
                                                .toList()
                                                .length >
                                            3)
                                          IconButton(
                                              padding: const EdgeInsets.all(2),
                                              icon: Container(
                                                padding:
                                                    const EdgeInsets.all(6.0),
                                                decoration: BoxDecoration(
                                                  shape: BoxShape.circle,
                                                  color: Theme.of(context)
                                                      .accentColor
                                                      .withOpacity(0.1),
                                                ),
                                                child: Icon(
                                                  JamIcons.more_horizontal,
                                                  size: 20,
                                                  color: Theme.of(context)
                                                      .accentColor
                                                      .withOpacity(0.8),
                                                ),
                                              ),
                                              onPressed: () {
                                                showNoLoadLinksPopUp(
                                                    context,
                                                    snapshot.data?[index]
                                                            .links ??
                                                        {});
                                              }),
                                      ]),
                                )
                            ],
                          ),
                        )
                      ]),
                      Positioned(
                        top: MediaQuery.of(context).size.height * 0.19 - 56,
                        child: SizedBox(
                          width: MediaQuery.of(context).size.width,
                          child: Center(
                            child: Container(
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: Theme.of(context).errorColor,
                                  width: 4,
                                ),
                                color: Theme.of(context).accentColor,
                              ),
                              child: ClipOval(
                                child: CachedNetworkImage(
                                  imageUrl:
                                      snapshot.data?[index].profilePhoto ??
                                          "".toString(),
                                  width: 78,
                                  height: 78,
                                  fit: BoxFit.cover,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        }
      },
    );
  }
}
