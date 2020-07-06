import 'package:Prism/data/categories/provider/categoriesProvider.dart';
import 'package:Prism/ui/pages/categories/abstractScreen.dart';
import 'package:Prism/ui/pages/categories/curatedScreen.dart';
import 'package:Prism/ui/pages/categories/natureScreen.dart';
import 'package:Prism/ui/pages/home/homeScreen.dart';
import 'package:Prism/ui/widgets/home/bottomNavBar.dart';
import 'package:Prism/ui/widgets/home/categoriesBar.dart';
import 'package:Prism/ui/widgets/popup/updatePopup.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:package_info/package_info.dart';
import 'package:provider/provider.dart';

PageController pageController = PageController();

class PageManager extends StatefulWidget {
  @override
  _PageManagerState createState() => _PageManagerState();
}

class _PageManagerState extends State<PageManager> {
  //Check for update if available
  bool _updateAvailable = true;
  PackageInfo _packageInfo = PackageInfo(
    appName: 'Unknown',
    packageName: 'Unknown',
    version: 'Unknown',
    buildNumber: 'Unknown',
  );

  @override
  void initState() {
    super.initState();
    _initPackageInfo();
    _checkUpdate();
  }

  Future<void> _checkUpdate() {
      Firestore.instance.collection("appConfig").document("version").get().then((value) => (){
     setState(() {
       print("Current version "+ _packageInfo.version+ "  Latest Version "+ value.toString());
      if( _packageInfo.version!= value){
        setState(() {
          _updateAvailable = true;
        });
      }

     });
   });
  }

  //Check for update update info
  Future<void> _initPackageInfo() async {
    final PackageInfo info = await PackageInfo.fromPlatform();
    setState(() {
      _packageInfo = info;
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
        body: Stack(
          children: [
            BottomBar(
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
            Visibility(visible: _updateAvailable, child: UpdatePopup())
          ],
        ));
  }
}
