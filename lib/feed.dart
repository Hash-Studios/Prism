import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:wallpapers_app/downloads.dart';
import 'package:wallpapers_app/likedimages.dart';
import 'package:wallpapers_app/search.dart';
import 'package:wallpapers_app/settings.dart';
import 'package:wallpapers_app/wallpapers.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import './themes.dart';
import 'package:dynamic_theme/dynamic_theme.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import './main.dart';

final GlobalKey<ScaffoldState> scaffoldKey = new GlobalKey();
TabController _tabController;

class Feed extends StatefulWidget {
  String currentUserId;
  Feed({this.currentUserId});
  @override
  _FeedState createState() => _FeedState();
}

class _FeedState extends State<Feed> with SingleTickerProviderStateMixin {
  bool isLoading = false;
  final GoogleSignIn googleSignIn = GoogleSignIn();

  SharedPreferences prefs;
  String id = '';
  String name = '';
  String email = '';

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
    _tabController = new TabController(vsync: this, length: 3);
    readLocal();
  }

  @override
  void dispose() {
    super.dispose();
    _tabController.dispose();
  }

  void changeColor() {
    DynamicTheme.of(context).setThemeData(this._selectedItem.themeData);
  }

  setSharedPrefs() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    prefs.setString('dynTheme', _selectedItem.slug);
  }

  void readLocal() async {
    prefs = await SharedPreferences.getInstance();
    id = prefs.getString('id');
    name = prefs.getString('name');
    email = prefs.getString('email');
    // Force refresh input
    setState(() {});
  }

  onChangeDropdownItem(ThemeItem selectedItem) {
    setState(() {
      this._selectedItem = selectedItem;
    });
    changeColor();
    setSharedPrefs();
  }

  Future<Null> handleSignOut() async {
    this.setState(() {
      isLoading = true;
    });

    await FirebaseAuth.instance.signOut();
    await googleSignIn.disconnect();
    await googleSignIn.signOut();

    this.setState(() {
      isLoading = false;
    });

    Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (context) => MyApp()),
        (Route<dynamic> route) => false);
  }

  @override
  Widget build(BuildContext context) {
    ScreenUtil.init(context, width: 720, height: 1440, allowFontScaling: true);
    return Scaffold(
      key: scaffoldKey,
      appBar: AppBar(
        title: Text(
          'Prism',
          style: GoogleFonts.pacifico(
              fontWeight: FontWeight.w600,
              fontSize: 30,
              color: DynamicTheme.of(context).data.secondaryHeaderColor),
        ),
        actions: <Widget>[
          Hero(
            tag: 'search',
            child: Card(
              elevation: 0,
              color: Colors.transparent,
              child: IconButton(
                icon: Icon(
                  Icons.search,
                  color: DynamicTheme.of(context).data.secondaryHeaderColor,
                ),
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) {
                        return Search();
                      },
                    ),
                  );
                },
              ),
            ),
          ),
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
            scaffoldKey.currentState.openDrawer();
          },
        ),
      ),
      drawer: Drawer(
        child: new ListView(
          children: <Widget>[
            new UserAccountsDrawerHeader(
              accountName: Padding(
                padding: const EdgeInsets.only(left: 10),
                child: ClipRRect(
                  borderRadius: BorderRadius.all(Radius.circular(5)),
                  child: new Text(
                    " " + name + " ",
                    style: TextStyle(
                        fontWeight: FontWeight.w500,
                        fontSize: 18,
                        backgroundColor: Colors.white54,
                        color: Colors.black),
                  ),
                ),
              ),
              decoration: BoxDecoration(
                image: DecorationImage(
                    image: AssetImage("assets/images/login.png"),
                    fit: BoxFit.cover),
              ),
              accountEmail: Padding(
                padding: const EdgeInsets.only(left: 10),
                child: ClipRRect(
                  borderRadius: BorderRadius.all(Radius.circular(5)),
                  child: new Text(
                    " " + email + " ",
                    style: TextStyle(
                        backgroundColor: Colors.white54, color: Colors.black),
                  ),
                ),
              ),
              currentAccountPicture: Center(
                child: Icon(
                  Icons.format_paint,
                  size: 48,
                  color: DynamicTheme.of(context).data.secondaryHeaderColor,
                ),
              ),
            ),
            new ListTile(
                selected: _tabController.index == 0 ? true : false,
                leading: Icon(
                  Icons.format_paint,
                  color: DynamicTheme.of(context).data.secondaryHeaderColor,
                ),
                title: new Text("Wallpapers"),
                onTap: () {
                  Navigator.pop(context);
                  setState(() {
                    _tabController.animateTo(0);
                  });
                }),
            new ListTile(
                selected: _tabController.index == 1 ? true : false,
                leading: Icon(
                  Icons.favorite,
                  color: DynamicTheme.of(context).data.secondaryHeaderColor,
                ),
                title: new Text("Favourites"),
                onTap: () {
                  Navigator.pop(context);
                  setState(() {
                    _tabController.animateTo(1);
                  });
                }),
            new ListTile(
                selected: _tabController.index == 2 ? true : false,
                leading: Icon(
                  Icons.arrow_downward,
                  color: DynamicTheme.of(context).data.secondaryHeaderColor,
                ),
                title: new Text("Downloads"),
                onTap: () {
                  Navigator.pop(context);
                  setState(() {
                    _tabController.animateTo(2);
                  });
                }),
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Tooltip(
                message: "Themes",
                waitDuration: Duration(seconds: 1),
                child: Container(
                  width: 390.w,
                  child: DropdownButton(
                    isDense: true,
                    isExpanded: true,
                    hint: Row(
                      children: [
                        Icon(
                          Icons.brightness_4,
                          color: DynamicTheme.of(context)
                              .data
                              .secondaryHeaderColor,
                        ),
                        Padding(
                          padding: const EdgeInsets.only(left: 4.0),
                          child: Text(
                            '          Themes',
                            style: TextStyle(
                                color: DynamicTheme.of(context)
                                    .data
                                    .textTheme
                                    .subtitle
                                    .color,
                                fontSize: 14),
                          ),
                        ),
                      ],
                    ),
                    elevation: 6,
                    icon: Icon(FontAwesomeIcons.angleDown,
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
                  color: DynamicTheme.of(context).data.secondaryHeaderColor,
                ),
                title: new Text("Settings"),
                onTap: () {
                  Navigator.pop(context);
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) {
                        return Settings();
                      },
                    ),
                  );
                }),
            ListTile(
                leading: Icon(
                  Icons.exit_to_app,
                  color: DynamicTheme.of(context).data.secondaryHeaderColor,
                ),
                title: new Text("Sign out"),
                onTap: () {
                  handleSignOut();
                }),
            new Divider(),
            new ListTile(
                leading: Icon(
                  Icons.info,
                  color: DynamicTheme.of(context).data.secondaryHeaderColor,
                ),
                title: new Text("About"),
                onTap: () {
                  Navigator.pop(context);
                }),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          Wallpapers(''),
          LikedImages(
              ScreenUtil.screenWidth.round(), ScreenUtil.screenHeight.round()),
          Downloads(
              ScreenUtil.screenWidth.round(), ScreenUtil.screenHeight.round()),
        ],
      ),
      bottomNavigationBar: new TabBar(
        controller: _tabController,
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
    );
  }
}
