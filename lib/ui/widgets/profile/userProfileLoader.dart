import 'package:Prism/ui/widgets/home/loading.dart';
import 'package:Prism/ui/widgets/profile/userProfileGrid.dart';
import 'package:flutter/material.dart';

class UserProfileLoader extends StatefulWidget {
  final Future future;
  final String email;
  UserProfileLoader({@required this.future, @required this.email});
  @override
  _UserProfileLoaderState createState() => _UserProfileLoaderState();
}

class _UserProfileLoaderState extends State<UserProfileLoader> {
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
            print("snapshot null");
            return LoadingCards();
          }
          if (snapshot.connectionState == ConnectionState.waiting ||
              snapshot.connectionState == ConnectionState.none) {
            print("snapshot none, waiting");
            return LoadingCards();
          } else {
            // print("snapshot done");
            return UserProfileGrid(
              email: widget.email,
            );
          }
        },
      ),
    );
  }
}
