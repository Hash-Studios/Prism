import 'package:Prism/core/widgets/home/wallpapers/loading.dart';
import 'package:Prism/features/public_profile/views/public_profile_bloc_adapter.dart';
import 'package:Prism/features/public_profile/views/widgets/user_profile_grid.dart';
import 'package:Prism/logger/logger.dart';
import 'package:flutter/material.dart';

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
    _future = context.publicProfileAdapter(listen: false).getuserProfileWalls(widget.email);
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 4.0),
      child: FutureBuilder(
        future: _future,
        builder: (ctx, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting || snapshot.connectionState == ConnectionState.none) {
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
