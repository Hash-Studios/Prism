import 'package:Prism/data/profile/wallpaper/getUserProfile.dart';
import 'package:Prism/logger/logger.dart';
import 'package:Prism/ui/widgets/home/wallpapers/loading.dart';
import 'package:Prism/ui/widgets/profile/userProfileGrid.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

class UserProfileLoader extends StatefulWidget {
  final String? email;
  const UserProfileLoader({required this.email});
  @override
  _UserProfileLoaderState createState() => _UserProfileLoaderState();
}

class _UserProfileLoaderState extends State<UserProfileLoader> {
  Future? _future;

  @override
  void initState() {
    _future = Provider.of<UserProfileProvider>(context, listen: false)
        .getuserProfileWalls(widget.email);
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 4.0),
      child: FutureBuilder(
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
            return UserProfileGrid(
              email: widget.email,
            );
          }
        },
      ),
    );
  }
}
