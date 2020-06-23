import 'package:Prism/theme/jam_icons_icons.dart';
import 'package:Prism/theme/themeModel.dart';
import 'package:Prism/ui/widgets/bottomNavBar.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

class SearchScreen extends StatefulWidget {
  @override
  _SearchScreenState createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final List<String> tags = [
    'Home',
    'Abstract',
    'Community',
    'Nature',
    'Cars',
    'Comics',
  ];
  bool isTyping;
  bool isSubmitted;
  TextEditingController searchController = TextEditingController();
  @override
  void initState() {
    isSubmitted = false;
    isTyping = false;
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        backgroundColor: Theme.of(context).primaryColor,
        appBar: AppBar(
          excludeHeaderSemantics: false,
          automaticallyImplyLeading: false,
          elevation: 0,
          titleSpacing: 0,
          title: SizedBox(
            width: MediaQuery.of(context).size.width,
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Container(
                decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(500),
                    color: Theme.of(context).hintColor),
                child: TextField(
                  style: Theme.of(context)
                      .textTheme
                      .headline5
                      .copyWith(color: Theme.of(context).accentColor),
                  controller: searchController,
                  decoration: InputDecoration(
                    contentPadding: EdgeInsets.only(left: 30, top: 15),
                    border: InputBorder.none,
                    disabledBorder: InputBorder.none,
                    enabledBorder: InputBorder.none,
                    focusedBorder: InputBorder.none,
                    hintText: "Search",
                    suffixIcon: Icon(JamIcons.search),
                  ),
                ),
              ),
            ),
          ),
          bottom: PreferredSize(
              child: SizedBox(
                width: MediaQuery.of(context).size.width,
                height: 60,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  itemCount: tags.length,
                  itemBuilder: (context, index) {
                    return Align(
                      alignment: Alignment.center,
                      child: Stack(
                        children: <Widget>[
                          Padding(
                            padding: const EdgeInsets.all(5),
                            child: ActionChip(
                                pressElevation: 5,
                                padding: EdgeInsets.fromLTRB(14, 11, 14, 11),
                                backgroundColor: Theme.of(context).hintColor,
                                label: Text(tags[index],
                                    style:
                                        Theme.of(context).textTheme.headline4),
                                onPressed: () {}),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
              preferredSize: Size(double.infinity, 55)),
        ),
        body: BottomBar(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              SizedBox(
                width: MediaQuery.of(context).size.width,
                child: ThemeModel().returnTheme() == ThemeType.Dark
                    ? SvgPicture.asset(
                        "assets/images/loader dark.svg",
                      )
                    : SvgPicture.asset(
                        "assets/images/loader light.svg",
                      ),
              ),
              SizedBox(
                width: MediaQuery.of(context).size.width,
                height: MediaQuery.of(context).size.height * 0.1,
              )
            ],
          ),
        ));
  }
}
