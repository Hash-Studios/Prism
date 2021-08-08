import 'package:flutter/material.dart';
import 'package:Prism/ui/widgets/home/core/headingChipBar.dart';
import 'package:Prism/routes/router.dart';
import 'package:Prism/routes/routing_constants.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:Prism/logger/logger.dart';

class FollowersScreen extends StatefulWidget {
  final List? arguments;
  const FollowersScreen({required this.arguments});

  @override
  _FollowersScreenState createState() => _FollowersScreenState();
}

class _FollowersScreenState extends State<FollowersScreen> {
  List? followers;

  @override
  void initState() {
    followers = widget.arguments![0] as List;
    followers!.sort();
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
        onWillPop: () async {
          if (navStack.length > 1) navStack.removeLast();
          logger.d(navStack.toString());
          return true;
        },
        child: Scaffold(
            backgroundColor: Theme.of(context).primaryColor,
            appBar: const PreferredSize(
              preferredSize: Size(double.infinity, 55),
              child: HeadingChipBar(
                current: "Followers",
              ),
            ),
            body: ListView.builder(
                itemCount: followers!.length,
                itemBuilder: (BuildContext context, int index) {
                  return ListTile(
                    leading: CircleAvatar(
                      child: ClipOval(
                        child: SvgPicture.network(
                            "https://avatars.dicebear.com/api/avataaars/$index.svg?background=transparent"),
                      ),
                    ),
                    title: Text(
                      followers![index].toString(),
                      style: Theme.of(context)
                          .textTheme
                          .bodyText2!
                          .copyWith(color: Theme.of(context).accentColor),
                    ),
                    onTap: () {
                      Navigator.pushNamed(context, followerProfileRoute,
                          arguments: [followers![index].toString()]);
                    },
                  );
                })));
  }
}
