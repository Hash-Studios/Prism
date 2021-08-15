import 'package:Prism/auth/userModel.dart';
import 'package:Prism/data/user/user_service.dart';
import 'package:Prism/data/user/user_notifier.dart';
import 'package:Prism/locator/locator.dart';
import 'package:Prism/logger/logger.dart';
import 'package:Prism/routes/router.dart';
import 'package:Prism/ui/pages/search/searchScreen.dart';
import 'package:Prism/ui/widgets/home/wallpapers/loading.dart';
import 'package:flutter/material.dart';
import 'package:Prism/theme/jam_icons_icons.dart';
import 'package:provider/provider.dart';

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
              return Container(child: Text("${snapshot.data?[index].name}"));
            },
          );
        }
      },
    );
  }
}
