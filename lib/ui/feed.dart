import 'package:Prism/data/notifications.dart';
import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:Prism/screens/tabs/downloads.dart';
import 'package:Prism/screens/tabs/likedimages.dart';
import 'package:Prism/screens/search.dart';
import 'package:Prism/screens/settings.dart';
import 'package:Prism/screens/tabs/wallpapers.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:Prism/data/themes.dart';
import 'package:dynamic_theme/dynamic_theme.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:Prism/main.dart';
import 'package:flutter/services.dart';

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
        MaterialPageRoute(builder: (context) => NotificationHandler()),
        (Route<dynamic> route) => false);
  }

  Future<bool> _onBackPressed() {
    SystemChannels.platform.invokeMethod('SystemNavigator.pop');
  }

  Future<bool> _onBackPressedDrawer() {
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    if (DynamicTheme.of(context).data.brightness == Brightness.light) {
      SystemChrome.setSystemUIOverlayStyle(SystemUiOverlayStyle.dark);
    } else {
      SystemChrome.setSystemUIOverlayStyle(SystemUiOverlayStyle.light);
    }
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
      drawer: WillPopScope(
        onWillPop: _onBackPressedDrawer,
        child: Drawer(
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
                    gradient: LinearGradient(colors: [
                  DynamicTheme.of(context).data.backgroundColor,
                  DynamicTheme.of(context).data.primaryColor
                ], begin: Alignment.bottomCenter, end: Alignment.topCenter)),
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
                    child: ClipOval(
                        child: Image.asset("assets/images/icon1.png"))),
              ),
              new ListTile(
                  leading: Icon(
                    Icons.format_paint,
                    color: _tabController.index == 0
                        ? DynamicTheme.of(context).data.hoverColor
                        : DynamicTheme.of(context).data.secondaryHeaderColor,
                  ),
                  title: new Text(
                    "Wallpapers",
                    style: TextStyle(
                      color: _tabController.index == 0
                          ? DynamicTheme.of(context).data.hoverColor
                          : DynamicTheme.of(context)
                              .data
                              .primaryTextTheme
                              .title
                              .color,
                    ),
                  ),
                  onTap: () {
                    Navigator.pop(context);
                    setState(() {
                      _tabController.animateTo(0);
                    });
                  }),
              new ListTile(
                  leading: Icon(
                    Icons.favorite,
                    color: _tabController.index == 1
                        ? DynamicTheme.of(context).data.hoverColor
                        : DynamicTheme.of(context).data.secondaryHeaderColor,
                  ),
                  title: new Text(
                    "Favourites",
                    style: TextStyle(
                      color: _tabController.index == 1
                          ? DynamicTheme.of(context).data.hoverColor
                          : DynamicTheme.of(context)
                              .data
                              .primaryTextTheme
                              .title
                              .color,
                    ),
                  ),
                  onTap: () {
                    Navigator.pop(context);
                    setState(() {
                      _tabController.animateTo(1);
                    });
                  }),
              new ListTile(
                  leading: Icon(
                    Icons.arrow_downward,
                    color: _tabController.index == 2
                        ? DynamicTheme.of(context).data.hoverColor
                        : DynamicTheme.of(context).data.secondaryHeaderColor,
                  ),
                  title: new Text(
                    "Downloads",
                    style: TextStyle(
                      color: _tabController.index == 2
                          ? DynamicTheme.of(context).data.hoverColor
                          : DynamicTheme.of(context)
                              .data
                              .primaryTextTheme
                              .title
                              .color,
                    ),
                  ),
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
              new Divider(),
              new ListTile(
                  leading: Icon(
                    Icons.info,
                    color: DynamicTheme.of(context).data.secondaryHeaderColor,
                  ),
                  title: new Text("About"),
                  onTap: () {
                    Navigator.pop(context);
                    showDialog(
                      context: context,
                      builder: (BuildContext context) {
                        // return object of type Dialog
                        return AlertDialog(
                          title: new Text("About"),
                          content: new Text(
                              "Prism is a collection of random but beautiful 16:9 high quality wallpapers, with robust back-end and beautiful UI. This app has been developed with WallHaven API."),
                          actions: <Widget>[
                            // usually buttons at the bottom of the dialog
                            new FlatButton(
                              child: new Text("Close"),
                              onPressed: () {
                                Navigator.of(context).pop();
                              },
                            ),
                          ],
                        );
                      },
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
            ],
          ),
        ),
      ),
      body: WillPopScope(
        onWillPop: _onBackPressed,
        child: TabBarView(
          controller: _tabController,
          children: [
            Wallpapers(''),
            LikedImages(ScreenUtil.screenWidth.round(),
                ScreenUtil.screenHeight.round()),
            Downloads(ScreenUtil.screenWidth.round(),
                ScreenUtil.screenHeight.round()),
          ],
        ),
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
