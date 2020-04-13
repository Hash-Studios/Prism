import 'package:flutter/material.dart';
import 'package:cache_image/cache_image.dart';
import 'package:wallpapers_app/wallpapers.dart';

final GlobalKey<ScaffoldState> _scaffoldKey = new GlobalKey();

class Feed extends StatefulWidget {
  @override
  _FeedState createState() => _FeedState();
}

class _FeedState extends State<Feed> {
  @override
  void initState() {
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      initialIndex: 0,
      length: 4,
      child: Scaffold(
        key: _scaffoldKey,
        appBar: AppBar(
          title: Text('Prism'),
          actions: <Widget>[
            IconButton(
              icon: Icon(Icons.search),
              onPressed: null,
            )
          ],
          centerTitle: true,
          elevation: 0,
          backgroundColor: Colors.white,
          brightness: Brightness.light,
          leading: IconButton(
            icon: Icon(Icons.menu),
            onPressed: () {
              _scaffoldKey.currentState.openDrawer();
            },
          ),
        ),
        backgroundColor: Colors.white,
        drawer: Drawer(
          child: new ListView(
            children: <Widget>[
              new UserAccountsDrawerHeader(
                accountName: new Text(
                  " Prism ",
                  style: TextStyle(backgroundColor: Colors.white70),
                ),
                accountEmail: new Text(
                  " Always on the colourful side! ",
                  style: TextStyle(backgroundColor: Colors.white70),
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
            Wallpapers(),
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
          labelColor: Colors.deepPurple,
          unselectedLabelColor: Colors.grey,
          indicatorSize: TabBarIndicatorSize.label,
          indicatorPadding: EdgeInsets.all(5.0),
          indicatorColor: Colors.grey,
        ),
      ),
    );
  }
}
