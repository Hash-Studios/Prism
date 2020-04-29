import 'package:flutter/material.dart';
import 'package:cache_image/cache_image.dart';
import 'package:wallpapers_app/wallpapers.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
// import 'package:font_awesome_flutter/font_awesome_flutter.dart';

final GlobalKey<ScaffoldState> _scaffoldKey = new GlobalKey();

class Feed extends StatefulWidget {
  @override
  _FeedState createState() => _FeedState();
}

class _FeedState extends State<Feed> {
  final Color iconColor = Color(0xFF000000);
  final Color bgColor = Color(0xFFFFFFFF);
  @override
  void initState() {
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    ScreenUtil.init(context, width: 720, height: 1440, allowFontScaling: true);
    return DefaultTabController(
      initialIndex: 0,
      length: 4,
      child: Scaffold(
        // floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
        // floatingActionButton: FloatingActionButton(onPressed: null),
        key: _scaffoldKey,
        appBar: AppBar(
          title: Text(
            'Prism',
            style: GoogleFonts.pacifico(
                fontWeight: FontWeight.w600, fontSize: 30, color: iconColor),
          ),
          actions: <Widget>[
            IconButton(
              icon: Icon(
                Icons.search,
                color: iconColor,
              ),
              onPressed: null,
            )
          ],
          centerTitle: true,
          elevation: 0,
          backgroundColor: bgColor,
          brightness: Brightness.light,
          leading: IconButton(
            icon: Icon(
              Icons.menu,
              color: iconColor,
            ),
            onPressed: () {
              _scaffoldKey.currentState.openDrawer();
            },
          ),
        ),
        backgroundColor: bgColor,
        drawer: Drawer(
          child: new ListView(
            children: <Widget>[
              new UserAccountsDrawerHeader(
                accountName: Padding(
                  padding: const EdgeInsets.only(left: 10),
                  child: ClipRRect(
                    borderRadius: BorderRadius.all(Radius.circular(5)),
                    child: new Text(
                      " Prism ",
                      style: GoogleFonts.pacifico(
                          fontWeight: FontWeight.w500,
                          fontSize: 16,
                          backgroundColor: Colors.white54),
                    ),
                  ),
                ),
                accountEmail: Padding(
                  padding: const EdgeInsets.only(left: 10),
                  child: ClipRRect(
                    borderRadius: BorderRadius.all(Radius.circular(5)),
                    child: new Text(
                      " Always on the colourful side! ",
                      style: TextStyle(backgroundColor: Colors.white54),
                    ),
                  ),
                ),
                decoration: new BoxDecoration(
                  image: new DecorationImage(
                    image: new CacheImage(
                        'https://46.media.tumblr.com/85b3585957f0c810bf7f1f09dd8c7fe7/tumblr_p14hllwA221uzwgsuo1_400.gif'),
                    fit: BoxFit.cover,
                  ),
                ),
                currentAccountPicture: CircleAvatar(
                  child: Icon(
                    Icons.format_paint,
                    size: 48,
                    color: Colors.white70,
                  ),
                  backgroundImage: CacheImage(
                      "https://46.media.tumblr.com/85b3585957f0c810bf7f1f09dd8c7fe7/tumblr_p14hllwA221uzwgsuo1_400.gif"),
                ),
              ),
              new ListTile(
                  leading: Icon(
                    Icons.format_paint,
                    color: Colors.deepPurple,
                  ),
                  title: new Text("Wallpapers"),
                  onTap: () {
                    Navigator.pop(context);
                  }),
              new ListTile(
                  leading: Icon(
                    Icons.photo,
                    color: Colors.green,
                  ),
                  title: new Text("Photographs"),
                  onTap: () {
                    Navigator.pop(context);
                  }),
              new ListTile(
                  leading: Icon(
                    Icons.favorite,
                    color: Colors.pink,
                  ),
                  title: new Text("Favourites"),
                  onTap: () {
                    Navigator.pop(context);
                  }),
              new ListTile(
                  leading: Icon(
                    Icons.arrow_downward,
                    color: Colors.blue,
                  ),
                  title: new Text("Downloads"),
                  onTap: () {
                    Navigator.pop(context);
                  }),
              ExpansionTile(
                leading: Icon(Icons.brightness_4),
                title: Text(
                  'Themes',
                  style: TextStyle(),
                ),
                children: <Widget>[
                  Tooltip(
                    message: "Theme#1",
                    waitDuration: Duration(seconds: 1),
                    child: ListTile(
                      title: Text(
                        'Theme#1',
                        style: TextStyle(),
                      ),
                      onTap: () {},
                    ),
                  ),
                  Divider(
                    height: 2.0,
                  ),
                  Tooltip(
                    message: "Theme#2",
                    waitDuration: Duration(seconds: 1),
                    child: ListTile(
                      title: Text(
                        'Theme#2',
                        style: TextStyle(),
                      ),
                      onTap: () {},
                    ),
                  ),
                  Divider(
                    height: 2.0,
                  ),
                  Tooltip(
                    message: "Theme#3",
                    waitDuration: Duration(seconds: 1),
                    child: ListTile(
                      title: Text(
                        'Theme#3',
                        style: TextStyle(),
                      ),
                      onTap: () {},
                    ),
                  ),
                  Divider(
                    height: 2.0,
                  ),
                  Tooltip(
                    message: "Theme#4",
                    waitDuration: Duration(seconds: 1),
                    child: ListTile(
                      title: Text(
                        'Theme#4',
                        style: TextStyle(),
                      ),
                      onTap: () {},
                    ),
                  ),
                  Divider(
                    height: 2.0,
                  ),
                  Tooltip(
                    message: "Theme#5",
                    waitDuration: Duration(seconds: 1),
                    child: ListTile(
                      title: Text(
                        'Theme#5',
                        style: TextStyle(),
                      ),
                      onTap: () {},
                    ),
                  ),
                ],
              ),
              new ListTile(
                  leading: Icon(
                    Icons.settings,
                    color: Colors.deepOrange,
                  ),
                  title: new Text("Settings"),
                  onTap: () {
                    Navigator.pop(context);
                  }),
              new Divider(),
              new ListTile(
                  leading: Icon(
                    Icons.info,
                    color: Colors.amber[700],
                  ),
                  title: new Text("About"),
                  onTap: () {
                    Navigator.pop(context);
                  }),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            Wallpapers(ScreenUtil.screenWidth.round(),
                ScreenUtil.screenHeight.round()),
            new Container(
              color: Colors.green,
            ),
            new Container(
              color: Colors.pink,
            ),
            new Container(
              color: Colors.blue,
            ),
          ],
        ),
        bottomNavigationBar: new TabBar(
          tabs: [
            Tab(
              icon: new Icon(Icons.format_paint),
            ),
            Tab(
              icon: new Icon(Icons.photo),
            ),
            Tab(
              icon: new Icon(Icons.favorite),
            ),
            Tab(
              icon: new Icon(Icons.arrow_downward),
            )
          ],
          labelColor: iconColor,
          unselectedLabelColor: Colors.grey,
          indicatorSize: TabBarIndicatorSize.label,
          indicatorPadding: EdgeInsets.all(5.0),
          indicatorColor: iconColor,
        ),
      ),
    );
  }
}
