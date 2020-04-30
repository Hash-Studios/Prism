import 'package:flutter/material.dart';
import 'package:cache_image/cache_image.dart';
import 'package:wallpapers_app/likedimages.dart';
import 'package:wallpapers_app/wallpapers.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import './themes.dart';
import 'package:dynamic_theme/dynamic_theme.dart';
import 'package:shared_preferences/shared_preferences.dart';
// import 'package:font_awesome_flutter/font_awesome_flutter.dart';

final GlobalKey<ScaffoldState> _scaffoldKey = new GlobalKey();

class Feed extends StatefulWidget {
  // Color iconColor;
  // Color bgColor;
  // Feed(this.iconColor, this.bgColor);
  @override
  _FeedState createState() => _FeedState();
}

class _FeedState extends State<Feed> {
  List<ThemeItem> _themeItems = ThemeItem.getThemeItems();

  List<DropdownMenuItem<ThemeItem>> _dropDownMenuItems;

  ThemeItem _selectedItem;

  List<DropdownMenuItem<ThemeItem>> buildDropdownMenuItems() {
    List<DropdownMenuItem<ThemeItem>> items = List();
    for (ThemeItem themeItem in _themeItems) {
      items
          .add(DropdownMenuItem(value: themeItem, child: Text(themeItem.name)));
    }
    return items;
  }

  @override
  void initState() {
    _dropDownMenuItems = buildDropdownMenuItems();
    _selectedItem = _dropDownMenuItems[0].value;
    super.initState();
  }

  void changeColor() {
    DynamicTheme.of(context).setThemeData(this._selectedItem.themeData);
  }

  setSharedPrefs() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    prefs.setString('dynTheme', _selectedItem.slug);
  }

  onChangeDropdownItem(ThemeItem selectedItem) {
    setState(() {
      this._selectedItem = selectedItem;
    });
    changeColor();
    setSharedPrefs();
  }

  // void changeToTheme1() {
  // setState(() {
  //   DynamicTheme.of(context).data.secondaryHeaderColor = Color(0xFF000000);
  //   DynamicTheme.of(context).data.primaryColor = Color(0xFFFFFFFF);
  // });
  // if (DynamicTheme.of(context).data.secondaryHeaderColor != Color(0xFF000000)) {
  //   Navigator.of(context)
  //       .push(new MaterialPageRoute(builder: (BuildContext context) {
  //     return new Feed(Color(0xFF000000), Color(0xFFFFFFFF));
  //   }));
  // }
  // }

  // void changeToTheme2() {
  // setState(() {
  //   DynamicTheme.of(context).data.secondaryHeaderColor = Color(0xFFFFFFFF);
  //   DynamicTheme.of(context).data.primaryColor = Color(0xFF000000);
  // });
  // if (DynamicTheme.of(context).data.secondaryHeaderColor != Color(0xFFFFFFFF)) {
  //   Navigator.of(context)
  //       .push(new MaterialPageRoute(builder: (BuildContext context) {
  //     return new Feed(Color(0xFF000000), Color(0xFFFFFFFF));
  //   }));
  // }
  // }

  @override
  Widget build(BuildContext context) {
    ScreenUtil.init(context, width: 720, height: 1440, allowFontScaling: true);
    return DefaultTabController(
      initialIndex: 0,
      length: 3,
      child: Scaffold(
        // floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
        // floatingActionButton: FloatingActionButton(onPressed: null),
        key: _scaffoldKey,
        appBar: AppBar(
          title: Text(
            'Prism',
            style: GoogleFonts.pacifico(
                fontWeight: FontWeight.w600,
                fontSize: 30,
                color: DynamicTheme.of(context).data.secondaryHeaderColor),
          ),
          actions: <Widget>[
            IconButton(
              icon: Icon(
                Icons.search,
                color: DynamicTheme.of(context).data.secondaryHeaderColor,
              ),
              onPressed: null,
            )
          ],
          centerTitle: true,
          elevation: 0,
          backgroundColor: DynamicTheme.of(context).data.primaryColor,
          brightness: Brightness.light,
          leading: IconButton(
            icon: Icon(
              Icons.menu,
              color: DynamicTheme.of(context).data.secondaryHeaderColor,
            ),
            onPressed: () {
              _scaffoldKey.currentState.openDrawer();
            },
          ),
        ),
        backgroundColor: DynamicTheme.of(context).data.primaryColor,
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
                          backgroundColor: Colors.white54,
                          color: Colors.black),
                    ),
                  ),
                ),
                accountEmail: Padding(
                  padding: const EdgeInsets.only(left: 10),
                  child: ClipRRect(
                    borderRadius: BorderRadius.all(Radius.circular(5)),
                    child: new Text(
                      " Always on the colourful side! ",
                      style: TextStyle(
                          backgroundColor: Colors.white54, color: Colors.black),
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
                    color: Colors.green,
                  ),
                  title: new Text("Downloads"),
                  onTap: () {
                    Navigator.pop(context);
                  }),
              ListTile(
                leading: Icon(
                  Icons.brightness_4,
                  color: Colors.amber,
                ),
                title: Text(
                  ' ',
                  style: TextStyle(),
                ),
                trailing: Tooltip(
                  message: "Themes",
                  waitDuration: Duration(seconds: 1),
                  child: Container(
                    width: 390.w,
                    child: DropdownButton(
                      isExpanded: true,
                      hint: Text(
                        'Themes',
                        style: TextStyle(
                            color: DynamicTheme.of(context)
                                .data
                                .textTheme
                                .subtitle
                                .color,
                            fontSize: 14),
                      ),
                      icon: Icon(Icons.more_vert,
                          color: DynamicTheme.of(context).data.iconTheme.color),
                      items: _dropDownMenuItems,
                      onChanged: onChangeDropdownItem,
                      underline: SizedBox(),
                    ),
                  ),
                ),
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
            Wallpapers(
              ScreenUtil.screenWidth.round(),
              ScreenUtil.screenHeight.round(),
            ),
            LikedImages(
              ScreenUtil.screenWidth.round(),
              ScreenUtil.screenHeight.round(),
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
              icon: new Icon(Icons.favorite),
            ),
            Tab(
              icon: new Icon(Icons.arrow_downward),
            )
          ],
          labelColor: DynamicTheme.of(context).data.secondaryHeaderColor,
          unselectedLabelColor: Colors.grey,
          indicatorSize: TabBarIndicatorSize.label,
          indicatorPadding: EdgeInsets.all(5.0),
          indicatorColor: DynamicTheme.of(context).data.secondaryHeaderColor,
        ),
      ),
    );
  }
}
