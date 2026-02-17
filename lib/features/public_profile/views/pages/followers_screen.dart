import 'package:Prism/core/router/app_router.dart';
import 'package:Prism/core/widgets/home/core/headingChipBar.dart';
import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

@RoutePage()
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
                          .bodyMedium!
                          .copyWith(color: Theme.of(context).colorScheme.secondary),
                    ),
                    onTap: () {
                      context.router.push(ProfileRoute(arguments: [followers![index].toString()]));
                    },
                  );
                })));
  }
}
