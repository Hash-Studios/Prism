import 'package:Prism/data/categories/provider/categoriesProvider.dart';
import 'package:Prism/ui/pages/abstractScreen.dart';
import 'package:Prism/ui/pages/curatedScreen.dart';
import 'package:Prism/ui/pages/homeScreen.dart';
import 'package:Prism/ui/pages/natureScreen.dart';
import 'package:Prism/ui/widgets/bottomNavBar.dart';
import 'package:Prism/ui/widgets/categoriesBar.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

PageController pageController = PageController();

class PageManager extends StatefulWidget {
  @override
  _PageManagerState createState() => _PageManagerState();
}

class _PageManagerState extends State<PageManager> {
  @override
  void initState() {
    super.initState();
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
        ));
  }
}
