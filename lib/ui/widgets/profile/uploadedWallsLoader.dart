import 'package:Prism/logger/logger.dart';
import 'package:Prism/ui/widgets/animated/loader.dart';
import 'package:Prism/ui/widgets/profile/uploadedWallsGrid.dart';
import 'package:flutter/material.dart';

class ProfileLoader extends StatefulWidget {
  final Future future;
  const ProfileLoader({required this.future});
  @override
  _ProfileLoaderState createState() => _ProfileLoaderState();
}

class _ProfileLoaderState extends State<ProfileLoader> {
  Future? _future;

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
            logger.d("snapshot null");
            return Center(
              child: Loader(),
            );
          }
          if (snapshot.connectionState == ConnectionState.waiting ||
              snapshot.connectionState == ConnectionState.none) {
            logger.d("snapshot none, waiting");
            return Center(
              child: Loader(),
            );
          } else {
            return const ProfileGrid();
          }
        },
      ),
    );
  }
}
