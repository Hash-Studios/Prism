import 'package:Prism/theme/jam_icons_icons.dart';
import 'package:Prism/ui/widgets/setWallpaperButton.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class ShareWallpaperViewScreen extends StatefulWidget {
  final List arguments;
  ShareWallpaperViewScreen({this.arguments});

  @override
  _ShareWallpaperViewScreenState createState() =>
      _ShareWallpaperViewScreenState();
}

class _ShareWallpaperViewScreenState extends State<ShareWallpaperViewScreen> {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  String id;
  String provider;
  String url;
  bool isLoading = true;
  @override
  void initState() {
    id = widget.arguments[0];
    provider = widget.arguments[1];
    url = widget.arguments[2];
    isLoading = true;
    super.initState();
  }

  @override
  void dispose() {
    super.dispose();
    SystemChrome.setEnabledSystemUIOverlays(
        [SystemUiOverlay.top, SystemUiOverlay.bottom]);
  }

  @override
  Widget build(BuildContext context) {
    SystemChrome.setEnabledSystemUIOverlays([]);
    try {
      return Scaffold(
        key: _scaffoldKey,
        backgroundColor: Theme.of(context).primaryColor,
        body: Stack(
          children: <Widget>[
            Container(
              height: MediaQuery.of(context).size.height,
              width: MediaQuery.of(context).size.width,
              child: Image.network(
                url,
                fit: BoxFit.cover,
              ),
            ),
            Align(
              alignment: Alignment.bottomCenter,
              child: Padding(
                padding: const EdgeInsets.all(20.0),
                child: SetWallpaperButton(),
              ),
            ),
            Align(
              alignment: Alignment.topLeft,
              child: Padding(
                padding: const EdgeInsets.all(8.0),
                child: IconButton(
                  onPressed: () {
                    Navigator.pop(context);
                  },
                  color: Theme.of(context).accentColor,
                  icon: Icon(
                    JamIcons.chevron_left,
                  ),
                ),
              ),
            )
          ],
        ),
      );
    } catch (e) {
      print(e.toString());
      Navigator.pop(context);
      return Container();
    }
  }
}
