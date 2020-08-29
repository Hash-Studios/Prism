import 'package:Prism/ui/widgets/home/loading.dart';
import 'package:Prism/ui/widgets/profile/profileGrid.dart';
import 'package:flutter/material.dart';

class ProfileLoader extends StatefulWidget {
  final Future future;
  ProfileLoader({@required this.future});
  @override
  _ProfileLoaderState createState() => _ProfileLoaderState();
}

class _ProfileLoaderState extends State<ProfileLoader> {
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
            return ProfileGrid();
          }
        },
      ),
    );
  }
}
