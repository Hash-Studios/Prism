import 'package:flutter/material.dart';

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
    return Scaffold(
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
              accountName: new Text(" Prism ",style: TextStyle(backgroundColor: Colors.white70),),
              accountEmail: new Text(" Always on the colourful side! ",style: TextStyle(backgroundColor: Colors.white70),),
              decoration: new BoxDecoration(
                image: new DecorationImage(
                  image: new NetworkImage('https://picsum.photos/600/600'),
                  fit: BoxFit.cover,
                ),
              ),
              currentAccountPicture: CircleAvatar(child: Icon(Icons.format_paint,size: 48,),
                  backgroundColor: Colors.white,),
            ),
            new ListTile(
                leading: Icon(Icons.format_paint),
                title: new Text("Wallpapers"),
                onTap: () {
                  Navigator.pop(context);
                }),
            new ListTile(
                leading: Icon(Icons.photo),
                title: new Text("Photographs"),
                onTap: () {
                  Navigator.pop(context);
                }),
            new ListTile(
                leading: Icon(Icons.favorite),
                title: new Text("Favourites"),
                onTap: () {
                  Navigator.pop(context);
                }),
            new ListTile(
                leading: Icon(Icons.arrow_downward),
                title: new Text("Downloads"),
                onTap: () {
                  Navigator.pop(context);
                }),
            new ListTile(
                leading: Icon(Icons.settings),
                title: new Text("Settings"),
                onTap: () {
                  Navigator.pop(context);
                }),
            new Divider(),
            new ListTile(
                leading: Icon(Icons.info),
                title: new Text("About"),
                onTap: () {
                  Navigator.pop(context);
                }),
          ],
        ),
      ),
    );
  }
}
