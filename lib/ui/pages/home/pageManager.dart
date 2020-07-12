import 'package:Prism/data/categories/provider/categoriesProvider.dart';
import 'package:Prism/ui/pages/categories/abstractScreen.dart';
import 'package:Prism/ui/pages/categories/curatedScreen.dart';
import 'package:Prism/ui/pages/categories/natureScreen.dart';
import 'package:Prism/ui/pages/home/homeScreen.dart';
import 'package:Prism/ui/widgets/home/bottomNavBar.dart';
import 'package:Prism/ui/widgets/home/categoriesBar.dart';
import 'package:Prism/ui/widgets/popup/updatePopUp.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:Prism/global/globals.dart' as globals;

PageController pageController = PageController();

class PageManager extends StatefulWidget {
  @override
  _PageManagerState createState() => _PageManagerState();
}

class _PageManagerState extends State<PageManager> {
  //Check for update if available
  String currentAppVersion = "2.4.2";
  final databaseReference = Firestore.instance;
  @override
  void initState() {
    Provider.of<CategoryProvider>(context, listen: false)
        .updateSelectedCategory("Home");
    _checkUpdate();
    super.initState();
  }

  Future<void> _checkUpdate() async {
    print("checking for update");
    databaseReference.collection("appConfig").getDocuments().then((value) {
      print("Current App Version :" + currentAppVersion);
      print(
          "Latest Version :" + value.documents[0]["currentVersion"].toString());
      setState(() {
        if (currentAppVersion !=
            value.documents[0]["currentVersion"].toString()) {
          setState(() {
            globals.updateAvailable = true;
            globals.versionInfo = {
              "version_number": value.documents[0]["currentVersion"].toString(),
              "version_desc": value.documents[0]["versionDesc"],
            };
          });
        } else {
          setState(() {
            globals.updateAvailable = false;
          });
        }
      });
      globals.updateAvailable
          ? !globals.noNewNotification
              ? showUpdate(context)
              : print("No new notification")
          : print("No update");
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).primaryColor,
      appBar: PreferredSize(
        child: CategoriesBar(),
        preferredSize: Size(double.infinity, 55),
      ),
      body: BottomBar(
        child: PageView.builder(
            onPageChanged: (index) {
              if (index == 0) {
                Provider.of<CategoryProvider>(context, listen: false)
                    .updateSelectedCategory("Home");
              } else if (index == 1) {
                Provider.of<CategoryProvider>(context, listen: false)
                    .updateSelectedCategory("Curated");
              } else if (index == 2) {
                Provider.of<CategoryProvider>(context, listen: false)
                    .updateSelectedCategory("Abstract");
              } else {
                Provider.of<CategoryProvider>(context, listen: false)
                    .updateSelectedCategory("Nature");
              }
            },
            controller: pageController,
            itemCount: 4,
            itemBuilder: (context, index) {
              if (index == 0) {
                return HomeScreen();
              } else if (index == 1) {
                return CuratedScreen();
              } else if (index == 2) {
                return AbstractScreen();
              } else {
                return NatureScreen();
              }
            }),
      ),
    );
  }
}
