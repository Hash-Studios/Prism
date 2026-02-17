import 'package:Prism/features/public_profile/views/public_profile_bloc_adapter.dart';
import 'package:Prism/features/public_profile/views/widgets/user_profile_setup_grid.dart';
import 'package:Prism/features/setups/views/widgets/loading_setup_cards.dart';
import 'package:Prism/logger/logger.dart';
import 'package:flutter/material.dart';

class UserProfileSetupLoader extends StatefulWidget {
  final String? email;
  const UserProfileSetupLoader({required this.email});
  @override
  _UserProfileSetupLoaderState createState() => _UserProfileSetupLoaderState();
}

class _UserProfileSetupLoaderState extends State<UserProfileSetupLoader>
    with AutomaticKeepAliveClientMixin<UserProfileSetupLoader> {
  Future? _future;

  @override
  void initState() {
    _future = context.publicProfileAdapter(listen: false).getUserProfileSetups(widget.email);
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return Padding(
      padding: const EdgeInsets.only(top: 4.0),
      child: FutureBuilder(
        future: _future,
        builder: (ctx, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting || snapshot.connectionState == ConnectionState.none) {
            logger.d("snapshot none, waiting");
            return const LoadingSetupCards();
          } else {
            return UserProfileSetupGrid(
              email: widget.email,
            );
          }
        },
      ),
    );
  }

  @override
  bool get wantKeepAlive => true;
}
