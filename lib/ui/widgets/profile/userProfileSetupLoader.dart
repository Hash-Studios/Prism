import 'package:Prism/ui/profile/public_profile_legacy_bridge.dart';
import 'package:Prism/logger/logger.dart';
import 'package:Prism/ui/widgets/profile/userProfileSetupGrid.dart';
import 'package:Prism/ui/widgets/setups/loadingSetups.dart';
import 'package:flutter/material.dart';

class UserProfileSetupLoader extends StatefulWidget {
  final String? email;
  const UserProfileSetupLoader({required this.email});
  @override
  _UserProfileSetupLoaderState createState() => _UserProfileSetupLoaderState();
}

class _UserProfileSetupLoaderState extends State<UserProfileSetupLoader> {
  Future? _future;

  @override
  void initState() {
    _future = context.publicProfileLegacyProvider(listen: false).getUserProfileSetups(widget.email);
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
}
