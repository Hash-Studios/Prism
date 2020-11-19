import 'package:Prism/ui/widgets/profile/userProfileSetupGrid.dart';
import 'package:Prism/ui/widgets/setups/loadingSetups.dart';
import 'package:flutter/material.dart';

class UserProfileSetupLoader extends StatefulWidget {
  final Future future;
  final String email;
  const UserProfileSetupLoader({@required this.future, @required this.email});
  @override
  _UserProfileSetupLoaderState createState() => _UserProfileSetupLoaderState();
}

class _UserProfileSetupLoaderState extends State<UserProfileSetupLoader> {
  Future _future;

  @override
  void initState() {
    _future = widget.future;
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
            debugPrint("snapshot null");
            return const LoadingSetupCards();
          }
          if (snapshot.connectionState == ConnectionState.waiting ||
              snapshot.connectionState == ConnectionState.none) {
            debugPrint("snapshot none, waiting");
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
