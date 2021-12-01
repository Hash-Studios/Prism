import 'package:Prism/logger/logger.dart';
import 'package:Prism/ui/widgets/animated/loader.dart';
import 'package:Prism/ui/widgets/profile/uploadedSetupsGrid.dart';
import 'package:flutter/material.dart';

class UploadedSetupsLoader extends StatefulWidget {
  final Future future;
  const UploadedSetupsLoader({required this.future});
  @override
  _UploadedSetupsLoaderState createState() => _UploadedSetupsLoaderState();
}

class _UploadedSetupsLoaderState extends State<UploadedSetupsLoader> {
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
            logger.d(snapshot.data.toString());
            return Center(
              child: Loader(),
            );
          } else {
            return const UploadedSetupsGrid();
          }
        },
      ),
    );
  }
}
